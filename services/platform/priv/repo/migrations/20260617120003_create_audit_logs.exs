defmodule QuoteAssist.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  # Append-only audit trail (RELEASE_PLAN.md). Records every privileged action and
  # status transition from R2 onward. No update/delete — `inserted_at` only, and the
  # context exposes no update/delete functions. actor_id/tenant_id are plain columns
  # (no FK): the actor is polymorphic (admin | user | system) and tenant_id is null
  # for platform-level actions. Never store full message bodies — references +
  # masked values only.
  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_type, :string, null: false
      add :actor_id, :binary_id
      add :tenant_id, :binary_id
      add :action, :string, null: false
      add :target_type, :string
      add :target_id, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_logs, [:tenant_id])
    create index(:audit_logs, [:actor_type, :actor_id])
    create index(:audit_logs, [:action])
  end
end
