defmodule QuoteAssist.PolicyTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.Accounts.Membership
  alias QuoteAssist.Accounts.Role
  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Policy

  describe "catalog" do
    test "permissions_for/1 returns each persona's bundle" do
      assert "tenant:manage" in Policy.permissions_for(:site_admin)
      assert "user:manage" in Policy.permissions_for(:agency_admin)
      assert "discount:apply" in Policy.permissions_for(:salesperson)
    end

    test "all_permissions/0 is the union of the persona bundles" do
      all = Policy.all_permissions()

      for persona <- [:site_admin, :agency_admin, :salesperson],
          permission <- Policy.permissions_for(persona) do
        assert permission in all
      end
    end
  end

  describe "can?/3" do
    setup do
      scope = %Scope{
        membership: %Membership{role: %Role{permissions: ["tenant:manage", "vertical:manage"]}}
      }

      %{scope: scope}
    end

    test "true when the active role grants <resource>:<action>", %{scope: scope} do
      assert Policy.can?(scope, :manage, :tenant)
      assert Policy.can?(scope, :manage, :vertical)
    end

    test "false when the permission is not granted", %{scope: scope} do
      refute Policy.can?(scope, :manage, :plan)
    end

    test "false when there is no active membership/role" do
      refute Policy.can?(%Scope{}, :manage, :tenant)
      refute Policy.can?(%Scope{membership: %Membership{role: nil}}, :manage, :tenant)
    end
  end
end
