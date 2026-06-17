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

    test "creates a plan via the modal", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/plans")
      lv |> element("#new-plan") |> render_click()

      html =
        lv
        |> form("#plan-form",
          plan: %{name: "Enterprise", slug: "enterprise", monthly_price: 499, seat_limit: 100}
        )
        |> render_submit()

      assert html =~ "Enterprise"
      assert Plans.get_plan_by_slug("enterprise")
    end

    test "edits a plan via the modal", %{conn: conn} do
      plan = plan_fixture(%{name: "Growth", slug: "growth"})
      {:ok, lv, _html} = live(conn, ~p"/admin/plans")

      lv |> element("#plan-#{plan.id} button", "Edit") |> render_click()

      html =
        lv
        |> form("#plan-form", plan: %{name: "Growth Plus", monthly_price: 199, seat_limit: 30})
        |> render_submit()

      assert html =~ "Growth Plus"
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
end
