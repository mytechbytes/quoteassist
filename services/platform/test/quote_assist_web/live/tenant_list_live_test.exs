defmodule QuoteAssistWeb.TenantListLiveTest do
  use QuoteAssistWeb.ConnCase

  import Phoenix.LiveViewTest

  alias QuoteAssistWeb.TenantListLive

  test "GET /tenants mounts and renders the empty state", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/tenants")

    assert html =~ "Tenants"
    assert html =~ "No tenants yet"

    # Public chrome is shared with the home page.
    assert html =~ "Admin login"
  end

  test "directory lists each tenant with a link to its subdomain login" do
    tenants = [%{name: "Acme Co", slug: "acme", status: :active}]

    html = rendered_to_string(TenantListLive.directory(%{tenants: tenants}))

    assert html =~ "Acme Co"
    assert html =~ "active"
    # Login link targets the tenant subdomain (prod scheme/host in the test env).
    assert html =~ ~s|href="https://acme.quoteassist.mytechbytes.in/login"|
    refute html =~ "No tenants yet"
  end
end
