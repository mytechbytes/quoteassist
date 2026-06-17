defmodule QuoteAssistWeb.Admin.DashboardLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Tenants

  describe "access control" do
    test "redirects to /admin/login when not signed in", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/login"}}} = live(conn, ~p"/admin")
      assert kind in [:redirect, :live_redirect]
    end
  end

  describe "signed in" do
    setup :register_and_log_in_admin

    test "renders the overview", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Platform overview"
    end

    test "shows a created tenant in the recent list", %{conn: conn, admin: admin} do
      plan = plan_fixture()

      {:ok, _tenant} =
        Tenants.create_tenant_with_owner(admin, %{
          "name" => "Acme Travel",
          "slug" => "acme",
          "owner_email" => "owner@acme.test",
          "plan_id" => plan.id
        })

      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Acme Travel"
    end
  end
end
