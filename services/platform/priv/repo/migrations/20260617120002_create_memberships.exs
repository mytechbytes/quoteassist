defmodule QuoteAssist.Repo.Migrations.CreateMemberships do
  use Ecto.Migration

  def change do
    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :role_id, references(:roles, type: :binary_id, on_delete: :restrict), null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:memberships, [:tenant_id])
    create index(:memberships, [:user_id])
    create index(:memberships, [:role_id])

    # A user has at most one live membership per tenant (RELEASE_PLAN.md: one
    # membership each). Partial so a removed (soft-deleted) member can rejoin.
    create unique_index(:memberships, [:tenant_id, :user_id],
             where: "deleted_at IS NULL",
             name: :memberships_tenant_user_live_index
           )
  end
end
