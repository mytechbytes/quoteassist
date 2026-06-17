defmodule QuoteAssistWeb.Plugs.RequirePlatformTest do
  use QuoteAssistWeb.ConnCase, async: true

  import QuoteAssist.TenantsFixtures

  alias QuoteAssistWeb.Plugs.RequirePlatform

  describe "call/2 (direct)" do
    test "passes through on the platform host (current_tenant nil)", %{conn: conn} do
      conn = conn |> assign(:current_tenant, nil) |> RequirePlatform.call([])
      refute conn.halted
    end

    test "passes through when current_tenant is absent", %{conn: conn} do
      refute RequirePlatform.call(conn, []).halted
    end
  end

  describe "end-to-end — /admin is invisible on a tenant host" do
    setup do
      %{tenant: active_tenant_fixture(%{slug: "acme"})}
    end

    test "GET /admin/login 404s on a tenant host", %{conn: conn} do
      conn = %{conn | host: "acme.example.com"} |> get(~p"/admin/login")
      assert conn.status == 404
    end

    test "GET /admin/tenants 404s on a tenant host", %{conn: conn} do
      conn = %{conn | host: "acme.example.com"} |> get(~p"/admin/tenants")
      assert conn.status == 404
    end
  end
end
