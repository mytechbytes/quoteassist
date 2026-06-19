defmodule QuoteAssist.Repo.Migrations.AddSourceToTenants do
  use Ecto.Migration

  # R5-selfreg · how a tenant entered the platform, for admin triage:
  #   "admin"       — created from the admin console (R3 flow).
  #   "self_signup" — self-registered at /register (R5 flow).
  # Stored as a string (Ecto.Enum). Existing rows are admin-created, so the
  # backfill default is "admin".
  def change do
    alter table(:tenants) do
      add :source, :string, null: false, default: "admin"
    end
  end
end
