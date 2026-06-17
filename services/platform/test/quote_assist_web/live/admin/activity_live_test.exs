defmodule QuoteAssistWeb.Admin.ActivityLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Tenants

  test "redirects to /admin/login when not signed in", %{conn: conn} do
    assert {:error, {kind, %{to: "/admin/login"}}} = live(conn, ~p"/admin/activity")
    assert kind in [:redirect, :live_redirect]
  end

  describe "signed in" do
    setup :register_and_log_in_admin

    test "renders recent platform activity", %{conn: conn, admin: admin} do
      plan = plan_fixture()

      {:ok, _tenant} =
        Tenants.create_tenant_with_owner(admin, %{
          "name" => "Acme Travel",
          "slug" => "acme",
          "owner_email" => "o@acme.test",
          "plan_id" => plan.id
        })

      {:ok, _lv, html} = live(conn, ~p"/admin/activity")
      assert html =~ "Activity"
      assert html =~ "Tenant created"
    end
  end
end
