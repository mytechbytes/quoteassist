defmodule QuoteAssist.Repo.Migrations.CreateTenancyRbac do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :citext, null: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenants, [:slug])

    # Roles bundle system-defined permissions. tenant_id NULL = a platform/system
    # role (e.g. the site-admin role); non-NULL = a tenant-owned role (R9).
    create table(:roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :permissions, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:roles, [:tenant_id])
    create unique_index(:roles, [:tenant_id, :name])
    # System roles (tenant_id NULL) need unique names too — NULLs are distinct in a
    # composite unique index, so enforce it with a partial index.
    create unique_index(:roles, [:name],
             where: "tenant_id IS NULL",
             name: :roles_system_name_index
           )

    # A membership grants a user a persona within a tenant. tenant_id is NULL for
    # the platform-level site_admin persona (exempt from tenant scoping).
    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all)
      add :role_id, references(:roles, type: :binary_id, on_delete: :nilify_all)
      add :persona, :string, null: false
      add :seller_level, :string

      timestamps(type: :utc_datetime)
    end

    create index(:memberships, [:user_id])
    create index(:memberships, [:tenant_id])
    create unique_index(:memberships, [:user_id, :tenant_id, :persona])
    # One platform-level (site_admin) membership per user.
    create unique_index(:memberships, [:user_id, :persona],
             where: "tenant_id IS NULL",
             name: :memberships_user_platform_persona_index
           )
  end
end
