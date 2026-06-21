defmodule QuoteAssistWeb.TlsControllerTest do
  use QuoteAssistWeb.ConnCase, async: true

  import QuoteAssist.TenantsFixtures

  test "200 for a verified custom domain", %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    put_custom_domain!(tenant, "quotes.acme.test", :verified)

    conn = get(conn, ~p"/tls/check", domain: "quotes.acme.test")
    assert conn.status == 200
  end

  test "403 for a pending (unverified) custom domain", %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    put_custom_domain!(tenant, "quotes.acme.test", :pending)

    conn = get(conn, ~p"/tls/check", domain: "quotes.acme.test")
    assert conn.status == 403
  end

  test "403 for an unknown host", %{conn: conn} do
    conn = get(conn, ~p"/tls/check", domain: "nobody.example.org")
    assert conn.status == 403
  end

  test "403 when no domain param is given", %{conn: conn} do
    conn = get(conn, ~p"/tls/check")
    assert conn.status == 403
  end
end
