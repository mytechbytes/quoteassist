defmodule QuoteAssistWeb.Admin.PlanLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Plans
  alias QuoteAssist.Tenants

  test "index redirects to /admin/login when not signed in", %{conn: conn} do
    assert {:error, {kind, %{to: "/admin/login"}}} = live(conn, ~p"/admin/plans")
    assert kind in [:redirect, :live_redirect]
  end

  describe "signed in" do
    setup :register_and_log_in_admin

    test "lists plans", %{conn: conn} do
      plan_fixture(%{name: "Starter", slug: "starter"})
      {:ok, _lv, html} = live(conn, ~p"/admin/plans")
      assert html =~ "Starter"
    end

    test "New plan links to the dedicated create page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/plans")
      assert has_element?(lv, ~s{#new-plan[href="/admin/plans/new"]})
    end

    test "creates a plan on the dedicated page (slug auto-fills from the name)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/plans/new")

      # typing the name live-derives the slug
      html = lv |> form("#plan-form", plan: %{name: "Enterprise Tier"}) |> render_change()
      assert html =~ "enterprise-tier"

      lv
      |> form("#plan-form",
        plan: %{name: "Enterprise", slug: "enterprise", price: 49_900, interval: "monthly"}
      )
      |> render_submit()

      assert Plans.get_plan_by_slug("enterprise")
    end

    test "edits a plan on the dedicated page", %{conn: conn} do
      plan = plan_fixture(%{name: "Growth", slug: "growth"})
      {:ok, lv, _html} = live(conn, ~p"/admin/plans/#{plan.id}/edit")

      lv |> form("#plan-form", plan: %{name: "Growth Plus", price: 19_900}) |> render_submit()

      assert Plans.get_plan(plan.id).name == "Growth Plus"
    end

    test "detail page shows the plan's activity", %{conn: conn, admin: admin} do
      plan = plan_fixture(%{name: "Growth", slug: "growth"})
      {:ok, _} = Plans.admin_update_plan(admin, plan, %{"name" => "Growth Plus"})

      {:ok, _lv, html} = live(conn, ~p"/admin/plans/#{plan.id}")
      assert html =~ "Activity"
      refute html =~ "No activity for this plan yet."
    end

    test "detail page lists tenants on the plan", %{conn: conn, admin: admin} do
      plan = plan_fixture()

      {:ok, _tenant} =
        Tenants.create_tenant_with_owner(admin, %{
          "name" => "Acme Travel",
          "slug" => "acme",
          "owner_email" => "o@acme.test",
          "plan_id" => plan.id
        })

      {:ok, _lv, html} = live(conn, ~p"/admin/plans/#{plan.id}")
      assert html =~ "Tenants on this plan"
      assert html =~ "Acme Travel"
    end

    test "detail page redirects for an unknown plan", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/plans"}}} =
               live(conn, ~p"/admin/plans/#{Ecto.UUID.generate()}")

      assert kind in [:redirect, :live_redirect]
    end
  end

  describe "permission gating" do
    @describetag admin_permissions: ["plan:list"]
    setup :register_and_log_in_normal_admin

    test "the create page is gated by plan:create", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin"}}} = live(conn, ~p"/admin/plans/new")
      assert kind in [:redirect, :live_redirect]
    end
  end
end
