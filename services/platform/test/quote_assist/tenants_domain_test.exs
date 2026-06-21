defmodule QuoteAssist.TenantsDomainTest do
  @moduledoc "Custom-domain context tests (R10-domain). DNS is the in-memory stub."
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Audit
  alias QuoteAssist.DnsStub
  alias QuoteAssist.Tenants

  setup do
    domain = "quotes#{System.unique_integer([:positive])}.acme.test"
    Map.put(owner_scope_fixture(), :domain, domain)
  end

  describe "set_custom_domain/3" do
    test "stores the domain as pending with a token", %{
      scope: scope,
      tenant: tenant,
      domain: domain
    } do
      assert {:ok, updated} =
               Tenants.set_custom_domain(scope, tenant, %{"custom_domain" => domain})

      assert updated.custom_domain == domain
      assert updated.custom_domain_status == :pending
      assert is_binary(updated.custom_domain_token)
      actions = "tenant" |> Audit.list_for_target(tenant.id) |> Enum.map(& &1.action)
      assert "domain.requested" in actions
    end

    test "rejects an invalid domain", %{scope: scope, tenant: tenant} do
      assert {:error, changeset} =
               Tenants.set_custom_domain(scope, tenant, %{"custom_domain" => "not a domain"})

      assert %{custom_domain: ["must be a valid domain"]} = errors_on(changeset)
    end

    test "rejects a host on the platform base domain", %{scope: scope, tenant: tenant} do
      assert {:error, changeset} =
               Tenants.set_custom_domain(scope, tenant, %{"custom_domain" => "evil.example.com"})

      assert %{custom_domain: ["can't be on example.com"]} = errors_on(changeset)
    end
  end

  describe "verify_custom_domain/2" do
    test "verifies when the TXT record is present", %{
      scope: scope,
      tenant: tenant,
      domain: domain
    } do
      {:ok, pending} = Tenants.set_custom_domain(scope, tenant, %{"custom_domain" => domain})
      DnsStub.put(domain, ["unrelated", Tenants.custom_domain_txt_value(pending)])

      assert {:ok, verified} = Tenants.verify_custom_domain(scope, pending)
      assert verified.custom_domain_status == :verified
      assert Tenants.verified_custom_domain?(domain)

      actions = "tenant" |> Audit.list_for_target(tenant.id) |> Enum.map(& &1.action)
      assert "domain.verified" in actions
    end

    test "stays pending when the TXT record is missing", %{
      scope: scope,
      tenant: tenant,
      domain: domain
    } do
      {:ok, pending} = Tenants.set_custom_domain(scope, tenant, %{"custom_domain" => domain})
      DnsStub.put(domain, ["some-other-value"])

      assert {:error, :not_found} = Tenants.verify_custom_domain(scope, pending)
      refute Tenants.verified_custom_domain?(domain)
    end

    test "errors when there is no domain to verify", %{scope: scope, tenant: tenant} do
      assert {:error, :no_domain} = Tenants.verify_custom_domain(scope, tenant)
    end
  end

  describe "clear_custom_domain/2" do
    test "resets the domain back to none", %{scope: scope, tenant: tenant, domain: domain} do
      {:ok, pending} = Tenants.set_custom_domain(scope, tenant, %{"custom_domain" => domain})

      assert {:ok, cleared} = Tenants.clear_custom_domain(scope, pending)
      assert cleared.custom_domain == nil
      assert cleared.custom_domain_status == :none
      refute Tenants.verified_custom_domain?(domain)
    end
  end

  describe "helpers" do
    test "cname target is the tenant subdomain", %{tenant: tenant} do
      assert Tenants.custom_domain_cname_target(tenant) == "#{tenant.slug}.example.com"
    end

    test "verified_custom_domain?/1 is false for unknown hosts" do
      refute Tenants.verified_custom_domain?("nobody.example.org")
      refute Tenants.verified_custom_domain?(nil)
    end
  end
end
