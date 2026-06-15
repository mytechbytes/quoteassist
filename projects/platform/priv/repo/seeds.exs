# Seeds for local/staging. Idempotent — safe to run repeatedly via `mix run
# priv/repo/seeds.exs` (or `mix ecto.setup`).
#
# Creates a demo tenant, the system roles, and one confirmed user per persona:
#
#   admin@quoteassist.test   → Site Administrator    (/admin)
#   owner@northwind.test     → Agency Admin          (/agency)
#   seller@northwind.test    → Sales Person (Senior) (/app)
#   demo@quoteassist.test    → Agency Admin + Sales Person (multi-persona launcher)
#
# All use the password: quoteassist-dev-1

alias QuoteAssist.Accounts
alias QuoteAssist.Accounts.Membership
alias QuoteAssist.Accounts.User
alias QuoteAssist.Policy
alias QuoteAssist.Repo
alias QuoteAssist.Tenancy
alias QuoteAssist.Tenancy.Tenant

require Logger

password = "quoteassist-dev-1"

upsert_tenant = fn name, slug ->
  case Tenancy.get_tenant_by_slug(slug) do
    nil ->
      {:ok, tenant} = Tenancy.create_tenant(%{name: name, slug: slug, status: :active})
      tenant

    %Tenant{} = tenant ->
      tenant
  end
end

upsert_system_role = fn name, persona ->
  case Accounts.get_system_role(name) do
    nil ->
      {:ok, role} =
        Accounts.create_role(%{name: name, permissions: Policy.permissions_for(persona)})

      role

    role ->
      role
  end
end

upsert_user = fn email ->
  case Accounts.get_user_by_email(email) do
    nil ->
      {:ok, user} = Accounts.register_user(%{"email" => email})

      user
      |> User.password_changeset(%{"password" => password})
      |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
      |> Repo.update!()

    %User{} = user ->
      user
  end
end

upsert_membership = fn user, persona, attrs ->
  unless Accounts.get_membership(user, persona) do
    {:ok, _} =
      Accounts.create_membership(Map.merge(%{user_id: user.id, persona: persona}, attrs))
  end
end

# Tenant + system roles
northwind = upsert_tenant.("Northwind Supply", "northwind")
site_admin_role = upsert_system_role.("Site Administrator", :site_admin)
agency_admin_role = upsert_system_role.("Agency Owner", :agency_admin)
salesperson_role = upsert_system_role.("Salesperson", :salesperson)

# One user per persona
admin = upsert_user.("admin@quoteassist.test")
owner = upsert_user.("owner@northwind.test")
seller = upsert_user.("seller@northwind.test")
demo = upsert_user.("demo@quoteassist.test")

upsert_membership.(admin, :site_admin, %{role_id: site_admin_role.id})

upsert_membership.(owner, :agency_admin, %{tenant_id: northwind.id, role_id: agency_admin_role.id})

upsert_membership.(seller, :salesperson, %{
  tenant_id: northwind.id,
  role_id: salesperson_role.id,
  seller_level: "Senior"
})

# Multi-persona user (shows two launcher tiles)
upsert_membership.(demo, :agency_admin, %{tenant_id: northwind.id, role_id: agency_admin_role.id})

upsert_membership.(demo, :salesperson, %{
  tenant_id: northwind.id,
  role_id: salesperson_role.id,
  seller_level: "Junior"
})

Logger.info(
  "Seeded tenant #{northwind.slug} · #{Repo.aggregate(User, :count)} users · " <>
    "#{Repo.aggregate(Membership, :count)} memberships"
)
