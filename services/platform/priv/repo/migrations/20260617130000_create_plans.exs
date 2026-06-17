defmodule QuoteAssist.Repo.Migrations.CreatePlans do
  use Ecto.Migration

  # Subscription plans (R3). A small platform-level catalog seeded with Starter +
  # Growth (priv/repo/seeds.exs); tenants reference one via tenants.plan_id. Carries
  # the attributes the admin UI / future billing read (seat limit, monthly price).
  # Soft-deleted like every other table (slug unique among live rows).
  def change do
    create table(:plans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :monthly_price, :integer, null: false, default: 0
      add :seat_limit, :integer, null: false, default: 0
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:plans, [:slug],
             where: "deleted_at IS NULL",
             name: :plans_slug_live_index
           )
  end
end
