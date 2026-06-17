defmodule QuoteAssist.Repo.Migrations.AddDisplayNameToUsers do
  use Ecto.Migration

  # Display name collected during owner onboarding (R3). The rest of the profile
  # (timezone, avatar) lands in R6; only the name is pulled forward here.
  def change do
    alter table(:users) do
      add :display_name, :string
    end
  end
end
