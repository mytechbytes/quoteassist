defmodule QuoteAssist.Repo.Migrations.AddMembershipTypeAndActive do
  use Ecto.Migration

  # Realigns R2 memberships to the protected-type pattern (RELEASE_PLAN.md, R2).
  # `type` sits above the role and gates authorization: `owner` = computed all-access
  # (carries no role), `member` = role-driven. `active` gates *future* access
  # (deactivation) independently of soft-delete (`deleted_at` = removal). `role_id`
  # becomes nullable because owners carry no role.
  #
  # Additive migration — R2's create_memberships stays frozen.
  def up do
    alter table(:memberships) do
      add :type, :string, null: false, default: "member"
      add :active, :boolean, null: false, default: true
    end

    execute "ALTER TABLE memberships ALTER COLUMN role_id DROP NOT NULL"
  end

  def down do
    execute "ALTER TABLE memberships ALTER COLUMN role_id SET NOT NULL"

    alter table(:memberships) do
      remove :active
      remove :type
    end
  end
end
