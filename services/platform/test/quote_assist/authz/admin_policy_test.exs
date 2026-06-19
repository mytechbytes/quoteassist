defmodule QuoteAssist.Authz.AdminPolicyTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.Accounts.{Admin, AdminRole}
  alias QuoteAssist.Authz.{AdminPermissions, AdminPolicy}

  describe "AdminPermissions catalog" do
    test "keys are unique, complete, colon-style, and exclude the self:* baseline" do
      keys = AdminPermissions.keys()
      assert length(keys) == 29
      assert keys == Enum.uniq(keys)
      assert "tenant:list" in keys
      assert "tenant:purge" in keys
      assert "admin:deactivate" in keys
      assert "admin_role:create" in keys
      assert "audit:read" in keys
      refute "self:read" in keys
    end

    test "valid?/1 covers catalog keys only (not the baseline)" do
      assert AdminPermissions.valid?("admin:create")
      refute AdminPermissions.valid?("self:read")
      refute AdminPermissions.valid?("nope:fake")
      refute AdminPermissions.valid?(:not_a_string)
    end

    test "baseline?/1 covers the self:* keys" do
      assert AdminPermissions.baseline?("self:read")
      assert AdminPermissions.baseline?("self:sessions")
      refute AdminPermissions.baseline?("tenant:list")
      refute AdminPermissions.baseline?(:not_a_string)
    end

    test "label/1 covers catalog + baseline and falls back to the key" do
      assert AdminPermissions.label("tenant:list") == "View agency list"
      assert AdminPermissions.label("self:read") == "View own profile"
      assert AdminPermissions.label("unknown:key") == "unknown:key"
    end

    test "catalog/0 groups cover exactly the flat key set" do
      grouped = for group <- AdminPermissions.catalog(), perm <- group.permissions, do: perm.key
      assert Enum.sort(grouped) == Enum.sort(AdminPermissions.keys())
    end
  end

  describe "can?/2 and can?/3 — normal admin (role-driven)" do
    test "true when the role grants the permission" do
      admin = %Admin{type: :admin, role: %AdminRole{permissions: ["tenant:list", "tenant:read"]}}
      assert AdminPolicy.can?(admin, "tenant:list")
      assert AdminPolicy.can?(admin, "tenant:read", :a_future_resource)
    end

    test "false when the role does not grant it" do
      admin = %Admin{type: :admin, role: %AdminRole{permissions: ["tenant:list"]}}
      refute AdminPolicy.can?(admin, "tenant:delete")
    end

    test "the self:* baseline is always granted, regardless of role" do
      admin = %Admin{type: :admin, role: %AdminRole{permissions: []}}
      assert AdminPolicy.can?(admin, "self:read")
      assert AdminPolicy.can?(admin, "self:password")
    end

    test "false when the role isn't loaded (only the baseline survives)" do
      admin = %Admin{type: :admin}
      refute AdminPolicy.can?(admin, "tenant:list")
      assert AdminPolicy.can?(admin, "self:read")
    end

    test "false with no usable actor" do
      refute AdminPolicy.can?(nil, "tenant:list")
      refute AdminPolicy.can?(%{}, "tenant:list")
    end
  end

  describe "can?/3 — super_admin (protected type, computed all-access)" do
    setup do
      %{admin: %Admin{type: :super_admin}}
    end

    test "holds every catalog permission with no role", %{admin: admin} do
      assert AdminPolicy.can?(admin, "tenant:purge")
      assert AdminPolicy.can?(admin, "admin:delete")
      assert AdminPolicy.can?(admin, "self:read")
    end

    test "holds permissions that don't exist yet (computed, future-proof)", %{admin: admin} do
      assert AdminPolicy.can?(admin, "something:invented_later")
    end
  end

  describe "permissions_for_admin/1" do
    test "returns the role's permissions for a normal admin" do
      admin = %Admin{type: :admin, role: %AdminRole{permissions: ["tenant:list"]}}
      assert AdminPolicy.permissions_for_admin(admin) == ["tenant:list"]
    end

    test "returns [] for a super_admin (all-access is computed, not enumerated)" do
      assert AdminPolicy.permissions_for_admin(%Admin{type: :super_admin}) == []
    end

    test "returns [] when there is no loaded role" do
      assert AdminPolicy.permissions_for_admin(%Admin{type: :admin}) == []
      assert AdminPolicy.permissions_for_admin(nil) == []
    end
  end
end
