defmodule QuoteAssist.Authz.PolicyTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Authz.{Permissions, Policy}
  alias QuoteAssist.Tenants.{Membership, Role}

  describe "Permissions catalog" do
    test "keys are unique, non-empty, and complete" do
      keys = Permissions.keys()
      assert length(keys) == 16
      assert keys == Enum.uniq(keys)
      assert "quotes.view" in keys
      assert "settings.billing" in keys
    end

    test "valid?/1" do
      assert Permissions.valid?("team.roles")
      refute Permissions.valid?("nope.fake")
      refute Permissions.valid?(:not_a_string)
    end

    test "label/1 falls back to the key" do
      assert Permissions.label("quotes.view") == "View quotes"
      assert Permissions.label("unknown.key") == "unknown.key"
    end

    test "catalog/0 groups cover exactly the flat key set" do
      grouped = for group <- Permissions.catalog(), perm <- group.permissions, do: perm.key
      assert Enum.sort(grouped) == Enum.sort(Permissions.keys())
    end
  end

  describe "can?/2 and can?/3" do
    test "true when the permission is granted" do
      scope = %Scope{permissions: ["quotes.view", "quotes.create"]}
      assert Policy.can?(scope, "quotes.view")
      assert Policy.can?(scope, "quotes.create", :a_future_resource)
    end

    test "false when not granted or no scope" do
      refute Policy.can?(%Scope{permissions: ["quotes.view"]}, "quotes.delete")
      refute Policy.can?(%Scope{}, "quotes.view")
      refute Policy.can?(nil, "quotes.view")
    end
  end

  describe "permissions_for_membership/1" do
    test "returns the role's permissions" do
      membership = %Membership{role: %Role{permissions: ["quotes.view"]}}
      assert Policy.permissions_for_membership(membership) == ["quotes.view"]
    end

    test "returns [] when there is no loaded role" do
      assert Policy.permissions_for_membership(%Membership{}) == []
      assert Policy.permissions_for_membership(nil) == []
    end
  end
end
