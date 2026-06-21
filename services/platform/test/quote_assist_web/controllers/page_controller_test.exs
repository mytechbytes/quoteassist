defmodule QuoteAssistWeb.PageControllerTest do
  use QuoteAssistWeb.ConnCase

  import QuoteAssist.TenantsFixtures

  test "GET / renders the platform build-status table", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)

    assert body =~ "QuoteAssist"
    assert body =~ "Build status"

    # Release train rows (hard-coded in PageHTML.release_tracks/0).
    assert body =~ "R0a"
    assert body =~ "R10-domain"
    assert body =~ "R12-quote-reply"

    # Status labels — all of R0–R12 have now shipped.
    assert body =~ "Done"

    # Public chrome: Admin login points at the (R3) admin route.
    assert body =~ "Admin login"
    assert body =~ ~s|href="/admin/login"|
  end

  test "GET / on a tenant host renders that tenant's branded landing (not the platform home)",
       %{conn: conn} do
    active_tenant_fixture(%{slug: "acme", name: "Acme Travel"})
    conn = %{conn | host: "acme.example.com"} |> get(~p"/")
    body = html_response(conn, 200)

    # The tenant's own landing — its name, never the platform build-status table.
    assert body =~ "Acme Travel"
    refute body =~ "Build status"

    # A guest is offered sign-in; no platform-only chrome (Admin login / /tenants).
    assert body =~ "Sign in"
    refute body =~ "Admin login"
    refute body =~ ~s|href="/tenants"|
  end

  test "GET / on a tenant host shows a signed-in member the workspace CTA (no redirect)",
       %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme", name: "Acme Travel"})
    {user, _membership} = member_fixture(tenant, "owner")

    conn = conn |> log_in_member(user, tenant) |> get(~p"/")
    body = html_response(conn, 200)

    assert body =~ "Go to workspace"
    assert body =~ ~s|href="/app"|
    refute body =~ "Build status"
  end
end
