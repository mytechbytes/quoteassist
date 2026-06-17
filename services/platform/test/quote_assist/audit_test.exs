defmodule QuoteAssist.AuditTest do
  use QuoteAssist.DataCase, async: true

  alias QuoteAssist.Audit
  alias QuoteAssist.Audit.Log

  test "log/1 inserts a row with the given fields" do
    target = Ecto.UUID.generate()

    assert {:ok, %Log{} = log} =
             Audit.log(%{
               actor_type: :system,
               action: "tenant.created",
               target_type: "tenant",
               target_id: target,
               metadata: %{"k" => "v"}
             })

    assert log.actor_type == :system
    assert log.action == "tenant.created"
    assert log.target_id == target
    assert log.inserted_at
    assert Repo.aggregate(Log, :count) == 1
  end

  test "log/1 requires actor_type and action" do
    assert {:error, changeset} = Audit.log(%{})
    assert %{actor_type: ["can't be blank"], action: ["can't be blank"]} = errors_on(changeset)
  end

  test "log!/1 returns the inserted row" do
    assert %Log{} =
             Audit.log!(%{
               actor_type: :user,
               actor_id: Ecto.UUID.generate(),
               action: "user.login"
             })
  end

  test "actor_types/0 lists the valid actor types" do
    assert Log.actor_types() == [:admin, :user, :system]
  end
end
