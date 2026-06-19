defmodule QuoteAssist.TenancyTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Tenancy
  alias QuoteAssist.Tenancy.NoTenantError
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Role

  describe "scope/2" do
    test "constrains a query to the scope's tenant" do
      tenant_a = tenant_fixture(%{slug: "scopea"})
      _tenant_b = tenant_fixture(%{slug: "scopeb"})

      tenant_ids =
        Role
        |> Tenancy.scope(%Scope{tenant: tenant_a})
        |> Repo.all()
        |> Enum.map(& &1.tenant_id)
        |> Enum.uniq()

      assert tenant_ids == [tenant_a.id]
    end

    test "filters soft-deleted rows" do
      tenant = tenant_fixture(%{slug: "scopedel"})
      scope = %Scope{tenant: tenant}
      [role | _] = Role |> Tenancy.scope(scope) |> Repo.all()

      role
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.update!()

      remaining_ids = Role |> Tenancy.scope(scope) |> Repo.all() |> Enum.map(& &1.id)
      refute role.id in remaining_ids
    end

    test "raises when no tenant is in scope" do
      # scope/2 raises before any query is built, so it never reaches Repo.all —
      # asserting on scope/2 alone both proves the raise and avoids a type-checker
      # "none()" warning from piping a guaranteed-raise into Repo.all.
      assert_raise NoTenantError, fn -> Tenancy.scope(Role, %Scope{}) end
      assert_raise NoTenantError, fn -> Tenancy.scope(Role, %Scope{user: nil, tenant: nil}) end
      assert_raise NoTenantError, fn -> Tenancy.scope(Role, nil) end
    end

    test "cross-tenant isolation: tenant A's scope cannot see tenant B's rows" do
      tenant_a = tenant_fixture(%{slug: "isoa"})
      tenant_b = tenant_fixture(%{slug: "isob"})
      b_role = Tenants.get_role_by_slug(tenant_b, "agent")

      ids_visible_to_a =
        Role |> Tenancy.scope(%Scope{tenant: tenant_a}) |> Repo.all() |> Enum.map(& &1.id)

      refute b_role.id in ids_visible_to_a
    end
  end

  describe "owner protection (query layer)" do
    setup do
      tenant = tenant_fixture(%{slug: "ownerprot"})
      {_u1, owner} = member_fixture(tenant, "owner")
      {_u2, member} = member_fixture(tenant, "agent")
      %{tenant: tenant, owner: owner, member: member}
    end

    test "members_visible_to/1 excludes owners for a non-owner actor", ctx do
      scope = %Scope{tenant: ctx.tenant, membership: ctx.member}
      visible = Tenancy.members_visible_to(scope) |> Repo.all()

      refute :owner in Enum.map(visible, & &1.type)
      assert ctx.member.id in Enum.map(visible, & &1.id)
      refute ctx.owner.id in Enum.map(visible, & &1.id)
    end

    test "members_visible_to/1 shows everyone to an owner actor", ctx do
      scope = %Scope{tenant: ctx.tenant, membership: ctx.owner}
      ids = Tenancy.members_visible_to(scope) |> Repo.all() |> Enum.map(& &1.id)

      assert ctx.owner.id in ids
      assert ctx.member.id in ids
    end

    test "assignable_types_for/1 gates the protected type to owners", ctx do
      assert Tenancy.assignable_types_for(%Scope{tenant: ctx.tenant, membership: ctx.owner}) ==
               [:owner, :member]

      assert Tenancy.assignable_types_for(%Scope{tenant: ctx.tenant, membership: ctx.member}) ==
               [:member]
    end
  end
end
