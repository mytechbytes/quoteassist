defmodule QuoteAssistWeb.App.SettingsLive.DomainTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.DnsStub
  alias QuoteAssist.Tenants

  defp domain, do: "quotes#{System.unique_integer([:positive])}.acme.test"

  describe "owner" do
    setup :register_and_log_in_member

    test "renders the subdomain and the add-domain form", %{conn: conn, tenant: tenant} do
      {:ok, _lv, html} = live(conn, ~p"/app/settings/domain")
      assert html =~ "Custom domain"
      assert html =~ "Platform subdomain"
      assert html =~ "#{tenant.slug}.example.com"
      assert html =~ "Add a custom domain"
    end

    test "adding a domain shows the DNS records to publish", %{conn: conn} do
      d = domain()
      {:ok, lv, _html} = live(conn, ~p"/app/settings/domain")

      html = lv |> form("#domain-form", domain: %{custom_domain: d}) |> render_submit()

      assert html =~ "Pending"
      assert html =~ d
      assert html =~ "CNAME"
      assert html =~ "TXT"
      assert html =~ "quoteassist-site-verification="
    end

    test "verifying succeeds when the TXT record is published", %{conn: conn, tenant: tenant} do
      d = domain()
      {:ok, lv, _html} = live(conn, ~p"/app/settings/domain")
      lv |> form("#domain-form", domain: %{custom_domain: d}) |> render_submit()

      # Publish the matching TXT record, then verify.
      pending = Tenants.get_tenant_by_slug(tenant.slug)
      DnsStub.put(d, [Tenants.custom_domain_txt_value(pending)])

      html = lv |> element("button", "Verify domain") |> render_click()
      assert html =~ "Verified"
      assert Tenants.verified_custom_domain?(d)
    end

    test "verifying without the TXT record reports it isn't found", %{conn: conn} do
      d = domain()
      {:ok, lv, _html} = live(conn, ~p"/app/settings/domain")
      lv |> form("#domain-form", domain: %{custom_domain: d}) |> render_submit()

      html = lv |> element("button", "Verify domain") |> render_click()
      assert html =~ "find the TXT record"
      assert html =~ "Pending"
    end

    test "removing clears the domain", %{conn: conn} do
      d = domain()
      {:ok, lv, _html} = live(conn, ~p"/app/settings/domain")
      lv |> form("#domain-form", domain: %{custom_domain: d}) |> render_submit()

      html = lv |> element("button", "Remove") |> render_click()
      assert html =~ "Add a custom domain"
      refute Tenants.verified_custom_domain?(d)
    end
  end

  describe "permissions" do
    test "a member without domain:read gets the branded 403", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      role = role_fixture(tenant, %{permissions: []})
      user = user_fixture()
      {:ok, _m} = Tenants.create_membership(tenant, user, role)
      conn = log_in_member(conn, user, tenant)

      assert_error_sent 403, fn -> get(conn, ~p"/app/settings/domain") end
    end
  end
end
