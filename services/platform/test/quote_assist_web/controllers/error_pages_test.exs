defmodule QuoteAssistWeb.ErrorPagesTest do
  @moduledoc """
  End-to-end: any unmatched path renders the branded, themed 404 page (R6-errors) via
  the catch-all route — on the platform host and, crucially, on a known tenant host —
  instead of a plain, unstyled "Not Found" (or, in dev, the `debug_errors` page).
  """
  use QuoteAssistWeb.ConnCase, async: true

  import QuoteAssist.TenantsFixtures

  # The branded 404 template is a complete `<!DOCTYPE html>` document whose <head>
  # carries the pre-paint theme script. If it were wrapped in the app root layout the
  # head (and the theme with it) would be dropped, so a correct render has exactly one
  # <html> tag and keeps the theme hook.
  defp assert_branded_404(conn) do
    assert conn.status == 404
    body = html_response(conn, 404)
    assert body =~ "NOT_FOUND"
    assert body =~ "QuoteAssist"
    # Themed, standalone document — not double-wrapped in the root layout.
    assert body =~ "data-theme"
    assert occurrences(body, "<html") == 1
    body
  end

  defp occurrences(haystack, needle) do
    haystack |> String.split(needle) |> length() |> Kernel.-(1)
  end

  test "an unknown route on the platform host renders the branded 404 page", %{conn: conn} do
    body = conn |> get("/no-such-route") |> assert_branded_404()
    # Platform host: the workspace directory (/tenants) link is offered.
    assert body =~ "Browse workspaces"
    assert body =~ ~s(href="/tenants")
  end

  test "an unknown route on a known tenant host renders the branded 404 page", %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})

    body =
      conn
      |> put_tenant_host(tenant)
      |> get("/tenantskkk")
      |> assert_branded_404()

    # Tenant host: /tenants belongs to the platform host only, so it must not be linked.
    refute body =~ "Browse workspaces"
    refute body =~ ~s(href="/tenants")
  end

  test "a deep unknown path under a known tenant host still 404s", %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})

    conn
    |> put_tenant_host(tenant)
    |> get("/app/does/not/exist")
    |> assert_branded_404()
  end
end
