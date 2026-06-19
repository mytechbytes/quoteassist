defmodule QuoteAssist.Authz.PolicyTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Authz.{Permissions, Policy}
  alias QuoteAssist.Tenants.{Membership, Role}

  describe "Permissions catalog" do
    test "keys are unique, complete, colon-style, and exclude the self:* baseline" do
      keys = Permissions.keys()
      assert length(keys) == 33
      assert keys == Enum.uniq(keys)
      assert "quote:list" in keys
      assert "billing:update" in keys
      assert "request:manage" in keys
      # self:* is a baseline, never role-composable, so never in the catalog keys.
      refute "self:read" in keys
    end

    test "valid?/1 covers catalog keys only (not the baseline)" do
      assert Permissions.valid?("role:create")
      refute Permissions.valid?("self:read")
      refute Permissions.valid?("nope:fake")
      refute Permissions.valid?(:not_a_string)
    end

    test "baseline?/1 covers the self:* keys" do
      assert Permissions.baseline?("self:read")
      assert Permissions.baseline?("self:sessions")
      refute Permissions.baseline?("quote:list")
      refute Permissions.baseline?(:not_a_string)
    end

    test "label/1 covers catalog + baseline and falls back to the key" do
      assert Permissions.label("quote:list") == "View quote list"
      assert Permissions.label("self:read") == "View own profile"
      assert Permissions.label("unknown:key") == "unknown:key"
    end

    test "catalog/0 groups cover exactly the flat key set" do
      grouped = for group <- Permissions.catalog(), perm <- group.permissions, do: perm.key
      assert Enum.sort(grouped) == Enum.sort(Permissions.keys())
    end
  end

  describe "can?/2 and can?/3 — member (role-driven)" do
    test "true when the role grants the permission" do
      scope = %Scope{
        membership: %Membership{type: :member},
        permissions: ["quote:list", "quote:create"]
      }

      assert Policy.can?(scope, "quote:list")
      assert Policy.can?(scope, "quote:create", :a_future_resource)
    end

    test "false when the role does not grant it" do
      scope = %Scope{membership: %Membership{type: :member}, permissions: ["quote:list"]}
      refute Policy.can?(scope, "quote:delete")
    end

    test "the self:* baseline is always granted, regardless of role" do
      scope = %Scope{membership: %Membership{type: :member}, permissions: []}
      assert Policy.can?(scope, "self:read")
      assert Policy.can?(scope, "self:password")
    end

    test "false with no usable scope" do
      refute Policy.can?(%Scope{}, "quote:list")
      refute Policy.can?(nil, "quote:list")
    end
  end

  describe "can?/3 — owner (protected type, computed all-access)" do
    setup do
      %{scope: %Scope{membership: %Membership{type: :owner}, permissions: []}}
    end

    test "holds every catalog permission with no enumerated keys", %{scope: scope} do
      assert Policy.can?(scope, "quote:delete")
      assert Policy.can?(scope, "billing:update")
      assert Policy.can?(scope, "self:read")
    end

    test "holds permissions that don't exist yet (computed, future-proof)", %{scope: scope} do
      assert Policy.can?(scope, "something:invented_later")
    end
  end

  describe "permissions_for_membership/1" do
    test "returns the role's permissions for a member" do
      membership = %Membership{type: :member, role: %Role{permissions: ["quote:list"]}}
      assert Policy.permissions_for_membership(membership) == ["quote:list"]
    end

    test "returns [] for an owner (all-access is computed, not enumerated)" do
      assert Policy.permissions_for_membership(%Membership{type: :owner}) == []
    end

    test "returns [] when there is no loaded role" do
      assert Policy.permissions_for_membership(%Membership{}) == []
      assert Policy.permissions_for_membership(nil) == []
    end
  end
end
