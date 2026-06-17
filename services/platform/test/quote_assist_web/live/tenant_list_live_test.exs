defmodule QuoteAssistWeb.TenantListLiveTest do
  use QuoteAssistWeb.ConnCase

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Tenants
  alias QuoteAssistWeb.TenantListLive

  defp dev_password, do: System.get_env("DEV_USER_PASSWORD", "panther@2010")

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

  describe "dev credentials panel (dev: true)" do
    test "shows each member with role and password" do
      tenant = active_tenant_fixture(%{slug: "acme", name: "Acme Travel"})
      {owner, _} = member_fixture(tenant, "owner")
      set_password(owner)
      magic_only = unconfirmed_user_fixture()
      membership_fixture(tenant, magic_only, "viewer")

      [t] = Tenants.list_live_tenants_with_members()
      html = rendered_to_string(TenantListLive.directory(%{tenants: [t], dev: true}))

      assert html =~ "Development only"
      assert html =~ owner.email
      assert html =~ "Owner"
      assert html =~ dev_password()

      # Members without a password show the magic-link note instead.
      assert html =~ magic_only.email
      assert html =~ "Viewer"
      assert html =~ "magic link only"
    end

    test "the public (non-dev) directory never shows passwords" do
      tenant = active_tenant_fixture(%{slug: "acme", name: "Acme Travel"})
      {owner, _} = member_fixture(tenant, "owner")
      set_password(owner)

      [t] = Tenants.list_live_tenants_with_members()
      # dev defaults to false.
      html = rendered_to_string(TenantListLive.directory(%{tenants: [t]}))

      assert html =~ "Acme Travel"
      refute html =~ dev_password()
      refute html =~ "magic link only"
      refute html =~ "Development only"
    end
  end
end
