defmodule QuoteAssist.AccountsAdminRbacTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.{Admin, AdminRole}
  alias QuoteAssist.Audit

  # Order-independent: audit rows share a second-precision `inserted_at` and a random
  # UUID tiebreak, so "the latest row" isn't deterministic within a test. Assert the
  # action was recorded with the super_admin subtype instead of relying on ordering.
  defp audited?(actor_id, action) do
    actor_id
    |> Audit.list_for_admin(50)
    |> Enum.any?(&(&1.action == action and &1.actor_subtype == :super_admin))
  end

  describe "register_admin/1 bootstraps a super_admin" do
    test "the bootstrap admin is the protected type with no role" do
      admin = admin_fixture()
      assert admin.type == :super_admin
      assert is_nil(admin.role_id)
      assert admin.active
    end
  end

  describe "admin roles" do
    setup do
      %{actor: admin_fixture()}
    end

    test "create/update/list/get round-trip and audit", %{actor: actor} do
      assert {:ok, role} =
               Accounts.create_admin_role(actor, %{
                 name: "Ops",
                 slug: "ops",
                 permissions: ["tenant:list", "tenant:read"]
               })

      assert audited?(actor.id, "admin_role.created")
      assert role.permissions == ["tenant:list", "tenant:read"]
      assert Enum.any?(Accounts.list_admin_roles(), &(&1.id == role.id))
      assert Accounts.get_admin_role(role.id).id == role.id
      assert Accounts.get_admin_role_by_slug("ops").id == role.id

      assert {:ok, updated} =
               Accounts.update_admin_role(actor, role, %{permissions: ["tenant:list"]})

      assert updated.permissions == ["tenant:list"]
      assert audited?(actor.id, "admin_role.updated")
    end

    test "rejects unknown permission keys", %{actor: actor} do
      assert {:error, changeset} =
               Accounts.create_admin_role(actor, %{
                 name: "X",
                 slug: "x",
                 permissions: ["nope:fake"]
               })

      assert errors_on(changeset).permissions != []
    end

    test "get_admin_role/1 returns nil for a malformed or unknown id" do
      assert Accounts.get_admin_role("not-a-uuid") == nil
      assert Accounts.get_admin_role(Ecto.UUID.generate()) == nil
    end

    test "soft delete refuses built-ins and roles in use, else removes", %{actor: actor} do
      [builtin | _] = Accounts.seed_default_admin_roles()
      assert {:error, :builtin} = Accounts.soft_delete_admin_role(actor, builtin)

      {:ok, role} =
        Accounts.create_admin_role(actor, %{name: "Temp", slug: "temp", permissions: []})

      _admin = normal_admin_fixture(role)
      assert {:error, :role_in_use} = Accounts.soft_delete_admin_role(actor, role)

      {:ok, free} =
        Accounts.create_admin_role(actor, %{name: "Free", slug: "free", permissions: []})

      assert {:ok, _deleted} = Accounts.soft_delete_admin_role(actor, free)
      assert Accounts.get_admin_role(free.id) == nil
    end

    test "seed_default_admin_roles/0 is idempotent" do
      first = Accounts.seed_default_admin_roles()
      second = Accounts.seed_default_admin_roles()
      assert length(first) == 2
      assert Enum.map(first, & &1.id) == Enum.map(second, & &1.id)
    end

    test "change_admin_role/2 returns a changeset" do
      assert %Ecto.Changeset{} = Accounts.change_admin_role()
    end
  end

  describe "create_admin/2" do
    setup do
      %{actor: admin_fixture(), role: admin_role_fixture(%{permissions: ["tenant:list"]})}
    end

    test "creates a normal admin with a role (audited)", %{actor: actor, role: role} do
      assert {:ok, admin} =
               Accounts.create_admin(actor, %{
                 email: unique_admin_email(),
                 password: valid_admin_password(),
                 role_id: role.id
               })

      assert admin.type == :admin
      assert admin.role_id == role.id
      assert audited?(actor.id, "admin.created")
    end

    test "requires a role", %{actor: actor} do
      assert {:error, changeset} =
               Accounts.create_admin(actor, %{
                 email: unique_admin_email(),
                 password: valid_admin_password()
               })

      assert "can't be blank" in errors_on(changeset).role_id
    end

    test "rejects a short password", %{actor: actor, role: role} do
      assert {:error, changeset} =
               Accounts.create_admin(actor, %{
                 email: unique_admin_email(),
                 password: "short",
                 role_id: role.id
               })

      assert errors_on(changeset).password != []
    end

    test "change_admin_creation/1 returns an unhashed changeset" do
      assert %Ecto.Changeset{} = Accounts.change_admin_creation()
    end
  end

  describe "update_admin_role_assignment/3" do
    setup do
      actor = admin_fixture()
      role = admin_role_fixture(%{permissions: ["tenant:list"]})
      %{actor: actor, role: role, target: normal_admin_fixture(role)}
    end

    test "reassigns a normal admin's role", %{actor: actor, target: target} do
      other = admin_role_fixture(%{permissions: ["plan:list"]})

      assert {:ok, updated} =
               Accounts.update_admin_role_assignment(actor, target, %{role_id: other.id})

      assert updated.role_id == other.id
      assert audited?(actor.id, "admin.role_changed")
    end

    test "refuses a super_admin target", %{actor: actor} do
      other_super = admin_fixture()

      assert {:error, :super_admin_has_no_role} =
               Accounts.update_admin_role_assignment(actor, other_super, %{role_id: nil})
    end
  end

  describe "activate / deactivate with the last-active-super_admin guard" do
    test "deactivating revokes sessions and is audited" do
      actor = admin_fixture()
      target = normal_admin_fixture(["tenant:list"])
      token = Accounts.generate_admin_session_token(target)

      assert {:ok, updated} = Accounts.deactivate_admin(actor, target)
      refute updated.active
      # Cross-cutting session revocation: the token no longer resolves.
      assert Accounts.get_admin_by_session_token(token) == nil
      assert audited?(actor.id, "admin.deactivated")

      assert {:ok, reactivated} = Accounts.activate_admin(actor, updated)
      assert reactivated.active
      assert audited?(actor.id, "admin.activated")
    end

    test "the last active super_admin cannot be deactivated or deleted" do
      solo = admin_fixture()
      assert Accounts.active_super_admin_count() == 1
      assert {:error, :last_super_admin} = Accounts.deactivate_admin(solo, solo)
      assert {:error, :last_super_admin} = Accounts.soft_delete_admin(solo, solo)
    end

    test "with two super_admins, one can be deactivated, then the survivor is protected" do
      a = admin_fixture()
      b = admin_fixture()
      assert Accounts.active_super_admin_count() == 2

      assert {:ok, _} = Accounts.deactivate_admin(a, b)
      assert Accounts.active_super_admin_count() == 1
      assert {:error, :last_super_admin} = Accounts.deactivate_admin(a, a)
    end

    test "soft_delete removes the admin, revokes sessions, and is audited" do
      actor = admin_fixture()
      target = normal_admin_fixture(["tenant:list"])
      token = Accounts.generate_admin_session_token(target)

      assert {:ok, deleted} = Accounts.soft_delete_admin(actor, target)
      assert deleted.deleted_at
      assert Accounts.get_admin_by_session_token(token) == nil
      assert Accounts.get_admin(target.id) == nil
      assert audited?(actor.id, "admin.deleted")
    end
  end

  describe "super_admin visibility is enforced at the query layer" do
    setup do
      super_admin = admin_fixture()
      normal = normal_admin_fixture(["admin:list"])
      %{super_admin: super_admin, normal: normal}
    end

    test "a super_admin sees every admin", %{super_admin: super_admin, normal: normal} do
      ids = super_admin |> Accounts.list_admins_visible_to() |> Enum.map(& &1.id)
      assert super_admin.id in ids
      assert normal.id in ids
    end

    test "a normal admin sees only normal admins", %{super_admin: super_admin, normal: normal} do
      visible = Accounts.list_admins_visible_to(normal)
      ids = Enum.map(visible, & &1.id)
      assert normal.id in ids
      refute super_admin.id in ids
      assert Enum.all?(visible, &(&1.type == :admin))
    end

    test "get_admin_visible_to/2 hides super_admins from a normal admin",
         %{super_admin: super_admin, normal: normal} do
      assert Accounts.get_admin_visible_to(super_admin, super_admin.id).id == super_admin.id
      assert Accounts.get_admin_visible_to(super_admin, normal.id).id == normal.id
      assert Accounts.get_admin_visible_to(normal, normal.id).id == normal.id
      assert Accounts.get_admin_visible_to(normal, super_admin.id) == nil
      assert Accounts.get_admin_visible_to(normal, "not-a-uuid") == nil
    end
  end

  describe "list_admins_for_role/1" do
    test "lists live admins assigned to the role" do
      role = admin_role_fixture(%{permissions: ["tenant:list"]})
      a = normal_admin_fixture(role)
      assert role |> Accounts.list_admins_for_role() |> Enum.map(& &1.id) == [a.id]
    end
  end

  describe "Admin.create_changeset/3 forces the normal type" do
    test "type is :admin even if a super_admin type is supplied" do
      role = admin_role_fixture()

      changeset =
        Admin.create_changeset(%Admin{}, %{
          email: unique_admin_email(),
          password: valid_admin_password(),
          role_id: role.id,
          type: :super_admin
        })

      assert Ecto.Changeset.get_field(changeset, :type) == :admin
    end

    test "AdminRole.changeset validates the slug format" do
      changeset = AdminRole.changeset(%AdminRole{}, %{name: "Bad", slug: "Bad Slug"})
      assert errors_on(changeset).slug != []
    end
  end
end
