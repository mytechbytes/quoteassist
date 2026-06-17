defmodule QuoteAssistWeb.Admin.TenantShowTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Tenants

  test "redirects to /admin/login when not signed in", %{conn: conn} do
    assert {:error, {kind, %{to: "/admin/login"}}} =
             live(conn, ~p"/admin/tenants/#{Ecto.UUID.generate()}")

    assert kind in [:redirect, :live_redirect]
  end

  describe "signed in" do
    setup :register_and_log_in_admin

    setup %{admin: admin} do
      plan = plan_fixture()

      {:ok, tenant} =
        Tenants.create_tenant_with_owner(admin, %{
          "name" => "Acme Travel",
          "slug" => "acme",
          "owner_email" => "owner@acme.test",
          "plan_id" => plan.id
        })

      %{tenant: tenant, plan: plan}
    end

    test "renders the profile, members, and audit timeline", %{conn: conn, tenant: tenant} do
      {:ok, _lv, html} = live(conn, ~p"/admin/tenants/#{tenant.id}")
      assert html =~ "Acme Travel"
      assert html =~ "owner@acme.test"
      assert html =~ "Owner"
      assert html =~ "Activity"
      assert html =~ "Tenant created"
    end

    test "redirects to the index for an unknown tenant", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/tenants"}}} =
               live(conn, ~p"/admin/tenants/#{Ecto.UUID.generate()}")

      assert kind in [:redirect, :live_redirect]
    end

    test "suspends and reactivates from the detail page", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants/#{tenant.id}")

      lv |> element("button", "Suspend") |> render_click()
      assert Tenants.get_tenant_for_admin(tenant.id).status == :suspended

      lv |> element("button", "Reactivate") |> render_click()
      assert Tenants.get_tenant_for_admin(tenant.id).status == :active
    end

    test "edits the name from the detail page", %{conn: conn, tenant: tenant, plan: plan} do
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants/#{tenant.id}")

      lv |> element("button", "Edit") |> render_click()

      html =
        lv
        |> form("#tenant-edit-form", tenant: %{name: "Renamed Co", plan_id: plan.id})
        |> render_submit()

      assert html =~ "Renamed Co"
    end

    test "soft-deletes and redirects to the index", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants/#{tenant.id}")

      lv |> element("button", "Remove") |> render_click()

      assert {:error, {kind, %{to: "/admin/tenants"}}} =
               lv |> element("button", "Remove agency") |> render_click()

      assert kind in [:redirect, :live_redirect]
      refute Tenants.get_tenant_for_admin(tenant.id)
    end
  end
end
