defmodule QuoteAssist.Repo.Migrations.CreateQuoteMessages do
  use Ecto.Migration

  # The reply thread on a quote request (RELEASE_PLAN.md, R12-quote-reply). Ordered
  # messages, each authored by a human member or the AI service. Tenant-scoped + soft
  # delete-aware so it flows through Tenancy.scope/2. Append-only (no updated_at).
  def change do
    create table(:quote_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false

      add :quote_request_id,
          references(:quote_requests, type: :binary_id, on_delete: :restrict),
          null: false

      add :author_type, :string, null: false
      # Null for AI-authored messages; the sending member for human ones.
      add :author_id, references(:memberships, type: :binary_id, on_delete: :nilify_all)
      add :body, :text, null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:quote_messages, [:quote_request_id])
    create index(:quote_messages, [:tenant_id])
  end
end
