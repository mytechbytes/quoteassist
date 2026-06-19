defmodule QuoteAssist.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias QuoteAssist.Repo

  alias QuoteAssist.Accounts.{Admin, AdminRole, AdminToken, User, UserNotifier, UserToken}
  alias QuoteAssist.Audit

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.one(from u in User, where: u.email == ^email and is_nil(u.deleted_at))
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.one(from u in User, where: u.email == ^email and is_nil(u.deleted_at))
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a self-service owner (R5-selfreg): email + display name, unconfirmed and
  password-less. Used by `Tenants.register_self_service/1` only when the email is new
  (an existing user is reused untouched). The owner sets a password and confirms via
  the onboarding link.
  """
  def register_owner(attrs) do
    %User{}
    |> User.owner_registration_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `QuoteAssist.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `QuoteAssist.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Onboarding

  @doc """
  Changeset for the owner onboarding form (display name + initial password). Defaults
  to `hash_password: false` so live validation doesn't hash on every keystroke.
  """
  def change_user_onboarding(%User{} = user, attrs \\ %{}, opts \\ []) do
    User.onboarding_changeset(user, attrs, Keyword.put_new(opts, :hash_password, false))
  end

  @doc """
  Completes owner onboarding: sets the display name + initial password in one update.
  Keeps the current session (the owner just authenticated via their invite link); the
  full profile + password-reset flows arrive in R6.
  """
  def onboard_user(%User{} = user, attrs) do
    user |> User.onboarding_changeset(attrs) |> Repo.update()
  end

  ## Owner onboarding via the platform-host link (R5-selfreg)
  #
  # The self-registered owner finishes setup on `quoteassist.../onboarding/:token`,
  # not while logged in. These functions back that flow: a long-lived (7-day)
  # "onboarding" token is emailed, exchanged for the user, and consumed when the
  # owner sets a password — which also confirms their email in the same transaction.

  @doc """
  Changeset for the onboarding password form. Defaults to `hash_password: false` so
  live validation doesn't hash (or stamp `confirmed_at`) on every keystroke.
  """
  def change_owner_onboarding(%User{} = user, attrs \\ %{}, opts \\ []) do
    User.onboarding_password_changeset(user, attrs, Keyword.put_new(opts, :hash_password, false))
  end

  @doc """
  Issues an onboarding token for `user` and emails the onboarding link built by
  `url_fun`. The link targets the platform host (`/onboarding/:token`) so the same
  flow works regardless of the tenant's host state.
  """
  def deliver_onboarding_instructions(%User{} = user, url_fun) when is_function(url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "onboarding")
    Repo.insert!(user_token)
    UserNotifier.deliver_onboarding_instructions(user, url_fun.(encoded_token))
  end

  @doc "Gets the user for a valid onboarding token, or nil (expired / unknown / used)."
  def get_user_by_onboarding_token(token) when is_binary(token) do
    with {:ok, query} <- UserToken.verify_onboarding_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Completes onboarding: sets the password and confirms the email in one update, then
  deletes all of the user's tokens — so the onboarding link is single-use and any
  stale links are invalidated. Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def complete_onboarding(%User{} = user, attrs) do
    case user
         |> User.onboarding_password_changeset(attrs)
         |> update_user_and_delete_all_tokens() do
      {:ok, {user, _expired_tokens}} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Site admin identity
  #
  # Admins are a fully separate identity (own table + tokens). These functions never
  # touch `users`/`memberships`. `register_admin/1` is the ONLY way to create an admin
  # — there is no HTTP route, seed, or env-var path (see RELEASE_PLAN.md).

  @doc "Gets a live admin by email, or nil."
  def get_admin_by_email(email) when is_binary(email) do
    Repo.one(from a in Admin, where: a.email == ^email and is_nil(a.deleted_at))
  end

  @doc "Gets a live admin by email + password, or nil. Constant-time on a miss."
  def get_admin_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin = Repo.one(from a in Admin, where: a.email == ^email and is_nil(a.deleted_at))
    if Admin.valid_password?(admin, password), do: admin
  end

  @doc "Gets a live admin by id, raising if missing."
  def get_admin!(id), do: Repo.one!(from a in Admin, where: a.id == ^id and is_nil(a.deleted_at))

  @doc "All live admins, ordered by email (for the admin console list)."
  def list_admins do
    Repo.all(from a in Admin, where: is_nil(a.deleted_at), order_by: [asc: a.email])
  end

  @doc "Fetches a live admin by id, or nil. Safe for untrusted ids (bad UUID -> nil)."
  def get_admin(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.one(from a in Admin, where: a.id == ^uuid and is_nil(a.deleted_at))
      :error -> nil
    end
  end

  @doc """
  Registers a **super_admin** — the bootstrap path for the protected root type. Called
  from a Mix task (`mix qa.create_admin`) or an `iex` session, never over HTTP, so the
  "≥1 active super_admin" invariant holds from first setup. Scoped, normal admins are
  created from the console via `create_admin/2`.
  """
  def register_admin(attrs) do
    %Admin{} |> Admin.registration_changeset(attrs) |> Repo.insert()
  end

  @doc "Resets an admin's password (used by `mix qa.create_admin` for idempotency)."
  def update_admin_password(%Admin{} = admin, attrs) do
    admin |> Admin.password_changeset(attrs) |> Repo.update()
  end

  @doc "Stamps `last_sign_in_at` on a successful admin login."
  def update_admin_last_sign_in(%Admin{} = admin) do
    admin
    |> Ecto.Changeset.change(last_sign_in_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc "Generates and stores an admin session token."
  def generate_admin_session_token(%Admin{} = admin) do
    {token, admin_token} = AdminToken.build_session_token(admin)
    Repo.insert!(admin_token)
    token
  end

  @doc """
  Gets the admin for a valid session token (with `:role` preloaded so
  `QuoteAssist.Authz.AdminPolicy` can authorize), or nil.
  """
  def get_admin_by_session_token(token) do
    {:ok, query} = AdminToken.verify_session_token_query(token)

    case Repo.one(query) do
      nil -> nil
      admin -> Repo.preload(admin, :role)
    end
  end

  @doc "Deletes an admin session token (logout)."
  def delete_admin_session_token(token) do
    Repo.delete_all(from(AdminToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Admin RBAC — roles (R4-retrofit)
  #
  # The platform mirror of the tenant role functions in `QuoteAssist.Tenants`.
  # `admin_roles` are platform-global (no tenant_id) and only ever hold normal-admin
  # roles — the `super_admin` protected type carries no role.

  @doc "All live admin roles, ordered by name (for the admin roles console)."
  def list_admin_roles do
    Repo.all(from r in AdminRole, where: is_nil(r.deleted_at), order_by: [asc: r.name])
  end

  @doc "Fetches a live admin role by id, or nil. Safe for untrusted ids (bad UUID -> nil)."
  def get_admin_role(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.one(from r in AdminRole, where: r.id == ^uuid and is_nil(r.deleted_at))
      :error -> nil
    end
  end

  @doc "Fetches a live admin role by slug, or nil."
  def get_admin_role_by_slug(slug) when is_binary(slug) do
    Repo.one(from r in AdminRole, where: r.slug == ^slug and is_nil(r.deleted_at))
  end

  @doc "Changeset backing the admin-role create/edit form."
  def change_admin_role(role \\ %AdminRole{}, attrs \\ %{}) do
    AdminRole.changeset(role, attrs)
  end

  @doc "Creates an admin role (audited, actor = admin)."
  def create_admin_role(%Admin{} = actor, attrs) do
    Repo.transact(fn ->
      with {:ok, role} <- %AdminRole{} |> AdminRole.changeset(attrs) |> Repo.insert() do
        audit_admin(actor, "admin_role.created", "admin_role", role.id, %{"slug" => role.slug})
        {:ok, role}
      end
    end)
  end

  @doc "Edits an admin role's name/description/permissions (audited)."
  def update_admin_role(%Admin{} = actor, %AdminRole{} = role, attrs) do
    Repo.transact(fn ->
      with {:ok, updated} <- role |> AdminRole.changeset(attrs) |> Repo.update() do
        audit_admin(actor, "admin_role.updated", "admin_role", role.id, %{"slug" => updated.slug})
        {:ok, updated}
      end
    end)
  end

  @doc """
  Soft-deletes an admin role (audited). Refuses built-in roles (`:builtin`) and roles
  still assigned to a live admin (`:role_in_use`) — there is no orphaning path.
  """
  def soft_delete_admin_role(%Admin{} = actor, %AdminRole{} = role) do
    cond do
      role.builtin -> {:error, :builtin}
      admin_role_in_use?(role) -> {:error, :role_in_use}
      true -> do_delete_admin_role(actor, role)
    end
  end

  defp do_delete_admin_role(actor, role) do
    Repo.transact(fn ->
      changeset = Ecto.Changeset.change(role, deleted_at: DateTime.utc_now(:second))

      with {:ok, deleted} <- Repo.update(changeset) do
        audit_admin(actor, "admin_role.deleted", "admin_role", role.id, %{"slug" => role.slug})
        {:ok, deleted}
      end
    end)
  end

  @doc "Seeds the built-in admin roles (idempotent — skips existing slugs)."
  def seed_default_admin_roles do
    for spec <- default_admin_role_specs() do
      case get_admin_role_by_slug(spec.slug) do
        nil ->
          {:ok, role} =
            %AdminRole{} |> AdminRole.changeset(Map.put(spec, :builtin, true)) |> Repo.insert()

          role

        %AdminRole{} = role ->
          role
      end
    end
  end

  @doc """
  Built-in admin role specs, composed from the code-owned admin catalog
  (`QuoteAssist.Authz.AdminPermissions`). `super_admin` is a protected *type*, not a
  role (computed all-access), so it is intentionally absent here.
  """
  def default_admin_role_specs do
    [
      %{
        slug: "operations",
        name: "Operations",
        description: "Manages agencies and their lifecycle.",
        permissions: ~w(tenant:list tenant:create tenant:read tenant:update
                        tenant:activate tenant:deactivate tenant:suspend tenant:cancel
                        plan:list plan:read admin:list admin:read audit:list audit:read)
      },
      %{
        slug: "support",
        name: "Support",
        description: "Read-only platform visibility for support staff.",
        permissions: ~w(tenant:list tenant:read plan:list plan:read
                        admin:list admin:read admin_role:list admin_role:read
                        audit:list audit:read)
      }
    ]
  end

  defp admin_role_in_use?(%AdminRole{id: role_id}) do
    Repo.exists?(from a in Admin, where: a.role_id == ^role_id and is_nil(a.deleted_at))
  end

  ## Admin RBAC — admins (R4-retrofit)
  #
  # The `super_admin` protected type is enforced at the QUERY layer, not the view: a
  # non-super-admin's admin lists EXCLUDE super_admins (`list_admins_visible_to/1` +
  # `get_admin_visible_to/2`), and the last-active-super_admin guard runs in the same
  # transaction as the mutation (`SELECT … FOR UPDATE`) so it can't be raced past.

  @doc """
  Live admins visible to `actor`, with `:role` preloaded, ordered by email. A
  super_admin sees everyone; a normal admin sees only normal admins — the protected
  type is filtered out in the query, never merely hidden in the template.
  """
  def list_admins_visible_to(%Admin{type: :super_admin}) do
    Repo.all(from a in admins_with_role(), order_by: [asc: a.email])
  end

  def list_admins_visible_to(%Admin{}) do
    Repo.all(from a in admins_with_role(), where: a.type == :admin, order_by: [asc: a.email])
  end

  @doc """
  A single live admin (with `:role`) visible to `actor`, or nil. A normal admin can
  never load a super_admin (the exclusion is in the query), so editing/viewing one is
  impossible by any path — not just hidden in the UI.
  """
  def get_admin_visible_to(%Admin{} = actor, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        base = from a in admins_with_role(), where: a.id == ^uuid

        query =
          case actor.type do
            :super_admin -> base
            :admin -> from a in base, where: a.type == :admin
          end

        Repo.one(query)

      :error ->
        nil
    end
  end

  @doc "Live admins assigned to a given admin role, ordered by email (for the role detail)."
  def list_admins_for_role(%AdminRole{id: role_id}) do
    Repo.all(
      from a in Admin,
        where: a.role_id == ^role_id and is_nil(a.deleted_at),
        order_by: [asc: a.email]
    )
  end

  defp admins_with_role do
    from a in Admin, where: is_nil(a.deleted_at), preload: [:role]
  end

  @doc "Changeset backing the create-admin form (email + password + role)."
  def change_admin_creation(attrs \\ %{}) do
    Admin.create_changeset(%Admin{}, attrs, hash_password: false)
  end

  @doc "Changeset backing the reassign-role form for a normal admin."
  def change_admin(%Admin{} = admin, attrs \\ %{}) do
    Admin.role_changeset(admin, attrs)
  end

  @doc """
  Creates a **normal** admin (type `:admin`, with a role), audited. The protected type
  is never reachable here — `Admin.create_changeset/3` forces `:admin`.
  """
  def create_admin(%Admin{} = actor, attrs) do
    Repo.transact(fn ->
      with {:ok, admin} <- %Admin{} |> Admin.create_changeset(attrs) |> Repo.insert() do
        audit_admin(actor, "admin.created", "admin", admin.id, %{
          "email" => mask_email(admin.email),
          "role_id" => admin.role_id
        })

        {:ok, admin}
      end
    end)
  end

  @doc """
  Reassigns a normal admin's role (audited). Refuses a super_admin target
  (`:super_admin_has_no_role`) — the protected type's access is computed, not a role.
  """
  def update_admin_role_assignment(%Admin{}, %Admin{type: :super_admin}, _attrs) do
    {:error, :super_admin_has_no_role}
  end

  def update_admin_role_assignment(%Admin{} = actor, %Admin{} = target, attrs) do
    Repo.transact(fn ->
      with {:ok, updated} <- target |> Admin.role_changeset(attrs) |> Repo.update() do
        audit_admin(actor, "admin.role_changed", "admin", target.id, %{
          "role_id" => updated.role_id
        })

        {:ok, updated}
      end
    end)
  end

  @doc "Reactivates a deactivated admin (audited)."
  def activate_admin(%Admin{} = actor, %Admin{} = target) do
    Repo.transact(fn ->
      with {:ok, updated} <- target |> Ecto.Changeset.change(active: true) |> Repo.update() do
        audit_admin(actor, "admin.activated", "admin", target.id, %{
          "email" => mask_email(target.email)
        })

        {:ok, updated}
      end
    end)
  end

  @doc """
  Deactivates an admin and revokes their sessions in the same transaction
  (cross-cutting session-revocation rule). Refuses the last active super_admin
  (`:last_super_admin`); the count + mutation run under a row lock so concurrent
  deactivations can't race past the guard.
  """
  def deactivate_admin(%Admin{} = actor, %Admin{} = target) do
    Repo.transact(fn ->
      if last_active_super_admin?(target),
        do: {:error, :last_super_admin},
        else: do_deactivate_admin(actor, target)
    end)
  end

  defp do_deactivate_admin(actor, target) do
    with {:ok, updated} <- target |> Ecto.Changeset.change(active: false) |> Repo.update() do
      revoke_admin_sessions(updated)

      audit_admin(actor, "admin.deactivated", "admin", target.id, %{
        "email" => mask_email(target.email)
      })

      {:ok, updated}
    end
  end

  @doc """
  Soft-deletes an admin (sets `deleted_at`, flips `active`), revokes their sessions,
  and audits it. Refuses the last active super_admin (`:last_super_admin`) under the
  same transactional guard as `deactivate_admin/2`.
  """
  def soft_delete_admin(%Admin{} = actor, %Admin{} = target) do
    Repo.transact(fn ->
      if last_active_super_admin?(target),
        do: {:error, :last_super_admin},
        else: do_soft_delete_admin(actor, target)
    end)
  end

  defp do_soft_delete_admin(actor, target) do
    changeset =
      Ecto.Changeset.change(target, deleted_at: DateTime.utc_now(:second), active: false)

    with {:ok, deleted} <- Repo.update(changeset) do
      revoke_admin_sessions(deleted)

      audit_admin(actor, "admin.deleted", "admin", target.id, %{
        "email" => mask_email(target.email)
      })

      {:ok, deleted}
    end
  end

  @doc "Count of live, active super_admins — the input to the last-active guard."
  def active_super_admin_count do
    Repo.aggregate(active_super_admins_query(), :count, :id)
  end

  # True only when `target` is itself an active super_admin AND it is the last one.
  # Locks the active super_admin rows (`FOR UPDATE`) so two concurrent deactivations
  # inside their own transactions serialise on the same rows and can't both pass.
  defp last_active_super_admin?(%Admin{type: :super_admin, active: true}) do
    ids = Repo.all(from a in active_super_admins_query(), lock: "FOR UPDATE", select: a.id)
    length(ids) <= 1
  end

  defp last_active_super_admin?(_target), do: false

  defp active_super_admins_query do
    from a in Admin, where: a.type == :super_admin and a.active == true and is_nil(a.deleted_at)
  end

  defp revoke_admin_sessions(%Admin{id: id}) do
    Repo.delete_all(from t in AdminToken, where: t.admin_id == ^id)
    :ok
  end

  # Append-only audit row for an admin action (platform — tenant_id nil). `actor_subtype`
  # captures the acting admin's tier (super_admin | admin), per the audit schema.
  defp audit_admin(%Admin{} = actor, action, target_type, target_id, metadata) do
    Audit.log!(%{
      actor_type: :admin,
      actor_subtype: actor.type,
      actor_id: actor.id,
      tenant_id: nil,
      action: action,
      target_type: target_type,
      target_id: target_id,
      metadata: metadata
    })
  end

  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, domain] -> "#{String.first(local)}***@#{domain}"
      _ -> "***"
    end
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
