defmodule QuoteAssist.TenantsMemberRbacTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Audit
  alias QuoteAssist.Tenants

  defp audited?(tenant_id, action) do
    tenant_id |> Audit.list_for_tenant(100) |> Enum.any?(&(&1.action == action))
  end

  describe "member visibility is enforced at the query layer" do
    setup do
      tenant = active_tenant_fixture(%{slug: "acme"})
      {owner_user, owner} = member_fixture(tenant, "owner")
      {agent_user, agent} = member_fixture(tenant, "agent")

      %{
        tenant: tenant,
        owner: owner,
        owner_scope: scope_fixture(tenant, owner_user, owner),
        agent: agent,
        agent_scope: scope_fixture(tenant, agent_user, agent)
      }
    end

    test "an owner sees every member; a member never sees an owner", ctx do
      owner_ids = ctx.owner_scope |> Tenants.list_members_visible_to() |> Enum.map(& &1.id)
      assert ctx.owner.id in owner_ids
      assert ctx.agent.id in owner_ids

      member_view = Tenants.list_members_visible_to(ctx.agent_scope)
      member_ids = Enum.map(member_view, & &1.id)
      assert ctx.agent.id in member_ids
      refute ctx.owner.id in member_ids
      assert Enum.all?(member_view, &(&1.type == :member))
    end

    test "get_member_visible_to hides owners from a member", ctx do
      assert Tenants.get_member_visible_to(ctx.owner_scope, ctx.owner.id).id == ctx.owner.id
      assert Tenants.get_member_visible_to(ctx.agent_scope, ctx.agent.id).id == ctx.agent.id
      assert Tenants.get_member_visible_to(ctx.agent_scope, ctx.owner.id) == nil
      assert Tenants.get_member_visible_to(ctx.agent_scope, "not-a-uuid") == nil
    end
  end

  describe "invite_member/2" do
    setup do
      ctx = owner_scope_fixture(%{slug: "acme"})
      Map.put(ctx, :role, Tenants.get_role_by_slug(ctx.tenant, "agent"))
    end

    test "invites a brand-new user as a member with the chosen role", ctx do
      email = "newbie@example.com"

      assert {:ok, membership} =
               Tenants.invite_member(ctx.scope, %{"email" => email, "role_id" => ctx.role.id})

      assert membership.type == :member
      assert membership.role_id == ctx.role.id
      assert Accounts.get_user_by_email(email)
      assert audited?(ctx.tenant.id, "user.invited")
    end

    test "reuses an already-set-up user (magic-link branch)", ctx do
      existing = set_password(user_fixture(%{email: "known@example.com"}))

      assert {:ok, membership} =
               Tenants.invite_member(ctx.scope, %{
                 "email" => existing.email,
                 "role_id" => ctx.role.id
               })

      assert membership.user_id == existing.id
    end

    test "rejects an email that is already a member", ctx do
      {user, _} = member_fixture(ctx.tenant, "agent")

      assert {:error, :already_member} =
               Tenants.invite_member(ctx.scope, %{"email" => user.email, "role_id" => ctx.role.id})
    end

    test "requires a real tenant role", ctx do
      assert {:error, :role_not_found} =
               Tenants.invite_member(ctx.scope, %{
                 "email" => "x@example.com",
                 "role_id" => Ecto.UUID.generate()
               })
    end

    test "validates the email", ctx do
      assert {:error, changeset} =
               Tenants.invite_member(ctx.scope, %{"email" => "nope", "role_id" => ctx.role.id})

      assert errors_on(changeset).email != []
    end
  end

  describe "role reassignment" do
    setup do
      ctx = owner_scope_fixture(%{slug: "acme"})
      {member_user, member} = member_fixture(ctx.tenant, "agent")
      Map.merge(ctx, %{member: member, member_user: member_user})
    end

    test "reassigns a member's role (audited)", ctx do
      manager = Tenants.get_role_by_slug(ctx.tenant, "manager")

      assert {:ok, updated} =
               Tenants.update_member_role(ctx.scope, ctx.member, %{"role_id" => manager.id})

      assert updated.role_id == manager.id
      assert audited?(ctx.tenant.id, "user.role_changed")
    end

    test "refuses an owner target", ctx do
      assert {:error, :owner_has_no_role} =
               Tenants.update_member_role(ctx.scope, ctx.membership, %{
                 "role_id" => ctx.member.role_id
               })
    end
  end

  describe "activate / deactivate / remove with session revocation" do
    setup do
      ctx = owner_scope_fixture(%{slug: "acme"})
      {member_user, member} = member_fixture(ctx.tenant, "agent")
      Map.merge(ctx, %{member: member, member_user: member_user})
    end

    test "deactivating revokes sessions and blocks access (audited)", ctx do
      token = Accounts.generate_user_session_token(ctx.member_user)

      assert {:ok, updated} = Tenants.deactivate_member(ctx.scope, ctx.member)
      refute updated.active
      assert Accounts.get_user_by_session_token(token) == nil
      refute Tenants.member?(ctx.tenant, ctx.member_user)
      assert Tenants.get_active_membership(ctx.tenant, ctx.member_user) == nil
      assert audited?(ctx.tenant.id, "user.deactivated")

      assert {:ok, reactivated} = Tenants.activate_member(ctx.scope, updated)
      assert reactivated.active
      assert Tenants.member?(ctx.tenant, ctx.member_user)
      assert audited?(ctx.tenant.id, "user.activated")
    end

    test "removing soft-deletes, revokes sessions, and is audited", ctx do
      token = Accounts.generate_user_session_token(ctx.member_user)

      assert {:ok, removed} = Tenants.remove_member(ctx.scope, ctx.member)
      assert removed.deleted_at
      assert Accounts.get_user_by_session_token(token) == nil
      refute Tenants.member?(ctx.tenant, ctx.member_user)
      assert audited?(ctx.tenant.id, "user.removed")
    end
  end

  describe "the last-active-owner guard" do
    setup do
      owner_scope_fixture(%{slug: "acme"})
    end

    test "the only owner cannot be deactivated or removed", ctx do
      assert Tenants.active_owner_count(ctx.tenant) == 1
      assert {:error, :last_owner} = Tenants.deactivate_member(ctx.scope, ctx.membership)
      assert {:error, :last_owner} = Tenants.remove_member(ctx.scope, ctx.membership)

      assert {:error, :last_owner} =
               Tenants.demote_owner(ctx.scope, ctx.membership, %{
                 "role_id" => Tenants.get_role_by_slug(ctx.tenant, "agent").id
               })
    end

    test "with two owners, one can be removed, then the survivor is protected", ctx do
      {second_user, second} = member_fixture(ctx.tenant, "owner")
      assert Tenants.active_owner_count(ctx.tenant) == 2

      assert {:ok, _} = Tenants.deactivate_member(ctx.scope, second)
      assert Tenants.active_owner_count(ctx.tenant) == 1
      assert {:error, :last_owner} = Tenants.remove_member(ctx.scope, ctx.membership)

      # the survivor is still the original owner
      assert Tenants.member?(ctx.tenant, ctx.user)
      refute Tenants.member?(ctx.tenant, second_user)
    end
  end

  describe "promote / demote" do
    setup do
      ctx = owner_scope_fixture(%{slug: "acme"})
      {member_user, member} = member_fixture(ctx.tenant, "agent")
      Map.merge(ctx, %{member: member, member_user: member_user})
    end

    test "promotes a member to owner (clears the role, audited)", ctx do
      assert {:ok, owner} = Tenants.promote_member(ctx.scope, ctx.member)
      assert owner.type == :owner
      assert is_nil(owner.role_id)
      assert Tenants.active_owner_count(ctx.tenant) == 2
      assert audited?(ctx.tenant.id, "user.promoted")
    end

    test "demotes an owner back to a member with a role (audited)", ctx do
      {_u, second_owner} = member_fixture(ctx.tenant, "owner")
      agent = Tenants.get_role_by_slug(ctx.tenant, "agent")

      assert {:ok, demoted} =
               Tenants.demote_owner(ctx.scope, second_owner, %{"role_id" => agent.id})

      assert demoted.type == :member
      assert demoted.role_id == agent.id
      assert audited?(ctx.tenant.id, "user.demoted")
    end
  end
end
