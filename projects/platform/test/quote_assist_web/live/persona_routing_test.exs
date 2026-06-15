defmodule QuoteAssistWeb.PersonaRoutingTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures

  describe "launcher" do
    test "shows only the personas the user holds", %{conn: conn} do
      {user, _membership} = user_with_persona_fixture(:site_admin)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/launcher")

      assert html =~ "Site Administrator"
      refute html =~ "Agency Admin"
      refute html =~ "Sales Person"
    end

    test "shows a tile per persona for a multi-persona user", %{conn: conn} do
      user = user_fixture()
      tenant = tenant_fixture()
      membership_fixture(user, :agency_admin, %{tenant_id: tenant.id})
      membership_fixture(user, :salesperson, %{tenant_id: tenant.id, seller_level: "Senior"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/launcher")

      assert html =~ "Agency Admin"
      assert html =~ "Sales Person"
      refute html =~ "Site Administrator"
    end

    test "redirects to log in when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/launcher")
    end
  end

  describe "workspace access" do
    test "site admin reaches /admin", %{conn: conn} do
      {user, _} = user_with_persona_fixture(:site_admin)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Platform overview"
    end

    test "agency admin reaches /agency and sees their tenant", %{conn: conn} do
      tenant = tenant_fixture(name: "Globex Trading")
      {user, _} = user_with_persona_fixture(:agency_admin, tenant: tenant)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/agency")
      assert html =~ "Globex Trading"
    end

    test "salesperson reaches /app", %{conn: conn} do
      {user, _} = user_with_persona_fixture(:salesperson, seller_level: "Senior")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/app")
      assert html =~ "Your workspace"
    end

    test "a salesperson is bounced from /admin to the launcher", %{conn: conn} do
      {user, _} = user_with_persona_fixture(:salesperson)
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/launcher"}}} = live(conn, ~p"/admin")
    end

    test "a site admin is bounced from /agency to the launcher", %{conn: conn} do
      {user, _} = user_with_persona_fixture(:site_admin)
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/launcher"}}} = live(conn, ~p"/agency")
    end

    test "unauthenticated access to a workspace redirects to log in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/admin")
    end
  end
end
