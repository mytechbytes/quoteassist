defmodule QuoteAssist.Tenants do
  @moduledoc """
  Tenant resolution, the public directory, RBAC role seeding, memberships, and the
  tenant status state machine.

  Host resolution (`resolve_host/1`) is the only place a tenant is identified, and
  it reads the request host — never user-supplied params (RELEASE_PLAN.md).
  """
  import Ecto.Query

  alias QuoteAssist.Accounts.User
  alias QuoteAssist.Audit
  alias QuoteAssist.Authz.Permissions
  alias QuoteAssist.Repo
  alias QuoteAssist.Tenants.{Membership, Role, Tenant}

  # ── Host resolution ───────────────────────────────────────────────────────────

  @doc """
  Resolves a request host to a tenant. The host is the sole input — params are never
  consulted.

    * `:platform`     — platform host (home / directory / admin); no tenant.
    * `{:ok, tenant}` — a live, resolvable tenant by slug or verified custom domain.
    * `:not_found`    — a tenant host with no matching live tenant → the caller 404s.
  """
  def resolve_host(host) when is_binary(host) do
    host = String.downcase(host)

    cond do
      platform_host?(host) -> :platform
      subdomain_host?(host) -> resolve_by_slug(subdomain_slug(host))
      true -> resolve_by_custom_domain(host)
    end
  end

  defp platform_host?(host) do
    base = base_host()
    host in ["localhost", "127.0.0.1", base, "www." <> base]
  end

  defp subdomain_host?(host), do: String.ends_with?(host, "." <> base_host())

  defp subdomain_slug(host) do
    host
    |> String.replace_suffix("." <> base_host(), "")
    |> String.split(".")
    |> List.first()
  end

  defp resolve_by_slug(slug) do
    query = from t in resolvable_query(), where: t.slug == ^slug

    case Repo.one(query) do
      nil -> :not_found
      tenant -> {:ok, tenant}
    end
  end

  defp resolve_by_custom_domain(host) do
    query =
      from t in resolvable_query(),
        where: t.custom_domain == ^host and t.custom_domain_status == :verified

    case Repo.one(query) do
      nil -> :not_found
      tenant -> {:ok, tenant}
    end
  end

  # Live + status in (:trial, :active). Suspended / cancelled / deleted never resolve.
  defp resolvable_query do
    from t in Tenant,
      where: is_nil(t.deleted_at) and t.status in ^Tenant.resolvable_statuses()
  end

  # Host part of the configured base domain (config carries scheme/port for URL
  # building; conn.host carries neither). dev → "lvh.me", prod →
  # "quoteassist.mytechbytes.in".
  defp base_host do
    :quote_assist
    |> Application.get_env(:tenant_base_domain, "quoteassist.mytechbytes.in")
    |> String.split(":")
    |> List.first()
  end

  # ── Directory ───────────────────────────────────────────────────────────────────

  @doc "All live tenants (any status), ordered by name — the public directory."
  def list_live_tenants do
    Repo.all(from t in Tenant, where: is_nil(t.deleted_at), order_by: [asc: t.name])
  end

  @doc """
  Fetches a live, resolvable tenant by id — used to reload the tenant from the
  session on every LiveView mount, so a tenant suspended or deleted mid-session is
  caught at the next mount.
  """
  def fetch_live_tenant(nil), do: nil

  def fetch_live_tenant(id) do
    Repo.one(from t in resolvable_query(), where: t.id == ^id)
  end

  @doc "Fetches a live tenant by slug (any status), or nil."
  def get_tenant_by_slug(slug) do
    Repo.one(from t in Tenant, where: t.slug == ^slug and is_nil(t.deleted_at))
  end

  # ── Tenant lifecycle ──────────────────────────────────────────────────────────

  @doc "Creates a tenant from core attrs. R3 builds the admin create flow on top."
  def create_tenant(attrs) do
    %Tenant{} |> Tenant.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Applies a guarded status transition and writes an audit row, atomically. Returns
  `{:ok, tenant}` or `{:error, changeset}`; an illegal transition never persists.
  """
  def transition_status(%Tenant{} = tenant, new_status, actor) do
    Repo.transact(fn ->
      with {:ok, updated} <- tenant |> Tenant.status_changeset(new_status) |> Repo.update() do
        Audit.log!(%{
          actor_type: actor_type(actor),
          actor_id: actor_id(actor),
          tenant_id: tenant.id,
          action: "tenant.status_changed",
          target_type: "tenant",
          target_id: tenant.id,
          metadata: %{"from" => to_string(tenant.status), "to" => to_string(new_status)}
        })

        {:ok, updated}
      end
    end)
  end

  # ── Roles ───────────────────────────────────────────────────────────────────────

  @doc "Seeds the built-in roles for a tenant (idempotent — skips existing slugs)."
  def seed_default_roles(%Tenant{} = tenant) do
    for spec <- default_role_specs() do
      case get_role_by_slug(tenant, spec.slug) do
        nil ->
          {:ok, role} = create_role(tenant, Map.put(spec, :builtin, true))
          role

        %Role{} = role ->
          role
      end
    end
  end

  @doc "Built-in role specs (mirror the design catalog in qa-team.js)."
  def default_role_specs do
    all = Permissions.keys()

    [
      %{
        slug: "owner",
        name: "Owner",
        description: "Full control of the workspace, billing and access.",
        permissions: all
      },
      %{
        slug: "lead",
        name: "Team lead",
        description: "Runs the desk: pricing, members and every quote.",
        permissions: all -- ["settings.billing"]
      },
      %{
        slug: "senior",
        name: "Senior agent",
        description: "Full quoting plus fare-policy tuning.",
        permissions: ~w(quotes.view quotes.create quotes.edit quotes.send quotes.export
                        quotes.delete pricing.view pricing.policy team.view settings.view)
      },
      %{
        slug: "agent",
        name: "Agent",
        description: "Drafts and sends quotes from enquiries.",
        permissions: ~w(quotes.view quotes.create quotes.edit quotes.send quotes.export
                        pricing.view team.view settings.view)
      },
      %{
        slug: "viewer",
        name: "Viewer",
        description: "Read-only access for auditors and observers.",
        permissions: ~w(quotes.view pricing.view team.view settings.view)
      }
    ]
  end

  @doc "Creates a tenant-scoped role."
  def create_role(%Tenant{} = tenant, attrs) do
    %Role{}
    |> Role.changeset(Map.merge(attrs, %{tenant_id: tenant.id}))
    |> Repo.insert()
  end

  @doc "Fetches a live role by slug within a tenant, or nil."
  def get_role_by_slug(%Tenant{} = tenant, slug) do
    Repo.one(
      from r in Role,
        where: r.tenant_id == ^tenant.id and r.slug == ^slug and is_nil(r.deleted_at)
    )
  end

  # ── Memberships ──────────────────────────────────────────────────────────────────

  @doc """
  The user's live membership for a tenant, with role preloaded — or nil. This is the
  access gate: no live membership for the resolved tenant means no access.
  """
  def get_active_membership(%Tenant{} = tenant, %User{} = user) do
    Repo.one(
      from m in Membership,
        where: m.tenant_id == ^tenant.id and m.user_id == ^user.id and is_nil(m.deleted_at),
        preload: [:role]
    )
  end

  @doc "Adds a user to a tenant with a role (a live membership)."
  def create_membership(%Tenant{} = tenant, %User{} = user, %Role{} = role) do
    %Membership{}
    |> Membership.changeset(%{tenant_id: tenant.id, user_id: user.id, role_id: role.id})
    |> Repo.insert()
  end

  # ── Audit actor helpers ───────────────────────────────────────────────────────────

  defp actor_type(%User{}), do: :user
  defp actor_type(_), do: :system

  defp actor_id(%User{id: id}), do: id
  defp actor_id(_), do: nil
end
