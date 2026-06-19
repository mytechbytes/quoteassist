defmodule QuoteAssist.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :display_name, :string
    field :confirmed_at, :utc_datetime
    field :deleted_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  @doc """
  Changeset for registering a self-service owner (R5-selfreg): email + the display
  name they typed on the signup form, set together at creation. The password is set
  later, at onboarding (`onboarding_password_changeset/3`). Used only when the email
  is new — an existing user is reused as-is, name untouched.
  """
  def owner_registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :display_name])
    |> validate_email(opts)
    |> validate_required([:display_name])
    |> validate_length(:display_name, min: 1, max: 80)
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
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Changeset for first-time owner onboarding (R3): set a display name and an initial
  password together. Reuses the password validation/hashing below.

  ## Options

    * `:hash_password` - hash + clear the virtual password (default `true`). Pass
      `false` for live form validation.
  """
  def onboarding_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:display_name, :password])
    |> validate_required([:display_name])
    |> validate_length(:display_name, min: 1, max: 80)
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Changeset for the platform-host onboarding link (R5-selfreg): set the initial
  password **and** confirm the email in a single update. Setting `hashed_password`
  and `confirmed_at` together is the one "ready to log in" predicate, so they must
  land in the same changeset (and therefore the same transaction). The display name
  was already captured at registration, so it is not collected here.

  ## Options

    * `:hash_password` - hash + clear the virtual password (default `true`). Pass
      `false` for live form validation.
  """
  def onboarding_password_changeset(user, attrs, opts \\ []) do
    changeset =
      user
      |> cast(attrs, [:password])
      |> validate_confirmation(:password, message: "does not match password")
      |> validate_password(opts)

    # Confirm the email alongside the password — but only on a valid, persisting
    # changeset (so live validation with `hash_password: false` never stamps it),
    # and only when not already confirmed (a reused, already-confirmed owner keeps
    # their original `confirmed_at`).
    if changeset.valid? and Keyword.get(opts, :hash_password, true) and is_nil(user.confirmed_at) do
      put_change(changeset, :confirmed_at, DateTime.utc_now(:second))
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%QuoteAssist.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
