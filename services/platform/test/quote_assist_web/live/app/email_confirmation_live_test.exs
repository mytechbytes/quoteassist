defmodule QuoteAssistWeb.App.EmailConfirmationLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.UserToken
  alias QuoteAssist.Repo
  alias QuoteAssist.Tenants

  setup %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    user = set_password(user_fixture())
    {:ok, _membership} = Tenants.create_membership(tenant, user, role_for(tenant))
    %{conn: log_in_member(conn, user, tenant), user: user, tenant: tenant}
  end

  defp role_for(tenant), do: Tenants.get_role_by_slug(tenant, "agent")

  # Mints a change-email token the way the initiation path does: hashed token in the DB,
  # sent_to = the NEW address, context = "change:<old address>".
  defp change_token(user, new_email) do
    {encoded, user_token} =
      UserToken.build_email_token(%{user | email: new_email}, "change:#{user.email}")

    Repo.insert!(user_token)
    encoded
  end

  test "confirms the email change and redirects to the account page", %{conn: conn, user: user} do
    new_email = "fresh-#{System.unique_integer([:positive])}@example.com"
    token = change_token(user, new_email)

    assert {:error, {:redirect, %{to: "/app/account"}}} =
             live(conn, ~p"/account/confirm-email/#{token}")

    assert Accounts.get_user!(user.id).email == new_email
  end

  test "shows the expired state for an invalid token and leaves the email unchanged", %{
    conn: conn,
    user: user
  } do
    {:ok, _lv, html} = live(conn, ~p"/account/confirm-email/not-a-real-token")

    assert html =~ "This link has expired"
    assert Accounts.get_user!(user.id).email == user.email
  end

  test "redirects to /login when not authenticated", %{tenant: tenant} do
    conn = build_conn() |> put_tenant_host(tenant)

    assert {:error, {:redirect, %{to: "/login"}}} =
             live(conn, ~p"/account/confirm-email/whatever")
  end
end
