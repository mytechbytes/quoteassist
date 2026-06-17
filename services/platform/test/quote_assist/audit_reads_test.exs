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
end
