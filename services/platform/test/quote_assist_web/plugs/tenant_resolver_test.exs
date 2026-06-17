defmodule QuoteAssistWeb.Plugs.TenantResolverTest do
  use QuoteAssistWeb.ConnCase, async: true

  import QuoteAssist.TenantsFixtures

  alias QuoteAssistWeb.Plugs.TenantResolver
  alias QuoteAssistWeb.TenantNotFoundError

  defp resolve(host, session \\ %{}) do
    build_conn()
    |> Map.put(:host, host)
    |> Plug.Test.init_test_session(session)
    |> TenantResolver.call([])
  end

  describe "call/2" do
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

    test "unknown subdomain raises (→ 404)" do
      assert_raise TenantNotFoundError, fn -> resolve("nope.example.com") end
    end

    test "suspended tenant raises (→ 404)" do
      tenant_with_status_fixture(:suspended, %{slug: "susp"})
      assert_raise TenantNotFoundError, fn -> resolve("susp.example.com") end
    end

    test "unverified custom domain raises (→ 404)" do
      active_tenant_fixture(%{slug: "pend"})
      |> put_custom_domain!("pending.acme.test", :pending)

      assert_raise TenantNotFoundError, fn -> resolve("pending.acme.test") end
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

  describe "TenantNotFoundError" do
    test "is a 404 via the Plug.Exception protocol" do
      assert Plug.Exception.status(%TenantNotFoundError{}) == 404
      assert Plug.Exception.actions(%TenantNotFoundError{}) == []
    end

    test "end to end: an unknown tenant host returns 404" do
      assert_error_sent 404, fn ->
        build_conn() |> Map.put(:host, "ghost.example.com") |> get(~p"/")
      end
    end
  end
end
