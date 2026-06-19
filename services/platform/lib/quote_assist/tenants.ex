defmodule QuoteAssist.Tenants do
  @moduledoc """
  Tenant resolution, the public directory, RBAC role seeding, memberships, and the
  tenant status state machine.

  Host resolution (`resolve_host/1`) is the only place a tenant is identified, and
  it reads the request host — never user-supplied params (RELEASE_PLAN.md).
  """
  import Ecto.Query

  alias Ecto.Multi
  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.{Admin, User}
  alias QuoteAssist.Audit
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
  # building; conn.host carries neither). dev → "quoteassist.localhost", prod →
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
  Live tenants with their live memberships (user + role) preloaded, ordered by name.
  Backs the dev-only credentials view on `/tenants`; not for production use.
  """
  def list_live_tenants_with_members do
    members =
      from m in Membership,
        where: is_nil(m.deleted_at),
        order_by: [asc: m.inserted_at],
        preload: [:user, :role]

    Repo.all(
      from t in Tenant,
        where: is_nil(t.deleted_at),
        order_by: [asc: t.name],
        preload: [memberships: ^members]
    )
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

  @doc """
  Built-in **member** role specs, composed from the code-owned catalog
  (`QuoteAssist.Authz.Permissions`). Owner is a protected *type*, not a role
  (computed all-access), so it is intentionally absent here. Definitions track the
  R7-rbac catalog: `manager` runs the desk; `agent` drafts and sends quotes.
  """
  def default_role_specs do
    [
      %{
        slug: "manager",
        name: "Manager",
        description: "Runs the desk: every quote, members and settings.",
        permissions: ~w(quote:list quote:create quote:read quote:update quote:delete
                        quote:status quote:reply quote:ai_generate
                        user:list user:create user:read user:update
                        user:activate user:deactivate
                        role:list role:read settings:read settings:update)
      },
      %{
        slug: "agent",
        name: "Agent",
        description: "Drafts and sends quotes from enquiries.",
        permissions: ~w(quote:list quote:create quote:read quote:update
                        quote:status quote:reply quote:ai_generate
                        user:list user:read)
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
  Whether the user has a live membership for the tenant. A lean existence check used
  to gate login (you can only sign in to a tenant you belong to).
  """
  def member?(%Tenant{} = tenant, %User{} = user) do
    Repo.exists?(
      from m in Membership,
        where: m.tenant_id == ^tenant.id and m.user_id == ^user.id and is_nil(m.deleted_at)
    )
  end

  @doc """
  The user's live membership for a tenant, with role preloaded — or nil. This is the
  access gate: no live membership for the resolved tenant means no access. (Owners
  carry no role, so the preload is simply nil for them.)
  """
  def get_active_membership(%Tenant{} = tenant, %User{} = user) do
    Repo.one(
      from m in Membership,
        where: m.tenant_id == ^tenant.id and m.user_id == ^user.id and is_nil(m.deleted_at),
        preload: [:role]
    )
  end

  @doc "Adds a user to a tenant as a **member** with a role (a live membership)."
  def create_membership(%Tenant{} = tenant, %User{} = user, %Role{} = role) do
    %Membership{}
    |> Membership.member_changeset(%{tenant_id: tenant.id, user_id: user.id, role_id: role.id})
    |> Repo.insert()
  end

  @doc """
  Adds a user to a tenant as the **owner** (protected type, no role). The owner holds
  computed all-access via `QuoteAssist.Authz.Policy`; see the protected-type pattern.
  """
  def create_owner_membership(%Tenant{} = tenant, %User{} = user) do
    %Membership{}
    |> Membership.owner_changeset(%{tenant_id: tenant.id, user_id: user.id})
    |> Repo.insert()
  end

  @doc """
  Count of live, active owners for a tenant. The last-active-owner guard reads this
  inside the same transaction as any owner deactivation / removal / demotion (R7-rbac)
  so the "≥1 active owner per tenant" invariant can never be raced past.
  """
  def active_owner_count(%Tenant{id: tenant_id}), do: active_owner_count(tenant_id)

  def active_owner_count(tenant_id) when is_binary(tenant_id) do
    Repo.aggregate(
      from(m in Membership,
        where:
          m.tenant_id == ^tenant_id and m.type == :owner and m.active == true and
            is_nil(m.deleted_at)
      ),
      :count,
      :id
    )
  end

  # ── Admin tenant console (R3) ─────────────────────────────────────────────────────

  @trial_days 15

  @doc """
  All live tenants (any status) for the admin console, ordered by name, with plan +
  live memberships (user + role) preloaded. Soft-deleted tenants are excluded.
  """
  def list_tenants_for_admin do
    Repo.all(
      from t in Tenant,
        where: is_nil(t.deleted_at),
        order_by: [asc: t.name],
        preload: [:plan, memberships: ^admin_members_query()]
    )
  end

  @doc "A single live tenant (any status) for the admin console, or nil (safe for untrusted ids)."
  def get_tenant_for_admin(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.one(
          from t in Tenant,
            where: t.id == ^uuid and is_nil(t.deleted_at),
            preload: [:plan, memberships: ^admin_members_query()]
        )

      :error ->
        nil
    end
  end

  defp admin_members_query do
    from m in Membership, where: is_nil(m.deleted_at), preload: [:user, :role]
  end

  @doc "The owner's email for a tenant (the live `owner`-type membership), or nil."
  def owner_email(%Tenant{memberships: memberships}) when is_list(memberships) do
    Enum.find_value(memberships, fn m ->
      if m.type == :owner && m.user, do: m.user.email
    end)
  end

  def owner_email(_tenant), do: nil

  @doc "Live tenants on a given plan, ordered by name (for the plan detail page)."
  def list_tenants_for_plan(plan_id) do
    Repo.all(
      from t in Tenant,
        where: t.plan_id == ^plan_id and is_nil(t.deleted_at),
        order_by: [asc: t.name]
    )
  end

  @doc "Map of `plan_id => live tenant count` (for the plans list)."
  def tenant_count_by_plan do
    from(t in Tenant,
      where: is_nil(t.deleted_at) and not is_nil(t.plan_id),
      group_by: t.plan_id,
      select: {t.plan_id, count(t.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Changeset backing the admin create-tenant form (includes the virtual owner_email)."
  def change_tenant_creation(attrs \\ %{}) do
    Tenant.admin_create_changeset(%Tenant{}, attrs)
  end

  @doc "Changeset backing the admin edit-tenant form (name + plan only)."
  def change_tenant(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.admin_update_changeset(tenant, attrs)
  end

  # `Ecto.Multi.t/0` is opaque and wraps a `MapSet`; piping `Multi.new/0` into
  # `Multi.insert/4` makes Dialyzer read that MapSet structurally and emit a
  # spurious `call_without_opaque`. The code is correct (a well-known Ecto.Multi
  # false positive), so scope a `:no_opaque` suppression to just this function.
  @dialyzer {:no_opaque, create_tenant_with_owner: 2}

  @doc """
  Admin-creates a tenant and its owner, atomically (`Ecto.Multi`):

    * tenant — status `trial`, `trial_expires_at = now + 15 days`, chosen plan;
    * the built-in role set (`seed_default_roles/1`);
    * owner `User` — reuses the existing global row if the email is already known,
      else registers a new (unconfirmed) user;
    * owner `Membership` (**`type: :owner`**, no role);
    * an audit row (actor = admin).

  On success an invite email (a magic link built on the tenant's own host) is sent to
  the owner and `{:ok, tenant}` is returned. Any failed step rolls the whole thing
  back; an invalid form or a taken slug comes back as `{:error, changeset}`.
  """
  def create_tenant_with_owner(%Admin{} = admin, attrs) do
    changeset = Tenant.admin_create_changeset(%Tenant{}, attrs)

    if changeset.valid? do
      owner_email = Ecto.Changeset.get_field(changeset, :owner_email)
      expires_at = DateTime.add(DateTime.utc_now(:second), @trial_days, :day)
      insert_changeset = Ecto.Changeset.put_change(changeset, :trial_expires_at, expires_at)

      multi =
        Multi.new()
        |> Multi.insert(:tenant, insert_changeset)
        |> Multi.run(:roles, fn _repo, %{tenant: tenant} ->
          {:ok, seed_default_roles(tenant)}
        end)
        |> Multi.run(:owner, fn _repo, _changes -> ensure_owner_user(owner_email) end)
        |> Multi.run(:membership, fn _repo, %{tenant: tenant, owner: owner} ->
          create_owner_membership(tenant, owner)
        end)
        |> Multi.run(:audit, fn _repo, %{tenant: tenant, owner: owner} ->
          Audit.log(%{
            actor_type: :admin,
            actor_id: admin.id,
            tenant_id: tenant.id,
            action: "tenant.created",
            target_type: "tenant",
            target_id: tenant.id,
            metadata: %{"slug" => tenant.slug, "owner_email" => mask_email(owner.email)}
          })
        end)

      case Repo.transaction(multi) do
        {:ok, %{tenant: tenant, owner: owner}} ->
          deliver_owner_invite(owner, tenant)
          {:ok, tenant}

        {:error, :tenant, %Ecto.Changeset{} = failed, _changes} ->
          {:error, failed}

        {:error, _step, _reason, _changes} ->
          {:error, %{changeset | action: :insert}}
      end
    else
      {:error, %{changeset | action: :insert}}
    end
  end

  @doc "Admin-edits a tenant's name + plan (status changes go through `transition_status/3`)."
  def update_tenant(%Admin{} = admin, %Tenant{} = tenant, attrs) do
    Repo.transact(fn ->
      with {:ok, updated} <- tenant |> Tenant.admin_update_changeset(attrs) |> Repo.update() do
        Audit.log!(%{
          actor_type: actor_type(admin),
          actor_id: actor_id(admin),
          tenant_id: tenant.id,
          action: "tenant.updated",
          target_type: "tenant",
          target_id: tenant.id,
          metadata: %{"slug" => updated.slug}
        })

        {:ok, updated}
      end
    end)
  end

  @doc """
  Soft-deletes a tenant (sets `deleted_at`) and audits it. Hard purge is a separate,
  later, explicit action — not this.
  """
  def soft_delete_tenant(%Admin{} = admin, %Tenant{} = tenant) do
    now = DateTime.utc_now(:second)

    Repo.transact(fn ->
      with {:ok, deleted} <- tenant |> Ecto.Changeset.change(deleted_at: now) |> Repo.update() do
        Audit.log!(%{
          actor_type: actor_type(admin),
          actor_id: actor_id(admin),
          tenant_id: tenant.id,
          action: "tenant.deleted",
          target_type: "tenant",
          target_id: tenant.id,
          metadata: %{"slug" => tenant.slug}
        })

        {:ok, deleted}
      end
    end)
  end

  # ── Trial expiry ──────────────────────────────────────────────────────────────────

  @doc "Whether a tenant's trial has lapsed (still `trial`, and the deadline has passed)."
  def trial_expired?(%Tenant{status: :trial, trial_expires_at: %DateTime{} = expires_at}) do
    DateTime.after?(DateTime.utc_now(), expires_at)
  end

  def trial_expired?(_tenant), do: false

  @doc """
  Enforces trial expiry at login. If the trial has lapsed, auto-transitions the tenant
  `trial → suspended` (audited, actor `:system`) and returns `:expired`; otherwise
  `:ok`. Once suspended, `TenantResolver` 404s the host on the next request.
  """
  def enforce_trial_expiry(%Tenant{} = tenant) do
    if trial_expired?(tenant) do
      {:ok, _suspended} = transition_status(tenant, :suspended, :system)
      :expired
    else
      :ok
    end
  end

  # ── Owner-invite helpers ────────────────────────────────────────────────────────

  defp ensure_owner_user(email) do
    case Accounts.get_user_by_email(email) do
      %User{} = user -> {:ok, user}
      nil -> Accounts.register_user(%{email: email})
    end
  end

  # Sends the owner a magic-link invite built on the tenant's OWN host (subdomain),
  # since cookies are host-scoped — the whole login flow must stay on that host.
  defp deliver_owner_invite(%User{} = owner, %Tenant{} = tenant) do
    Accounts.deliver_login_instructions(owner, fn token ->
      tenant_url(tenant, "/login/#{token}")
    end)
  end

  defp tenant_url(%Tenant{slug: slug}, path) do
    scheme = Application.get_env(:quote_assist, :tenant_url_scheme, "https")
    base = Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.mytechbytes.in")
    "#{scheme}://#{slug}.#{base}#{path}"
  end

  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, domain] -> "#{String.first(local)}***@#{domain}"
      _ -> "***"
    end
  end

  # ── Audit actor helpers ───────────────────────────────────────────────────────────

  defp actor_type(%User{}), do: :user
  defp actor_type(%Admin{}), do: :admin
  defp actor_type(_), do: :system

  defp actor_id(%User{id: id}), do: id
  defp actor_id(%Admin{id: id}), do: id
  defp actor_id(_), do: nil
end
