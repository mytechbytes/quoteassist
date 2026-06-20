defmodule QuoteAssist.AuditReadsTest do
  use QuoteAssist.DataCase, async: true

  alias QuoteAssist.Audit

  test "list_for_tenant/2 returns only that tenant's rows" do
    t1 = Ecto.UUID.generate()
    t2 = Ecto.UUID.generate()
    {:ok, _} = Audit.log(%{actor_type: :system, action: "a.one", tenant_id: t1})
    {:ok, _} = Audit.log(%{actor_type: :system, action: "a.two", tenant_id: t1})
    {:ok, _} = Audit.log(%{actor_type: :system, action: "b.one", tenant_id: t2})

    actions = t1 |> Audit.list_for_tenant() |> Enum.map(& &1.action)
    assert "a.one" in actions
    assert "a.two" in actions
    refute "b.one" in actions
  end

  test "list_recent/1 respects the limit" do
    for i <- 1..3, do: Audit.log(%{actor_type: :system, action: "act.#{i}"})
    assert length(Audit.list_recent(2)) == 2
  end

  test "list_for_admin/2 filters to a single admin actor" do
    admin_id = Ecto.UUID.generate()
    {:ok, _} = Audit.log(%{actor_type: :admin, actor_id: admin_id, action: "admin.did"})
    {:ok, _} = Audit.log(%{actor_type: :user, actor_id: Ecto.UUID.generate(), action: "user.did"})

    assert [%{action: "admin.did"}] = Audit.list_for_admin(admin_id)
  end

  test "list_for_target/3 filters to a single resource by type + id" do
    role_id = Ecto.UUID.generate()

    {:ok, _} =
      Audit.log(%{
        actor_type: :user,
        action: "role.created",
        target_type: "role",
        target_id: role_id
      })

    {:ok, _} =
      Audit.log(%{
        actor_type: :user,
        action: "role.updated",
        target_type: "role",
        target_id: role_id
      })

    {:ok, _} =
      Audit.log(%{
        actor_type: :user,
        action: "role.created",
        target_type: "role",
        target_id: Ecto.UUID.generate()
      })

    {:ok, _} =
      Audit.log(%{
        actor_type: :user,
        action: "user.removed",
        target_type: "user",
        target_id: role_id
      })

    actions = "role" |> Audit.list_for_target(role_id) |> Enum.map(& &1.action)
    assert "role.created" in actions
    assert "role.updated" in actions
    # different target_id and different target_type are both excluded
    assert length(actions) == 2
  end
end
