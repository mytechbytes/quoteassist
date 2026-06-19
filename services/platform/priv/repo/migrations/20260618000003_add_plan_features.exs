defmodule QuoteAssist.Repo.Migrations.AddPlanFeatures do
  use Ecto.Migration

  # Realigns R3 plans to "Plans are DB-backed with feature limits" (RELEASE_PLAN.md):
  #   * price    — smallest currency unit (paise); 0 = free  (renamed from monthly_price)
  #   * interval — :monthly | :yearly
  #   * limits   — jsonb: quotes_per_month, seats, ai_generations_per_month, custom_domain
  #   * active   — offerable to new tenants
  # The informational `seat_limit` integer is folded into `limits.seats`.
  #
  # Additive migration — R3's create_plans stays frozen.
  def change do
    rename table(:plans), :monthly_price, to: :price

    alter table(:plans) do
      remove :seat_limit, :integer, null: false, default: 0
      add :interval, :string, null: false, default: "monthly"
      add :limits, :map, null: false, default: %{}
      add :active, :boolean, null: false, default: true
    end
  end
end
