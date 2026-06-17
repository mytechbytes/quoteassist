defmodule QuoteAssist.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      # Subdomain label, e.g. "acme" in acme.quoteassist.mytechbytes.in.
      add :slug, :string, null: false
      # State machine — trial → active → suspended → cancelled. Stored as a string;
      # validated via Tenant.can_transition?/2 at the changeset (illegal jumps rejected).
      add :status, :string, null: false, default: "trial"

      # Custom domain. Populated/verified in R-CD; the resolver already reads the
      # verified path in R2. A verified custom domain is globally unique.
      add :custom_domain, :string
      add :custom_domain_status, :string, null: false, default: "none"
      add :custom_domain_token, :string

      # Soft delete (null = live). Default queries filter it out; hard purge is a
      # separate, audited admin action (see RELEASE_PLAN.md).
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Slug unique among live tenants — partial index so a soft-deleted slug can be
    # re-onboarded later.
    create unique_index(:tenants, [:slug],
             where: "deleted_at IS NULL",
             name: :tenants_slug_live_index
           )

    # A verified custom domain must be unique across all (live) tenants so two
    # tenants can never claim the same host.
    create unique_index(:tenants, [:custom_domain],
             where: "deleted_at IS NULL AND custom_domain IS NOT NULL",
             name: :tenants_custom_domain_live_index
           )
  end
end
