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

    test "cancelled tenant 404s" do
      tenant_with_status_fixture(:cancelled, %{slug: "gone"})
      conn = get_on_host("gone.example.com")

      assert conn.status == 404
      assert conn.resp_body =~ "gone.example.com"
    end

    test "unverified (pending) custom domain" do
      active_tenant_fixture(%{slug: "pend"})
      |> put_custom_domain!("pending.acme.test", :pending)

      conn = get_on_host("pending.acme.test")

      assert conn.status == 404
      assert conn.resp_body =~ "pending.acme.test"
    end
  end

  describe "call/2 — a suspended tenant renders the branded 403 page" do
    test "suspended subdomain returns 403 with the suspension notice" do
      tenant_with_status_fixture(:suspended, %{slug: "susp", name: "Suspended Co"})
      conn = get_on_host("susp.example.com")

      assert conn.status == 403
      assert conn.halted
      assert conn.resp_body =~ "SUSPENDED"
      assert conn.resp_body =~ "Suspended Co"
      assert conn.resp_body =~ "susp.example.com"
      # The suspended tenant id is not written to the session — the workspace
      # must not be entered.
      assert get_session(conn, :tenant_id) == nil
    end

    test "a suspended tenant's verified custom domain also returns 403" do
      tenant_with_status_fixture(:suspended, %{slug: "cdsusp", name: "CD Susp"})
      |> put_custom_domain!("quotes.cdsusp.test", :verified)

      conn = get_on_host("quotes.cdsusp.test")

      assert conn.status == 403
      assert conn.resp_body =~ "SUSPENDED"
    end
  end
end
