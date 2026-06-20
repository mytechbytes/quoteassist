defmodule QuoteAssist.Repo.Migrations.CreateRequests do
  use Ecto.Migration

  # The generic tenant request inbox (RELEASE_PLAN.md, R7-rbac). `leave` is the first
  # type; the table is built to carry other request types (access, plan_change,
  # support, …) without a new schema each time. Member→owner asks, owner-processed,
  # with a small status state machine (`open → approved | declined | cancelled`).
  def change do
    create table(:requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :type, :string, null: false
      add :status, :string, null: false, default: "open"
      add :note, :text
      add :resolution, :text
      # Requester + processor are membership ids (tenant-scoped, not the global user).
      add :requested_by, references(:memberships, type: :binary_id, on_delete: :restrict),
        null: false

      add :resolved_by, references(:memberships, type: :binary_id, on_delete: :restrict)
      add :resolved_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:requests, [:tenant_id])
    create index(:requests, [:requested_by])

    # At most one OPEN request per (tenant, requester, type). Partial so resolved /
    # cancelled / soft-deleted rows never block raising a fresh one.
    create unique_index(:requests, [:tenant_id, :requested_by, :type],
             where: "status = 'open' AND deleted_at IS NULL",
             name: :requests_open_per_type_index
           )
  end
end
