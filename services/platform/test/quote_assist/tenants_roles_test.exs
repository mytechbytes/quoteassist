defmodule QuoteAssist.TenantsRolesTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Audit
  alias QuoteAssist.Tenants

  defp audited?(tenant_id, action) do
    tenant_id |> Audit.list_for_tenant(100) |> Enum.any?(&(&1.action == action))
  end

  setup do
    owner_scope_fixture(%{slug: "acme"})
  end

  test "list_roles/1 returns the seeded built-ins, get_role/2 is id-safe", ctx do
    slugs = ctx.tenant |> Tenants.list_roles() |> Enum.map(& &1.slug)
    assert "manager" in slugs
    assert "agent" in slugs

    manager = Tenants.get_role_by_slug(ctx.tenant, "manager")
    assert Tenants.get_role(ctx.tenant, manager.id).id == manager.id
    assert Tenants.get_role(ctx.tenant, "not-a-uuid") == nil
    assert Tenants.get_role(ctx.tenant, Ecto.UUID.generate()) == nil
  end

  test "create / update / delete round-trip and audit", ctx do
    assert {:ok, role} =
             Tenants.create_role(ctx.scope, %{
               "name" => "Senior agent",
               "slug" => "senior-agent",
               "permissions" => ["quote:list", "quote:read"]
             })

    assert role.tenant_id == ctx.tenant.id
    assert role.permissions == ["quote:list", "quote:read"]
    assert audited?(ctx.tenant.id, "role.created")

    assert {:ok, updated} =
             Tenants.update_role(ctx.scope, role, %{"permissions" => ["quote:list"]})

    assert updated.permissions == ["quote:list"]
    assert audited?(ctx.tenant.id, "role.updated")

    assert {:ok, _} = Tenants.soft_delete_role(ctx.scope, updated)
    assert Tenants.get_role(ctx.tenant, role.id) == nil
    assert audited?(ctx.tenant.id, "role.deleted")
  end

  test "rejects unknown permission keys", ctx do
    assert {:error, changeset} =
             Tenants.create_role(ctx.scope, %{
               "name" => "Bad",
               "slug" => "bad",
               "permissions" => ["nope:fake"]
             })

    assert errors_on(changeset).permissions != []
  end

  test "soft delete refuses built-ins and roles still in use", ctx do
    builtin = Tenants.get_role_by_slug(ctx.tenant, "agent")
    assert {:error, :builtin} = Tenants.soft_delete_role(ctx.scope, builtin)

    {:ok, role} =
      Tenants.create_role(ctx.scope, %{"name" => "Temp", "slug" => "temp", "permissions" => []})

    {_user, _m} = member_fixture(ctx.tenant, "agent")
    # assign the new role to a member so it is "in use"
    member = member_fixture(ctx.tenant, "agent")
    {_u, m} = member
    {:ok, _} = Tenants.update_member_role(ctx.scope, m, %{"role_id" => role.id})

    assert {:error, :role_in_use} = Tenants.soft_delete_role(ctx.scope, role)
  end

  test "change_tenant_role/3 returns a tenant-seeded changeset", ctx do
    changeset = Tenants.change_tenant_role(ctx.tenant)
    assert Ecto.Changeset.get_field(changeset, :tenant_id) == ctx.tenant.id
  end
end
