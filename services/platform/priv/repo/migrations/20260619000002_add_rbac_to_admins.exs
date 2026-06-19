defmodule QuoteAssist.Repo.Migrations.AddRbacToAdmins do
  use Ecto.Migration

  # Retrofits the R3 `admins` table for admin-side RBAC (RELEASE_PLAN.md,
  # R4-retrofit). R3 shipped `admins` with no type/role/active and a single
  # `:require_admin` guard; this adds the protected-type pattern:
  #
  #   * type    — `super_admin` (the protected root type: computed all-access, carries
  #               NO role) vs `admin` (role-driven). The column default is the SAFE
  #               value `admin`; the existing bootstrap admin(s) are backfilled to
  #               `super_admin` in this same transaction so the "≥1 active super_admin"
  #               invariant holds the instant the column exists.
  #   * active  — gates FUTURE logins (deactivation), independent of soft-delete
  #               (`deleted_at` = removal).
  #   * role_id — required for a normal admin, null for a super_admin.
  #
  # Additive — R3's create_admins migration stays frozen.
  def up do
    alter table(:admins) do
      add :type, :string, null: false, default: "admin"
      add :active, :boolean, null: false, default: true
      add :role_id, references(:admin_roles, type: :binary_id, on_delete: :restrict)
    end

    create index(:admins, [:role_id])

    # Promote every existing (live) admin — the R3 bootstrap admin — to super_admin,
    # in the same transaction as the column add.
    execute("UPDATE admins SET type = 'super_admin' WHERE deleted_at IS NULL")
  end

  def down do
    drop index(:admins, [:role_id])

    alter table(:admins) do
      remove :role_id
      remove :active
      remove :type
    end
  end
end
