defmodule QuoteAssist.Accounts.Admin do
  @moduledoc """
  A site administrator — a completely separate identity from tenant `User`
  (RELEASE_PLAN.md). No `tenant_id`, no membership, no shared `Scope`. The only way
  to create one is `QuoteAssist.Accounts.register_admin/1` (via `mix qa.create_admin`);
  there is no HTTP route, seed, or env-var path. Credentials live only as a bcrypt
  hash. Soft-deleted via `deleted_at`; email is unique among live rows (citext).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admins" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :last_sign_in_at, :utc_datetime
    field :deleted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Registration changeset: email + password, both required. Unlike a tenant `User`
  (magic-link first, opt-in password), an admin always has a password set at
  creation. Only `Accounts.register_admin/1` uses this.

  ## Options

    * `:hash_password` - hash + clear the virtual password (default `true`).
    * `:validate_unique` - validate email uniqueness (default `true`).
  """
  def registration_changeset(admin, attrs, opts \\ []) do
    admin
    |> cast(attrs, [:email, :password])
    |> validate_email(opts)
    |> validate_password(opts)
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
