defmodule QuoteAssist.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      # Stable key within a tenant (owner, lead, senior, agent, viewer, …).
      add :slug, :string, null: false
      add :description, :string
      # Permission keys from the code-owned catalog (QuoteAssist.Authz.Permissions).
      # The roles UI (R5) composes these; the catalog is never invented in the DB.
      add :permissions, {:array, :string}, null: false, default: []
      # Built-in roles are seeded per tenant and are not deletable in the UI (R5).
      add :builtin, :boolean, null: false, default: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:roles, [:tenant_id])

    # One live role per (tenant, slug). Partial so soft-deleted slugs can be reused.
    create unique_index(:roles, [:tenant_id, :slug],
             where: "deleted_at IS NULL",
             name: :roles_tenant_slug_live_index
           )
  end
end
