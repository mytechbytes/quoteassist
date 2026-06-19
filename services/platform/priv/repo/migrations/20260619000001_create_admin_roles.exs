defmodule QuoteAssist.Repo.Migrations.CreateAdminRoles do
  use Ecto.Migration

  # Admin-side roles (RELEASE_PLAN.md, R4-retrofit). The platform mirror of the
  # tenant `roles` table — same shape, but NO `tenant_id` (admins are a platform
  # identity, not tenant-scoped). A role is a named bundle of permission keys drawn
  # from the code-owned admin catalog (QuoteAssist.Authz.AdminPermissions); the
  # `super_admin` protected type carries NO role (its all-access is computed), so this
  # table only ever holds normal-admin roles.
  def change do
    create table(:admin_roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      # Stable key (operations, support, …).
      add :slug, :string, null: false
      add :description, :string
      # Permission keys from the code-owned admin catalog. The roles UI composes
      # these; the catalog is never invented in the DB.
      add :permissions, {:array, :string}, null: false, default: []
      # Built-in roles are seeded and not deletable in the UI.
      add :builtin, :boolean, null: false, default: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # One live role per slug (platform-global). Partial so soft-deleted slugs reuse.
    create unique_index(:admin_roles, [:slug],
             where: "deleted_at IS NULL",
             name: :admin_roles_slug_live_index
           )
  end
end
