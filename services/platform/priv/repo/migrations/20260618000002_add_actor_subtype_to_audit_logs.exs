defmodule QuoteAssist.Repo.Migrations.AddActorSubtypeToAuditLogs do
  use Ecto.Migration

  # RELEASE_PLAN.md cross-cutting ("Audit log — immutable, from R2"): each row records
  # an `actor_subtype` (super_admin | admin | owner | member | null) alongside
  # `actor_type`, so "which admin/owner tier did this" is answerable. Nullable —
  # platform/system actions and as-yet-untiered actors leave it blank.
  #
  # Additive migration — R2's create_audit_logs stays frozen.
  def change do
    alter table(:audit_logs) do
      add :actor_subtype, :string
    end
  end
end
