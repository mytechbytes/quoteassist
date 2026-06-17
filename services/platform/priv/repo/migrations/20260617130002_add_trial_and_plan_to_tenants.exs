defmodule QuoteAssist.Repo.Migrations.AddTrialAndPlanToTenants do
  use Ecto.Migration

  # R3 adds the 15-day trial deadline and the plan reference to tenants. A separate
  # migration (never edit R2's create_tenants). plan_id is nilify_all so removing a
  # plan never deletes tenants; it stays nullable because R2 dev tenants predate
  # plans (admin-created tenants always set it).
  def change do
    alter table(:tenants) do
      add :trial_expires_at, :utc_datetime
      add :plan_id, references(:plans, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:tenants, [:plan_id])
  end
end
