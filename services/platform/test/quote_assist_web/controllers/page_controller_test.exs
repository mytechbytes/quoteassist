defmodule QuoteAssistWeb.PageControllerTest do
  use QuoteAssistWeb.ConnCase

  import QuoteAssist.PlansFixtures
  import QuoteAssist.TenantsFixtures

  describe "platform host /" do
    test "GET / renders the marketing landing", %{conn: conn} do
      conn = get(conn, ~p"/")
      body = html_response(conn, 200)

      assert body =~ "QuoteAssist"
      # Hero + landing sections (ported from designs/index.html).
      assert body =~ "Turn a customer email"
      assert body =~ "Get started"
      assert body =~ "How it works" || body =~ "Six steps"
      assert body =~ "Pricing"

      # The release table itself moved to /release-build-status (the footer still links to it).
      refute body =~ "independently deployable"

      # Admin login moved into the footer; the directory + register are linked.
      assert body =~ ~s|href="/admin/login"|
      assert body =~ ~s|href="/register"|
      assert body =~ ~s|href="/tenants"|
    end

    test "the pricing section renders the live, active plans from the DB", %{conn: conn} do
      plan_fixture(%{
        name: "Starter",
        slug: "starter",
        price: 0,
        limits: %{"quotes_per_month" => 50, "seats" => 3}
      })

      plan_fixture(%{name: "Growth", slug: "growth", price: 149_900, active: true})
      plan_fixture(%{name: "Scale", slug: "scale", price: 499_900, active: true})
      # An inactive plan must not appear in the public pricing.
      plan_fixture(%{name: "Hidden Plan", slug: "hidden", price: 9900, active: false})

      body = conn |> get(~p"/") |> html_response(200)

      assert body =~ "Starter"
      assert body =~ "Growth"
      assert body =~ "Scale"
      assert body =~ "Free"
      assert body =~ "₹1,499"
      assert body =~ "quotes / month"
      # Middle of three is the highlighted plan; inactive plans are excluded.
      assert body =~ "Most popular"
      refute body =~ "Hidden Plan"
    end

    test "the pricing section shows a fallback when no plans are set up", %{conn: conn} do
      body = conn |> get(~p"/") |> html_response(200)
      assert body =~ "Plans are being set up"
    end
  end

  describe "release build status" do
    test "GET /release-build-status renders the release table", %{conn: conn} do
      conn = get(conn, ~p"/release-build-status")
      body = html_response(conn, 200)

      assert body =~ "Build status"
      assert body =~ "R0a"
      assert body =~ "R12-quote-reply"
      # All of R0–R12 have shipped.
      assert body =~ "Done"
    end

    test "404s on a tenant host (platform-only content)", %{conn: conn} do
      active_tenant_fixture(%{slug: "acme"})
      conn = %{conn | host: "acme.example.com"} |> get(~p"/release-build-status")
      assert conn.status == 404
    end
  end

  describe "tenant host /" do
    test "renders the tenant's login-hero landing (not the platform home)", %{conn: conn} do
      active_tenant_fixture(%{slug: "acme", name: "Acme Travel"})
      conn = %{conn | host: "acme.example.com"} |> get(~p"/")
      body = html_response(conn, 200)

      # The tenant's own branding + a login CTA; never the platform build-status table.
      assert body =~ "Acme Travel"
      assert body =~ "Log in"
      assert body =~ ~s|href="/login"|
      refute body =~ "Build status"

      # No platform-only chrome (admin login / directory).
      refute body =~ ~s|href="/admin/login"|
      refute body =~ ~s|href="/tenants"|
    end

    test "shows a signed-in member the workspace CTA (no redirect)", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme", name: "Acme Travel"})
      {user, _membership} = member_fixture(tenant, "owner")

      conn = conn |> log_in_member(user, tenant) |> get(~p"/")
      body = html_response(conn, 200)

      assert body =~ "Go to workspace"
      assert body =~ ~s|href="/app"|
      refute body =~ "Build status"
    end
  end
end
