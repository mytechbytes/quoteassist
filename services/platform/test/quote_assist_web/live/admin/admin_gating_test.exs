defmodule QuoteAssistWeb.Admin.AdminGatingTest do
  @moduledoc """
  Cross-cutting checks that every retro-gated admin LiveView bounces an admin who
  lacks the area's permission back to the console home, and that a scoped admin with
  the matching permission gets in (the protected-type predicate via a role).
  """
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.PlansFixtures
  import QuoteAssist.TenantsFixtures

  describe "a normal admin with no permissions" do
    @describetag admin_permissions: []
    setup :register_and_log_in_normal_admin

    test "reaches the console home (no permission gate, no redirect loop)", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Platform overview"
    end

    test "is bounced from every gated area to /admin", %{conn: conn} do
      tenant = tenant_fixture()
      plan = plan_fixture()
      role = admin_role_fixture()

      paths = [
        ~p"/admin/tenants",
        ~p"/admin/tenants/#{tenant.id}",
        ~p"/admin/plans",
        ~p"/admin/plans/#{plan.id}",
        ~p"/admin/admins",
        ~p"/admin/roles",
        ~p"/admin/roles/#{role.id}",
        ~p"/admin/activity"
      ]

      for path <- paths do
        assert {:error, {kind, %{to: "/admin"}}} = live(conn, path)
        assert kind in [:redirect, :live_redirect], "expected #{path} to bounce to /admin"
      end
    end
  end

  describe "a scoped admin with a matching permission" do
    setup :register_and_log_in_normal_admin

    @tag admin_permissions: ["audit:list"]
    test "is allowed into the area its role grants", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/activity")
      assert html =~ "Activity"
    end

    @tag admin_permissions: ["tenant:list"]
    test "tenant:list opens the agencies list", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/tenants")
      assert html =~ "Agencies"
    end
  end
end
