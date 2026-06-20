defmodule QuoteAssistWeb.Admin.TenantLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Tenants

  describe "access control" do
    test "redirects to /admin/login when not signed in", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/login"}}} = live(conn, ~p"/admin/tenants")
      assert kind in [:redirect, :live_redirect]
    end
  end

  describe "signed in" do
    setup [:register_and_log_in_admin, :with_plan]

    test "lists tenants with owner email", %{conn: conn, admin: admin, plan: plan} do
      {:ok, _} = create(admin, plan, "Acme Travel", "acme", "owner@acme.test")
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants")
      assert render(lv) =~ "Acme Travel"
      assert render(lv) =~ "owner@acme.test"
    end

    test "creates a tenant + owner on the dedicated page (slug auto-fills)", %{
      conn: conn,
      plan: plan
    } do
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants/new")

      # the slug derives from the name as you type
      html = lv |> form("#tenant-form", tenant: %{name: "Globex Inc"}) |> render_change()
      assert html =~ "globex-inc"

      lv
      |> form("#tenant-form",
        tenant: %{
          name: "Globex",
          slug: "globex",
          owner_email: "owner@globex.test",
          plan_id: plan.id
        }
      )
      |> render_submit()

      tenant = Tenants.get_tenant_by_slug("globex")
      assert tenant.status == :trial
      assert tenant.plan_id == plan.id
      assert Accounts.get_user_by_email("owner@globex.test")
    end

    test "shows validation errors for an invalid create", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants/new")

      html =
        lv
        |> form("#tenant-form", tenant: %{name: "X", slug: "xy", owner_email: "", plan_id: ""})
        |> render_submit()

      assert html =~ "blank"
    end

    test "suspends and reactivates a tenant", %{conn: conn, admin: admin, plan: plan} do
      {:ok, tenant} = create(admin, plan, "Acme", "acme", "o@acme.test")
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants")

      lv |> element("#tenant-#{tenant.id} button", "Suspend") |> render_click()
      assert Tenants.get_tenant_for_admin(tenant.id).status == :suspended

      lv |> element("#tenant-#{tenant.id} button", "Reactivate") |> render_click()
      assert Tenants.get_tenant_for_admin(tenant.id).status == :active
    end

    test "soft-deletes a tenant via the confirm modal", %{conn: conn, admin: admin, plan: plan} do
      {:ok, tenant} = create(admin, plan, "Acme", "acme", "o@acme.test")
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants")

      lv |> element("#tenant-#{tenant.id} button", "Remove") |> render_click()
      lv |> element("button", "Remove agency") |> render_click()

      refute has_element?(lv, "#tenant-#{tenant.id}")
      refute Tenants.get_tenant_for_admin(tenant.id)
    end

    test "edits a tenant's name on the dedicated page", %{conn: conn, admin: admin, plan: plan} do
      {:ok, tenant} = create(admin, plan, "Acme", "acme", "o@acme.test")
      {:ok, lv, _html} = live(conn, ~p"/admin/tenants/#{tenant.id}/edit")

      lv
      |> form("#tenant-form", tenant: %{name: "Acme Renamed", plan_id: plan.id})
      |> render_submit()

      assert Tenants.get_tenant_for_admin(tenant.id).name == "Acme Renamed"
    end
  end

  defp with_plan(_context), do: %{plan: plan_fixture()}

  defp create(admin, plan, name, slug, email) do
    Tenants.create_tenant_with_owner(admin, %{
      "name" => name,
      "slug" => slug,
      "owner_email" => email,
      "plan_id" => plan.id
    })
  end
end
