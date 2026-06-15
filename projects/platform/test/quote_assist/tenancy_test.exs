defmodule QuoteAssist.TenancyTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts.Membership
  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Tenancy
  alias QuoteAssist.Tenancy.Tenant

  describe "create_tenant/1" do
    test "creates a tenant and downcases the slug" do
      assert {:ok, %Tenant{} = tenant} =
               Tenancy.create_tenant(%{name: "Globex", slug: "Globex-Corp"})

      assert tenant.slug == "globex-corp"
      assert tenant.status == :active
    end

    test "requires name and slug" do
      assert {:error, changeset} = Tenancy.create_tenant(%{})
      assert %{name: ["can't be blank"], slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an invalid slug format" do
      assert {:error, changeset} = Tenancy.create_tenant(%{name: "X", slug: "no spaces"})
      assert errors_on(changeset).slug != []
    end

    test "enforces slug uniqueness" do
      _ = tenant_fixture(slug: "dup-slug")
      assert {:error, changeset} = Tenancy.create_tenant(%{name: "Other", slug: "dup-slug"})
      assert "has already been taken" in errors_on(changeset).slug
    end
  end

  describe "scope/2" do
    test "limits a query to the scope's active tenant" do
      tenant_a = tenant_fixture()
      tenant_b = tenant_fixture()

      membership_fixture(user_fixture(), :salesperson, %{tenant_id: tenant_a.id})
      membership_fixture(user_fixture(), :salesperson, %{tenant_id: tenant_a.id})
      membership_fixture(user_fixture(), :salesperson, %{tenant_id: tenant_b.id})

      scope = %Scope{tenant: tenant_a}
      rows = Membership |> Tenancy.scope(scope) |> Repo.all()

      assert length(rows) == 2
      assert Enum.all?(rows, &(&1.tenant_id == tenant_a.id))
    end

    test "raises when the scope has no active tenant" do
      assert_raise ArgumentError, ~r/requires a scope with an active tenant/, fn ->
        Tenancy.scope(Membership, %Scope{tenant: nil})
      end
    end
  end
end
