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
  alias QuoteAssist.Accounts.{Admin, Scope, User, UserToken}
  alias QuoteAssist.Audit
  alias QuoteAssist.Plans
  alias QuoteAssist.Repo
  alias QuoteAssist.Tenancy
  alias QuoteAssist.Tenants.{Membership, Role, Tenant}

  # ── Host resolution ───────────────────────────────────────────────────────────

  @doc """
  Resolves a request host to a tenant. The host is the sole input — params are never
  consulted.

    * `:platform`          — platform host (home / directory / admin); no tenant.
    * `{:ok, tenant}`      — a live, resolvable tenant (trial / active) by slug or
      verified custom domain.
    * `{:suspended, tenant}` — a live but suspended tenant; the caller shows a
      suspension notice with status 403 (the workspace exists, access is forbidden).
    * `:not_found`         — no matching live tenant, or a cancelled one → 404.
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
    query = from t in live_tenant_query(), where: t.slug == ^slug
    query |> Repo.one() |> classify()
  end

  defp resolve_by_custom_domain(host) do
    query =
      from t in live_tenant_query(),
        where: t.custom_domain == ^host and t.custom_domain_status == :verified

    query |> Repo.one() |> classify()
  end

  # Classifies a looked-up tenant (or nil) into a host-resolution outcome by status:
  # trial/active serve the workspace, suspended shows the 403 notice, and cancelled
  # (or no match) is a 404. Deleted tenants are already excluded by `live_tenant_query/0`.
  defp classify(nil), do: :not_found
  defp classify(%Tenant{status: :suspended} = tenant), do: {:suspended, tenant}
  defp classify(%Tenant{status: :cancelled}), do: :not_found
  defp classify(%Tenant{} = tenant), do: {:ok, tenant}

  # Live = not soft-deleted, any status — `resolve_host/1` then classifies by status.
  defp live_tenant_query do
    from t in Tenant, where: is_nil(t.deleted_at)
  end

  # Live + status in (:trial, :active). Used to reload a still-serving tenant mid-session
  # (`fetch_live_tenant/1`); suspended / cancelled / deleted never pass.
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

  @doc """
  Creates a tenant-scoped role. The `%Tenant{}` head is the low-level seed/test path
  (no audit); the `%Scope{}` head is the audited R7-rbac console path (`role:create`),
  acting as the signed-in member.
  """
  def create_role(%Tenant{} = tenant, attrs) do
    %Role{}
    |> Role.changeset(Map.merge(attrs, %{tenant_id: tenant.id}))
    |> Repo.insert()
  end

  def create_role(%Scope{} = scope, attrs) do
    Repo.transact(fn ->
      changeset = Role.changeset(%Role{}, Map.put(stringify(attrs), "tenant_id", scope.tenant.id))

      with {:ok, role} <- Repo.insert(changeset) do
        audit_member(scope, "role.created", role.id, %{"slug" => role.slug}, "role")
        {:ok, role}
      end
    end)
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
  Whether the user has a live, **active** membership for the tenant. A lean existence
  check used to gate login (you can only sign in to a tenant you belong to, and a
  deactivated member can't — `active` gates future logins per the cross-cutting rule).
  """
  def member?(%Tenant{} = tenant, %User{} = user) do
    Repo.exists?(
      from m in Membership,
        where:
          m.tenant_id == ^tenant.id and m.user_id == ^user.id and m.active == true and
            is_nil(m.deleted_at)
    )
  end

  @doc """
  The user's live, **active** membership for a tenant, with role preloaded — or nil.
  This is the access gate (re-run on every LiveView mount): no live, active membership
  for the resolved tenant means no access, so a member deactivated mid-session is
  bounced at the next request. (Owners carry no role, so the preload is nil for them.)
  """
  def get_active_membership(%Tenant{} = tenant, %User{} = user) do
    Repo.one(
      from m in Membership,
        where:
          m.tenant_id == ^tenant.id and m.user_id == ^user.id and m.active == true and
            is_nil(m.deleted_at),
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

  # ── Member & role management (R7-rbac) ────────────────────────────────────────────
  #
  # The tenant mirror of the admin RBAC functions. The protected `owner` type is
  # enforced at the QUERY layer (`QuoteAssist.Tenancy.members_visible_to/1`): a member's
  # member/role lists EXCLUDE owners, so they can't see, edit, or act on one by any
  # path. The last-active-owner guard runs in the same transaction as the mutation
  # (`SELECT … FOR UPDATE`), and deactivate/remove revoke the member's sessions. Every
  # mutation is audited (actor = user, subtype = owner | member).

  @doc """
  Live memberships visible to `scope`'s actor, with `:user` + `:role` preloaded,
  oldest first. An owner sees every member; a normal member sees only members — owners
  are filtered out in the query, never merely hidden in the template.
  """
  def list_members_visible_to(%Scope{} = scope) do
    scope
    |> Tenancy.members_visible_to()
    |> order_by([m], asc: m.inserted_at)
    |> preload([:user, :role])
    |> Repo.all()
  end

  @doc """
  A single live membership (with `:user` + `:role`) visible to `scope`'s actor, or nil.
  A member can never load an owner (the exclusion is in the query), so editing/acting on
  one is impossible by any path — not just hidden in the UI.
  """
  def get_member_visible_to(%Scope{} = scope, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        scope
        |> Tenancy.members_visible_to()
        |> where([m], m.id == ^uuid)
        |> preload([:user, :role])
        |> Repo.one()

      :error ->
        nil
    end
  end

  @doc "Live members assigned to a role, oldest first (with `:user`) — the role detail page."
  def list_members_for_role(%Role{id: role_id, tenant_id: tenant_id}) do
    Repo.all(
      from m in Membership,
        where: m.role_id == ^role_id and m.tenant_id == ^tenant_id and is_nil(m.deleted_at),
        order_by: [asc: m.inserted_at],
        preload: [:user]
    )
  end

  @doc "A live membership in `tenant` by id (with `:user`), or nil. Visibility-agnostic."
  def get_membership(%Tenant{} = tenant, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.one(
          from m in Membership,
            where: m.id == ^uuid and m.tenant_id == ^tenant.id and is_nil(m.deleted_at),
            preload: [:user, :role]
        )

      :error ->
        nil
    end
  end

  @doc "Changeset backing the invite-member form (email + role)."
  def change_member_invite(attrs \\ %{}) do
    invite_changeset(attrs)
  end

  @doc """
  Invites a member by email (`user:create`): reuses the global `User` if the email is
  already known, else registers a new unconfirmed user; adds a live `member`
  membership with the chosen role; and emails an invite link — the platform-host
  onboarding link for a not-yet-set-up user, or a tenant-host magic link for one who
  already has an account. Atomic + audited. Returns `{:ok, membership}` or
  `{:error, changeset | :already_member | :role_not_found}`.
  """
  def invite_member(%Scope{} = scope, attrs) do
    changeset = invite_changeset(attrs)

    if changeset.valid?,
      do: do_invite(scope, changeset),
      else: {:error, %{changeset | action: :insert}}
  end

  # Same well-known `Ecto.Multi` opaque false positive suppressed on
  # `create_tenant_with_owner/2` — see the note there.
  @dialyzer {:no_opaque, do_invite: 2}

  defp do_invite(scope, changeset) do
    tenant = scope.tenant
    email = Ecto.Changeset.get_field(changeset, :email)
    role_id = Ecto.Changeset.get_field(changeset, :role_id)

    multi =
      Multi.new()
      |> Multi.run(:role, fn _repo, _ -> fetch_tenant_role(tenant, role_id) end)
      |> Multi.run(:user, fn _repo, _ -> {:ok, ensure_member_user(email)} end)
      |> Multi.run(:membership, fn _repo, %{user: user, role: role} ->
        create_membership(tenant, user, role)
      end)
      |> Multi.run(:audit, fn _repo, %{user: user, membership: membership} ->
        audit_member(scope, "user.invited", membership.id, %{
          "email" => mask_email(user.email),
          "role_id" => role_id
        })
      end)

    case Repo.transaction(multi) do
      {:ok, %{user: user, membership: membership}} ->
        deliver_member_invite(user, tenant)
        {:ok, membership}

      {:error, :role, :role_not_found, _} ->
        {:error, :role_not_found}

      {:error, :membership, %Ecto.Changeset{} = failed, _} ->
        invite_conflict(failed, changeset)

      {:error, _step, _reason, _} ->
        {:error, %{changeset | action: :insert}}
    end
  end

  defp invite_conflict(failed, changeset) do
    if member_taken?(failed),
      do: {:error, :already_member},
      else: {:error, %{changeset | action: :insert}}
  end

  @doc """
  Reassigns a **member's** role (`user:update`). Refuses an owner target
  (`:owner_has_no_role`) — the protected type carries no role. Audited.
  """
  def update_member_role(%Scope{}, %Membership{type: :owner}, _attrs) do
    {:error, :owner_has_no_role}
  end

  def update_member_role(%Scope{} = scope, %Membership{} = membership, attrs) do
    with {:ok, role} <- fetch_tenant_role(scope.tenant, role_id_param(attrs)) do
      Repo.transact(fn -> reassign_role(scope, membership, role) end)
    end
  end

  defp reassign_role(scope, membership, role) do
    with {:ok, updated} <-
           membership |> Membership.role_changeset(%{role_id: role.id}) |> Repo.update() do
      audit_member(scope, "user.role_changed", membership.id, %{"role_id" => role.id})
      {:ok, updated}
    end
  end

  @doc "Reactivates a deactivated member (`user:activate`). Audited."
  def activate_member(%Scope{} = scope, %Membership{} = membership) do
    Repo.transact(fn ->
      with {:ok, updated} <-
             membership |> Ecto.Changeset.change(active: true) |> Repo.update() do
        audit_member(scope, "user.activated", membership.id, member_meta(membership))
        {:ok, updated}
      end
    end)
  end

  @doc """
  Deactivates a member (`user:deactivate`) and revokes their sessions in the same
  transaction (cross-cutting session-revocation rule). Refuses the last active owner
  (`:last_owner`) under a row lock so concurrent deactivations can't race past it.
  """
  def deactivate_member(%Scope{} = scope, %Membership{} = membership) do
    Repo.transact(fn ->
      if last_active_owner?(membership),
        do: {:error, :last_owner},
        else: do_deactivate_member(scope, membership)
    end)
  end

  defp do_deactivate_member(scope, membership) do
    with {:ok, updated} <- membership |> Ecto.Changeset.change(active: false) |> Repo.update() do
      revoke_member_sessions(membership)
      audit_member(scope, "user.deactivated", membership.id, member_meta(membership))
      {:ok, updated}
    end
  end

  @doc """
  Soft-removes a member (`user:delete`): sets `deleted_at`, flips `active`, revokes
  their sessions, and audits it. Refuses the last active owner (`:last_owner`) under
  the same transactional guard as `deactivate_member/2`.
  """
  def remove_member(%Scope{} = scope, %Membership{} = membership) do
    Repo.transact(fn ->
      if last_active_owner?(membership),
        do: {:error, :last_owner},
        else: do_remove_member(scope, membership)
    end)
  end

  defp do_remove_member(scope, membership) do
    changeset =
      Ecto.Changeset.change(membership, deleted_at: DateTime.utc_now(:second), active: false)

    with {:ok, removed} <- Repo.update(changeset) do
      revoke_member_sessions(membership)
      audit_member(scope, "user.removed", membership.id, member_meta(membership))
      {:ok, removed}
    end
  end

  @doc """
  Promotes a member to the protected **owner** type (owner-only; the LiveView gates
  this). Clears the role — owners hold computed all-access. Audited.
  """
  def promote_member(%Scope{} = scope, %Membership{} = membership) do
    Repo.transact(fn ->
      with {:ok, updated} <- membership |> Membership.promote_changeset() |> Repo.update() do
        audit_member(scope, "user.promoted", membership.id, member_meta(membership))
        {:ok, updated}
      end
    end)
  end

  @doc """
  Demotes an owner back to a normal member with a role (owner-only). Refuses the last
  active owner (`:last_owner`) — demoting them would leave the tenant ownerless — under
  the same transactional guard. Audited.
  """
  def demote_owner(%Scope{} = scope, %Membership{} = membership, attrs) do
    with {:ok, role} <- fetch_tenant_role(scope.tenant, role_id_param(attrs)) do
      Repo.transact(fn -> demote_txn(scope, membership, role) end)
    end
  end

  defp demote_txn(scope, membership, role) do
    if last_active_owner?(membership),
      do: {:error, :last_owner},
      else: do_demote_owner(scope, membership, role)
  end

  defp do_demote_owner(scope, membership, role) do
    with {:ok, updated} <-
           membership |> Membership.demote_changeset(%{role_id: role.id}) |> Repo.update() do
      audit_member(scope, "user.demoted", membership.id, %{"role_id" => role.id})
      {:ok, updated}
    end
  end

  # ── Tenant roles (R7-rbac) ────────────────────────────────────────────────────────

  @doc "Live roles for a tenant, ordered by name (the roles console)."
  def list_roles(%Tenant{} = tenant) do
    Repo.all(
      from r in Role,
        where: r.tenant_id == ^tenant.id and is_nil(r.deleted_at),
        order_by: [asc: r.name]
    )
  end

  @doc "Fetches a live role within a tenant by id, or nil. Safe for untrusted ids."
  def get_role(%Tenant{} = tenant, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.one(
          from r in Role,
            where: r.id == ^uuid and r.tenant_id == ^tenant.id and is_nil(r.deleted_at)
        )

      :error ->
        nil
    end
  end

  @doc "Changeset backing the role create/edit form (seeded with the tenant)."
  def change_tenant_role(%Tenant{} = tenant, %Role{} = role \\ %Role{}, attrs \\ %{}) do
    Role.changeset(role, Map.put(stringify(attrs), "tenant_id", tenant.id))
  end

  @doc "Edits a tenant role's name/description/permissions (`role:update`). Audited."
  def update_role(%Scope{} = scope, %Role{} = role, attrs) do
    Repo.transact(fn ->
      with {:ok, updated} <-
             role
             |> Role.changeset(Map.put(stringify(attrs), "tenant_id", role.tenant_id))
             |> Repo.update() do
        audit_member(scope, "role.updated", role.id, %{"slug" => updated.slug}, "role")
        {:ok, updated}
      end
    end)
  end

  @doc """
  Soft-deletes a tenant role (`role:delete`). Refuses built-ins (`:builtin`) and roles
  still assigned to a live member (`:role_in_use`) — there is no orphaning path.
  Audited.
  """
  def soft_delete_role(%Scope{} = scope, %Role{} = role) do
    cond do
      role.builtin -> {:error, :builtin}
      role_in_use?(role) -> {:error, :role_in_use}
      true -> do_delete_role(scope, role)
    end
  end

  defp do_delete_role(scope, role) do
    Repo.transact(fn ->
      changeset = Ecto.Changeset.change(role, deleted_at: DateTime.utc_now(:second))

      with {:ok, deleted} <- Repo.update(changeset) do
        audit_member(scope, "role.deleted", role.id, %{"slug" => role.slug}, "role")
        {:ok, deleted}
      end
    end)
  end

  defp role_in_use?(%Role{id: role_id}) do
    Repo.exists?(from m in Membership, where: m.role_id == ^role_id and is_nil(m.deleted_at))
  end

  # ── R7 helpers ───────────────────────────────────────────────────────────────────

  # Schemaless changeset for the invite form (email + role).
  defp invite_changeset(attrs) do
    types = %{email: :string, role_id: :binary_id}

    {%{email: nil, role_id: nil}, types}
    |> Ecto.Changeset.cast(stringify(attrs), [:email, :role_id])
    |> Ecto.Changeset.update_change(:email, fn email ->
      email && email |> String.trim() |> String.downcase()
    end)
    |> Ecto.Changeset.validate_required([:email, :role_id])
    |> Ecto.Changeset.validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> Ecto.Changeset.validate_length(:email, max: 160)
  end

  defp role_id_param(attrs), do: attrs["role_id"] || attrs[:role_id]

  defp fetch_tenant_role(_tenant, nil), do: {:error, :role_not_found}

  defp fetch_tenant_role(%Tenant{} = tenant, role_id) do
    case get_role(tenant, role_id) do
      %Role{} = role -> {:ok, role}
      nil -> {:error, :role_not_found}
    end
  end

  # Reuse the existing global user untouched, or register a fresh unconfirmed one.
  defp ensure_member_user(email) do
    case Accounts.get_user_by_email(email) do
      %User{} = user -> user
      nil -> elem(Accounts.register_user(%{email: email}), 1)
    end
  end

  # An already-set-up user (has a password + confirmed email) gets a tenant-host magic
  # link to reach the new workspace; a fresh one gets the platform-host onboarding link
  # to set their password (which also confirms the email).
  defp deliver_member_invite(%User{} = user, %Tenant{} = tenant) do
    if onboarded?(user) do
      Accounts.deliver_login_instructions(user, fn token ->
        tenant_url(tenant, "/login/#{token}")
      end)
    else
      deliver_owner_onboarding(user)
    end
  end

  defp member_taken?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {field, _} -> field in [:tenant_id, :user_id] end)
  end

  defp member_meta(%Membership{user: %User{email: email}}), do: %{"email" => mask_email(email)}
  defp member_meta(_membership), do: %{}

  # True only when `target` is itself an active owner AND it is the last one. Locks the
  # active-owner rows (`FOR UPDATE`) so concurrent owner deactivations serialise on the
  # same rows and can't both pass the guard.
  defp last_active_owner?(%Membership{type: :owner, active: true, tenant_id: tenant_id}) do
    ids = Repo.all(from m in active_owners_query(tenant_id), lock: "FOR UPDATE", select: m.id)
    length(ids) <= 1
  end

  defp last_active_owner?(_membership), do: false

  defp active_owners_query(tenant_id) do
    from m in Membership,
      where:
        m.tenant_id == ^tenant_id and m.type == :owner and m.active == true and
          is_nil(m.deleted_at)
  end

  # Deletes the member's session tokens (context "session") so a deactivation / removal
  # kills their live sessions; invite / onboarding / reset tokens are left intact.
  defp revoke_member_sessions(%Membership{user_id: user_id}) do
    Repo.delete_all(from t in UserToken, where: t.user_id == ^user_id and t.context == "session")
    :ok
  end

  defp audit_member(scope, action, target_id, metadata, target_type \\ "user") do
    Audit.log(%{
      actor_type: :user,
      actor_subtype: scope.membership.type,
      actor_id: scope.user.id,
      tenant_id: scope.tenant.id,
      action: action,
      target_type: target_type,
      target_id: to_string(target_id),
      metadata: metadata
    })
  end

  defp stringify(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
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

  # ── Self-registration (R5-selfreg) ────────────────────────────────────────────────
  #
  # A company self-registers on the platform host and lands in their workspace on a
  # 15-day trial immediately — no admin approval (RELEASE_PLAN.md). The owner verifies
  # their email by setting a password on the platform-host onboarding link. Admins
  # handle bad actors reactively via the R3 suspend/cancel controls.

  @doc "Changeset backing the public self-registration form (name + slug + owner)."
  def change_self_registration(attrs \\ %{}) do
    Tenant.self_register_changeset(%Tenant{}, attrs)
  end

  # Same well-known `Ecto.Multi` opaque false positive suppressed on
  # `create_tenant_with_owner/2` — see the note there.
  @dialyzer {:no_opaque, register_self_service: 1}

  @doc """
  Self-registers a tenant and its owner, atomically (`Ecto.Multi`, audited as
  `actor_type: :system`):

    * tenant — status `trial`, `trial_expires_at = now + 15 days`, `source:
      :self_signup`, on the seeded **Starter** plan;
    * the built-in role set (`seed_default_roles/1`);
    * owner `User` — reuses the existing global row if the email is already known
      (the self-asserting path where reuse is correct), else registers a new
      unconfirmed user with the display name from the form;
    * owner `Membership` (**`type: :owner`**, no role);
    * an audit row (actor = system).

  On success a platform-host onboarding link is emailed to the owner and
  `{:ok, %{tenant: tenant, owner: owner}}` is returned. Any failed step rolls the
  whole thing back; an invalid form or a taken slug comes back as
  `{:error, changeset}`.
  """
  def register_self_service(attrs) do
    changeset = Tenant.self_register_changeset(%Tenant{}, attrs)

    if changeset.valid? do
      owner_email = Ecto.Changeset.get_field(changeset, :owner_email)
      owner_name = Ecto.Changeset.get_field(changeset, :owner_name)
      expires_at = DateTime.add(DateTime.utc_now(:second), @trial_days, :day)
      plan = default_signup_plan()

      insert_changeset =
        changeset
        |> Ecto.Changeset.put_change(:status, :trial)
        |> Ecto.Changeset.put_change(:source, :self_signup)
        |> Ecto.Changeset.put_change(:trial_expires_at, expires_at)
        |> Ecto.Changeset.put_change(:plan_id, plan && plan.id)

      multi =
        Multi.new()
        |> Multi.insert(:tenant, insert_changeset)
        |> Multi.run(:roles, fn _repo, %{tenant: tenant} ->
          {:ok, seed_default_roles(tenant)}
        end)
        |> Multi.run(:owner, fn _repo, _changes ->
          ensure_signup_owner(owner_email, owner_name)
        end)
        |> Multi.run(:membership, fn _repo, %{tenant: tenant, owner: owner} ->
          create_owner_membership(tenant, owner)
        end)
        |> Multi.run(:audit, fn _repo, %{tenant: tenant, owner: owner} ->
          Audit.log(%{
            actor_type: :system,
            actor_id: nil,
            tenant_id: tenant.id,
            action: "tenant.self_registered",
            target_type: "tenant",
            target_id: tenant.id,
            metadata: %{"slug" => tenant.slug, "owner_email" => mask_email(owner.email)}
          })
        end)

      case Repo.transaction(multi) do
        {:ok, %{tenant: tenant, owner: owner}} ->
          deliver_owner_onboarding(owner)
          {:ok, %{tenant: tenant, owner: owner}}

        {:error, :tenant, %Ecto.Changeset{} = failed, _changes} ->
          {:error, failed}

        {:error, _step, _reason, _changes} ->
          {:error, %{changeset | action: :insert}}
      end
    else
      {:error, %{changeset | action: :insert}}
    end
  end

  @doc """
  Re-issues an onboarding link for `email` when it belongs to a not-yet-onboarded
  owner of a live tenant. Always returns `:ok` — it never reveals whether the email
  exists, so the resend action can't be used to enumerate accounts.
  """
  def resend_onboarding(email) when is_binary(email) do
    with %User{} = user <- Accounts.get_user_by_email(email),
         %Tenant{} <- newest_owner_tenant(user),
         false <- onboarded?(user) do
      deliver_owner_onboarding(user)
    end

    :ok
  end

  @doc """
  The tenant of the user's most recent live owner membership, or nil. Used after
  onboarding to send a new owner to the right tenant login (they may own several).
  """
  def newest_owner_tenant(%User{id: user_id}) do
    Repo.one(
      from m in Membership,
        join: t in Tenant,
        on: t.id == m.tenant_id,
        where:
          m.user_id == ^user_id and m.type == :owner and is_nil(m.deleted_at) and
            is_nil(t.deleted_at),
        order_by: [desc: m.inserted_at],
        limit: 1,
        select: t
    )
  end

  @doc "The tenant's own-host login URL (subdomain). Public so onboarding can link to it."
  def tenant_login_url(%Tenant{} = tenant), do: tenant_url(tenant, "/login")

  # Whether a user is fully set up (has a password AND a confirmed email) — the
  # single "ready to log in" predicate (RELEASE_PLAN.md).
  defp onboarded?(%User{hashed_password: hash, confirmed_at: confirmed}) do
    not is_nil(hash) and not is_nil(confirmed)
  end

  # Default plan for a self-signup: the seeded Starter plan, falling back to the
  # cheapest live plan if Starter is somehow absent (and nil if no plans exist).
  defp default_signup_plan do
    Plans.get_plan_by_slug("starter") || List.first(Plans.list_plans())
  end

  # Reuse the existing global user (name untouched), or register a fresh unconfirmed
  # owner carrying the display name from the signup form.
  defp ensure_signup_owner(email, name) do
    case Accounts.get_user_by_email(email) do
      %User{} = user -> {:ok, user}
      nil -> Accounts.register_owner(%{email: email, display_name: name})
    end
  end

  defp deliver_owner_onboarding(%User{} = owner) do
    Accounts.deliver_onboarding_instructions(owner, &onboarding_url/1)
  end

  defp onboarding_url(token), do: platform_url("/onboarding/#{token}")

  # Builds a URL on the platform host (apex, no subdomain) from config — the
  # onboarding flow always lives there, regardless of any tenant's host state.
  defp platform_url(path) do
    scheme = Application.get_env(:quote_assist, :tenant_url_scheme, "https")
    base = Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.mytechbytes.in")
    "#{scheme}://#{base}#{path}"
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
