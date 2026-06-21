defmodule QuoteAssistWeb.AppHomeLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.QuotesFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Audit
  alias QuoteAssist.Tenants

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

  describe "dashboard — owner (computed all-access)" do
    setup :register_and_log_in_member

    test "renders the workspace shell chrome", %{conn: conn, user: user, tenant: tenant} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ tenant.name
      assert html =~ user.email
      assert html =~ "Owner"
      assert html =~ "Overview"
      assert html =~ ~p"/logout"
    end

    test "shows a greeting, the KPI tiles, and quick links", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/app")

      assert html =~ "Welcome back"
      # KPI tiles (owner holds everything) — checked by their stable data-stat hooks.
      assert html =~ "Open requests"
      assert has_element?(lv, "[data-stat='quoted-this-month']")
      assert has_element?(lv, "[data-stat='total-quotes']")
      assert has_element?(lv, "[data-stat='team-size']")
      # Recent-quotes table + enquiry queue are present for a quote:list holder.
      assert html =~ "Recent quotes"
      assert html =~ "Enquiry queue"
      # Quick links.
      assert html =~ "Team &amp; access"
      assert html =~ "Roles &amp; permissions"
      assert html =~ "Your account"
    end

    test "lists recent quotes and surfaces open leads in the queue", %{
      conn: conn,
      tenant: tenant,
      user: user,
      membership: membership
    } do
      scope = scope_fixture(tenant, user, membership)
      quote_request_fixture(scope, %{"customer_name" => "Open Lead"})

      {:ok, _lv, html} = live(conn, ~p"/app")
      assert html =~ "Open Lead"
      # The open lead shows in the enquiry queue with a "New" status pip.
      assert html =~ "New"
    end

    test "team size reflects the live, active membership count", %{conn: conn, tenant: tenant} do
      # Seed two more members so the count is 3 (owner + 2).
      member_fixture(tenant, "agent")
      member_fixture(tenant, "manager")

      {:ok, lv, _html} = live(conn, ~p"/app")
      assert Tenants.active_member_count(tenant) == 3
      assert has_element?(lv, "[data-stat='team-size']", "3")
    end

    test "renders recent tenant activity from the audit log", %{conn: conn, tenant: tenant} do
      Audit.log!(%{
        actor_type: :user,
        tenant_id: tenant.id,
        action: "user.invited",
        target_type: "user",
        target_id: Ecto.UUID.generate(),
        metadata: %{}
      })

      {:ok, _lv, html} = live(conn, ~p"/app")
      assert html =~ "Recent activity"
      assert html =~ "User invited"
    end

    test "shows the quotes empty state for a brand-new tenant", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")
      assert html =~ "No quote requests yet"
    end
  end

  describe "dashboard — permission gating" do
    setup %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      role = role_fixture(tenant, %{permissions: []})
      user = user_fixture()
      {:ok, membership} = Tenants.create_membership(tenant, user, role)

      %{
        conn: log_in_member(conn, user, tenant),
        tenant: tenant,
        user: user,
        membership: membership
      }
    end

    test "a member with an empty role sees no gated cards or links", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/app")

      # No KPIs, recent-quotes table, or enquiry queue they can't see.
      refute has_element?(lv, "[data-stat='open-requests']")
      refute has_element?(lv, "[data-stat='team-size']")
      refute html =~ "Recent quotes"
      refute html =~ "Enquiry queue"
      refute html =~ "Team &amp; access"
      refute html =~ "Roles &amp; permissions"

      # But the always-available surface is still there.
      assert html =~ "Recent activity"
      assert html =~ "Your account"
      assert html =~ ~p"/app/requests"
    end
  end
end
