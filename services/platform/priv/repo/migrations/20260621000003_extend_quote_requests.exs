defmodule QuoteAssist.Repo.Migrations.ExtendQuoteRequests do
  use Ecto.Migration

  # Richen quote requests into the full lead/quote model: travel facts surfaced by the
  # designs (reference · route · travel dates · pax · total · currency) plus the lead
  # stage signals — `valid_until` (set when the first quote is sent) and `awaiting`
  # (derived ball-in-court). The status lifecycle moves from open/in_progress/quoted/
  # closed to new → in_progress → quoted → accepted|rejected|expired, + cancelled.
  def change do
    alter table(:quote_requests) do
      add :reference, :string
      add :route, :string
      add :travel_dates, :string
      add :pax, :string
      add :total, :integer
      add :currency, :string, null: false, default: "GBP"
      add :valid_until, :date
      add :awaiting, :string
    end

    # Default new leads to `new`; remap any existing rows onto the new lifecycle.
    execute(
      "ALTER TABLE quote_requests ALTER COLUMN status SET DEFAULT 'new'",
      "ALTER TABLE quote_requests ALTER COLUMN status SET DEFAULT 'open'"
    )

    execute("UPDATE quote_requests SET status = 'new' WHERE status = 'open'", "")
    execute("UPDATE quote_requests SET status = 'cancelled' WHERE status = 'closed'", "")

    # Human-facing reference (e.g. QA-1042), unique per tenant.
    create unique_index(:quote_requests, [:tenant_id, :reference],
             where: "reference IS NOT NULL",
             name: :quote_requests_tenant_reference_index
           )
  end
end
