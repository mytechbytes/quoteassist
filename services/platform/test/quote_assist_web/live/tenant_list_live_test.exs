defmodule QuoteAssistWeb.TenantListLiveTest do
  use QuoteAssistWeb.ConnCase

  import Phoenix.LiveViewTest
  import QuoteAssist.TenantsFixtures

  alias QuoteAssistWeb.TenantListLive

  test "GET /tenants mounts and renders the empty state", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/tenants")

    assert html =~ "Tenants"
    assert html =~ "No tenants yet"

    # Public chrome is shared with the home page.
    assert html =~ "Admin login"
  end

  test "lists live tenants from the database", %{conn: conn} do
    tenant_fixture(%{name: "Globex", slug: "globex"})

    {:ok, _live, html} = live(conn, ~p"/tenants")

    assert html =~ "Globex"
    refute html =~ "No tenants yet"
  end

  test "directory lists each tenant with a link to its subdomain login" do
    tenants = [%{name: "Acme Co", slug: "acme", status: :active}]

    html = rendered_to_string(TenantListLive.directory(%{tenants: tenants}))

    assert html =~ "Acme Co"
    assert html =~ "active"
    # Login link targets the tenant subdomain (test scheme/base from config/test.exs).
    assert html =~ ~s|href="http://acme.example.com/login"|
    refute html =~ "No tenants yet"
  end
end
