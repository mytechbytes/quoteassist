defmodule QuoteAssistWeb.AppHomeLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts

  describe "/app access control" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = put_tenant_host(conn, tenant)

      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/app")
    end

    test "redirects to /login when authenticated but not a member of the tenant", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      # A user with no membership for this tenant.
      conn = log_in_member(conn, user_fixture(), tenant)

      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/app")
    end

    test "redirects to /login on the platform host (no tenant resolved)", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      # Authenticated, but host stays www.example.com → platform → no tenant.
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/app")
    end
  end

  describe "/app workspace shell" do
    setup :register_and_log_in_member

    test "renders the workspace for a member", %{conn: conn, user: user, tenant: tenant} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ tenant.name
      assert html =~ user.email
      # Role badge + sidebar nav from the shell chrome.
      assert html =~ "Owner"
      assert html =~ "Overview"
      assert html =~ ~p"/logout"
    end

    @tag role: "agent"
    test "shows the member's role in the shell", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")
      assert html =~ "Agent"
    end
  end
end
