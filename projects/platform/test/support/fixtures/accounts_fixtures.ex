defmodule QuoteAssist.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuoteAssist.Accounts` context.
  """

  import Ecto.Query

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Policy
  alias QuoteAssist.Tenancy

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  @doc "Creates a tenant."
  def tenant_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, tenant} =
      attrs
      |> Enum.into(%{name: "Acme #{n}", slug: "acme-#{n}"})
      |> Tenancy.create_tenant()

    tenant
  end

  @doc "Creates a system (tenant-less) role for a persona, with its default permissions."
  def system_role_fixture(persona) when is_atom(persona) do
    {:ok, role} =
      Accounts.create_role(%{
        name: "#{persona}-#{System.unique_integer([:positive])}",
        permissions: Policy.permissions_for(persona)
      })

    role
  end

  @doc "Creates a membership granting `user` a persona (pass `tenant_id` for tenant personas)."
  def membership_fixture(user, persona, attrs \\ %{}) do
    {:ok, membership} =
      attrs
      |> Enum.into(%{user_id: user.id, persona: persona})
      |> Accounts.create_membership()

    membership
  end

  @doc """
  Confirmed user holding a single persona. For tenant personas a tenant is created
  (or taken from `attrs[:tenant]`). Returns `{user, membership}`.
  """
  def user_with_persona_fixture(persona, attrs \\ %{}) do
    user = user_fixture()
    role = system_role_fixture(persona)

    membership_attrs =
      case persona do
        :site_admin ->
          %{role_id: role.id}

        _ ->
          tenant = attrs[:tenant] || tenant_fixture()
          %{tenant_id: tenant.id, role_id: role.id, seller_level: attrs[:seller_level]}
      end

    {user, membership_fixture(user, persona, membership_attrs)}
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
