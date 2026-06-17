defmodule QuoteAssist.Repo.Migrations.CreateAdmins do
  use Ecto.Migration

  # Site administrators — a COMPLETELY separate identity from tenant `users`
  # (RELEASE_PLAN.md). Own table, own session tokens, own auth pipeline. No
  # tenant_id, no membership. Created only via Accounts.register_admin/1
  # (mix qa.create_admin) — there is no HTTP/seed/env-var path. Soft-deleted like
  # every identity table; email unique among live rows (citext, case-insensitive).
  def change do
    create table(:admins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :last_sign_in_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:admins, [:email],
             where: "deleted_at IS NULL",
             name: :admins_email_live_index
           )

    # Admin session tokens — mirrors users_tokens but session-only (admins use a
    # password login, no magic-link / remember-me). Stored in the DB so sessions can
    # be revoked on logout and expire independently of the signed cookie.
    create table(:admins_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :admin_id, references(:admins, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:admins_tokens, [:admin_id])
    create unique_index(:admins_tokens, [:context, :token])
  end
end
