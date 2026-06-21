defmodule QuoteAssist.Repo.Migrations.CreateQuoteRequests do
  use Ecto.Migration

  # Quote requests = inbound leads (RELEASE_PLAN.md, R11-quotes). Tenant-scoped, soft
  # deleted, with a status state machine (open → in_progress → quoted → closed). The
  # reply thread (R12) hangs off these.
  def change do
    create table(:quote_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      # The member who entered the lead (tenant-scoped, never the global user).
      add :submitted_by, references(:memberships, type: :binary_id, on_delete: :nilify_all)
      add :customer_name, :string, null: false
      add :customer_email, :string, null: false
      add :subject, :string, null: false
      add :body, :text, null: false
      add :status, :string, null: false, default: "open"
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:quote_requests, [:tenant_id])
    create index(:quote_requests, [:tenant_id, :status])
  end
end
