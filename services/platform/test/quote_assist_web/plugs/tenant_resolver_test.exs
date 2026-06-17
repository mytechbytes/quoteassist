defmodule QuoteAssistWeb.Plugs.TenantResolverTest do
  use QuoteAssistWeb.ConnCase, async: true

  import QuoteAssist.TenantsFixtures

  alias QuoteAssistWeb.Plugs.TenantResolver

  # Direct plug call — used for the cases that only assign (no render).
  defp resolve(host, session \\ %{}) do
    build_conn()
    |> Map.put(:host, host)
    |> Plug.Test.init_test_session(session)
    |> TenantResolver.call([])
  end

  # End-to-end dispatch — used for the not-found cases, which render the branded page.
  defp get_on_host(host), do: build_conn() |> Map.put(:host, host) |> get(~p"/")

  describe "call/2 — assigns" do
    test "platform host: no tenant, and clears a stale session tenant id" do
      conn = resolve("www.example.com", %{tenant_id: "stale-id"})
      assert conn.assigns.current_tenant == nil
      assert get_session(conn, :tenant_id) == nil
    end

    test "subdomain: assigns the tenant and writes its id into the session" do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = resolve("acme.example.com")

      assert conn.assigns.current_tenant.id == tenant.id
      assert get_session(conn, :tenant_id) == tenant.id
    end

    test "verified custom domain: assigns the tenant" do
      tenant =
        active_tenant_fixture(%{slug: "cd"})
        |> put_custom_domain!("quotes.acme.test", :verified)

      assert resolve("quotes.acme.test").assigns.current_tenant.id == tenant.id
    end

    test "resolution is driven by host only — params cannot influence it" do
      tenant = active_tenant_fixture(%{slug: "acme"})

      conn =
        build_conn()
        |> Map.put(:host, "www.example.com")
        |> Map.put(:params, %{"tenant_id" => tenant.id, "slug" => "acme"})
        |> Plug.Test.init_test_session(%{})
        |> TenantResolver.call([])

      assert conn.assigns.current_tenant == nil
    end
  end

  describe "call/2 — unresolved hosts render the branded 404 page" do
    test "unknown subdomain" do
      conn = get_on_host("nope.example.com")

      assert conn.status == 404
      assert conn.halted
      assert conn.resp_body =~ "WORKSPACE"
      assert conn.resp_body =~ "nope.example.com"
    end

    test "suspended tenant" do
      tenant_with_status_fixture(:suspended, %{slug: "susp"})
      conn = get_on_host("susp.example.com")

      assert conn.status == 404
      assert conn.resp_body =~ "susp.example.com"
    end

    test "unverified (pending) custom domain" do
      active_tenant_fixture(%{slug: "pend"})
      |> put_custom_domain!("pending.acme.test", :pending)

      conn = get_on_host("pending.acme.test")

      assert conn.status == 404
      assert conn.resp_body =~ "pending.acme.test"
    end
  end
end
