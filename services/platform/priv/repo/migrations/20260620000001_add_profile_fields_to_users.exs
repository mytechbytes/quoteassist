defmodule QuoteAssist.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  # R7-rbac self-service profile (the `self:update` surface): avatar (a local URL for
  # now) + timezone, alongside the `display_name` pulled forward in R3. These three
  # are the member-editable profile; everything else on `users` is auth machinery.
  def change do
    alter table(:users) do
      add :avatar_url, :string
      add :timezone, :string
    end
  end
end
