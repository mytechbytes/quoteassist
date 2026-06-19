defmodule QuoteAssist.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuoteAssist.Accounts` context.
  """

  import Ecto.Query

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.{Admin, AdminRole, Scope}

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  ## Site admins

  def unique_admin_email, do: "admin#{System.unique_integer([:positive])}@example.com"
  def valid_admin_password, do: "admin password 123"

  @doc "A super_admin (the protected root type) — what `register_admin/1` produces."
  def admin_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: unique_admin_email(),
        password: valid_admin_password()
      })

    {:ok, admin} = Accounts.register_admin(attrs)
    admin
  end

  @doc "An admin role with the given (or no) permissions — inserted directly."
  def admin_role_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Role #{System.unique_integer([:positive])}",
        slug: "adminrole#{System.unique_integer([:positive])}",
        permissions: []
      })

    {:ok, role} = %AdminRole{} |> AdminRole.changeset(attrs) |> QuoteAssist.Repo.insert()
    role
  end

  @doc """
  A normal (scoped) admin with a role, with `:role` preloaded. Pass a role, or a list
  of permission keys (a fresh role is built for them), or nothing (an empty role).
  """
  def normal_admin_fixture(role_or_perms \\ [], attrs \\ %{})

  def normal_admin_fixture(%AdminRole{} = role, attrs) do
    attrs =
      Enum.into(attrs, %{
        email: unique_admin_email(),
        password: valid_admin_password(),
        role_id: role.id
      })

    {:ok, admin} = %Admin{} |> Admin.create_changeset(attrs) |> QuoteAssist.Repo.insert()
    QuoteAssist.Repo.preload(admin, :role)
  end

  def normal_admin_fixture(permissions, attrs) when is_list(permissions) do
    normal_admin_fixture(admin_role_fixture(%{permissions: permissions}), attrs)
  end

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} =
      Accounts.login_user_by_magic_link(token)

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    QuoteAssist.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    QuoteAssist.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    QuoteAssist.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
