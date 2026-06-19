defmodule QuoteAssist.Accounts.Admin do
  @moduledoc """
  A site administrator — a completely separate identity from tenant `User`
  (RELEASE_PLAN.md). No `tenant_id`, no membership, no shared `Scope`. Credentials
  live only as a bcrypt hash. Soft-deleted via `deleted_at`; email is unique among
  live rows (citext).

  ## `type` — the protected-type pattern (R4-retrofit)

  A `type` sits above the role and gates authorization before any role check
  (`QuoteAssist.Authz.AdminPolicy`):

    * `:super_admin` — the protected root type. Computed all-access (a short-circuit
      `true`), so it carries **no** `role_id`. Created only via
      `QuoteAssist.Accounts.register_admin/1` (`mix qa.create_admin`) — there is no
      HTTP/console path to mint or assign one, which is exactly the
      "unassignable by lower types" invariant.
    * `:admin` — the normal type. Authorization is role-driven, so a `role_id` is
      **required**. Created from the admin console by an authorised admin.

  `active` gates *future* logins (deactivation); `deleted_at` is removal. A normal
  admin keeps no role when none is meaningful, but the console always assigns one.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Accounts.AdminRole

  @types [:super_admin, :admin]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admins" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :type, Ecto.Enum, values: @types, default: :admin
    field :active, :boolean, default: true
    field :last_sign_in_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :role, AdminRole

    timestamps(type: :utc_datetime)
  end

  @doc "All valid admin types."
  def types, do: @types

  @doc "Human label for an admin type."
  def type_label(:super_admin), do: "Super admin"
  def type_label(:admin), do: "Admin"

  @doc """
  Registration changeset: email + password, both required. Unlike a tenant `User`
  (magic-link first, opt-in password), an admin always has a password set at
  creation. Used only by `Accounts.register_admin/1`, which is the bootstrap path,
  so the new admin is forced to **`super_admin`** (no role) — there is always ≥1
  super_admin from first setup.

  ## Options

    * `:hash_password` - hash + clear the virtual password (default `true`).
    * `:validate_unique` - validate email uniqueness (default `true`).
  """
  def registration_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:email, :password])
    |> put_change(:type, :super_admin)
    |> put_change(:role_id, nil)
    |> validate_email(opts)
    |> validate_password(opts)
  end

  @doc """
  Changeset for creating a **normal** admin from the console: email + password + a
  required `role_id`. `type` is forced to `:admin` so no console path can mint a
  `super_admin` (the protected type is bootstrap-only).

  Accepts the same `:hash_password` / `:validate_unique` options as
  `registration_changeset/3`.
  """
  def create_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:email, :password, :role_id])
    |> put_change(:type, :admin)
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_required([:role_id])
    |> assoc_constraint(:role)
  end

  @doc """
  Changeset for reassigning a normal admin's role. `type` is never cast here, so this
  path can neither promote to nor demote from `super_admin` — it only swaps the role
  of an already-normal admin.
  """
  def role_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:role_id])
    |> validate_required([:role_id])
    |> assoc_constraint(:role)
  end

  @doc "Changeset for (re)setting an admin password — used by `mix qa.create_admin`."
  def password_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:password])
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, QuoteAssist.Repo)
      |> unique_constraint(:email, name: :admins_email_live_index)
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Verifies the password. Calls `Bcrypt.no_user_verify/0` when there is no admin or no
  hash, to keep the timing constant and avoid enumeration.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
