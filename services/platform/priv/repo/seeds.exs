# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# It also runs as part of `mix ecto.setup` / `mix ecto.reset`.
#
# ── R2 dev/staging seed ───────────────────────────────────────────────────────
# Several tenants, each reachable on its own subdomain with the built-in role
# catalog seeded and its own members. Each user belongs to exactly one tenant, so
# you can verify isolation: a user of one tenant cannot sign in to another.
#
# The magic-link handler stays silent for unknown / non-member emails (no
# enumeration), so request a link on the tenant subdomain the user belongs to and
# read it at http://localhost:4000/dev/mailbox.
#
# Idempotent and guarded to dev/staging only. Password comes from DEV_USER_PASSWORD
# (must be >= 12 chars).

alias QuoteAssist.Accounts
alias QuoteAssist.Accounts.User
alias QuoteAssist.Plans
alias QuoteAssist.Repo
alias QuoteAssist.Tenants

deploy_env = Application.get_env(:quote_assist, :deploy_env, "dev")

# Plans are platform data the admin picks from when creating a tenant, so seed them in
# dev/staging/prod (idempotent). Skipped under test — the suite builds its own plan
# fixtures and a clean table. Admins themselves are never seeded — use `mix qa.create_admin`.
unless deploy_env == "test" do
  Plans.seed_plans()
  IO.puts("Seeded plans: #{Enum.map_join(Plans.list_plans(), ", ", & &1.name)}")

  # Built-in admin roles a super_admin can assign to scoped admins (R4-retrofit). The
  # `super_admin` protected type needs no role, so it is never seeded here.
  Accounts.seed_default_admin_roles()
  IO.puts("Seeded admin roles: #{Enum.map_join(Accounts.list_admin_roles(), ", ", & &1.name)}")
end

if deploy_env in ["dev", "staging"] do
  password = System.get_env("DEV_USER_PASSWORD", "panther@2010")
  scheme = Application.get_env(:quote_assist, :tenant_url_scheme, "http")
  base = Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.localhost:4000")
  growth = Plans.get_plan_by_slug("growth")

  ensure_user = fn email ->
    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{email: email})
        user

      existing ->
        existing
    end
  end

  confirm_with_password = fn email ->
    email
    |> ensure_user.()
    |> User.password_changeset(%{password: password})
    |> Repo.update!()
    |> User.confirm_changeset()
    |> Repo.update!()
  end

  ensure_tenant = fn slug, name ->
    tenant =
      case Tenants.get_tenant_by_slug(slug) do
        nil ->
          {:ok, tenant} = Tenants.create_tenant(%{name: name, slug: slug, plan_id: growth.id})
          tenant

        existing ->
          existing
      end

    # Promote trial → active so the tenant resolves; no-op once already active.
    tenant =
      if tenant.status == :trial do
        {:ok, active} = Tenants.transition_status(tenant, :active, :system)
        active
      else
        tenant
      end

    Tenants.seed_default_roles(tenant)
    tenant
  end

  # "owner" is the protected membership *type* (no role); other slugs are member roles.
  ensure_member = fn tenant, %User{} = user, role_slug ->
    case Tenants.get_active_membership(tenant, user) do
      nil ->
        case role_slug do
          "owner" ->
            {:ok, _membership} = Tenants.create_owner_membership(tenant, user)

          slug ->
            role = Tenants.get_role_by_slug(tenant, slug)
            {:ok, _membership} = Tenants.create_membership(tenant, user, role)
        end

      _existing ->
        :ok
    end
  end

  # Each tenant + its members. `confirmed: false` exercises the magic-link confirm
  # path (no password yet). Emails are tenant-specific so memberships never overlap.
  specs = [
    %{
      slug: "acme",
      name: "Acme Travel",
      members: [
        %{email: "owner@acme.test", role: "owner"},
        %{email: "manager@acme.test", role: "manager"},
        %{email: "agent@acme.test", role: "agent"},
        %{email: "newbie@acme.test", role: "agent", confirmed: false}
      ]
    },
    %{
      slug: "globex",
      name: "Globex Holidays",
      members: [
        %{email: "owner@globex.test", role: "owner"},
        %{email: "agent@globex.test", role: "agent"}
      ]
    },
    %{
      slug: "umbrella",
      name: "Umbrella Voyages",
      members: [
        %{email: "owner@umbrella.test", role: "owner"}
      ]
    }
  ]

  for spec <- specs do
    tenant = ensure_tenant.(spec.slug, spec.name)

    for member <- spec.members do
      user =
        if Map.get(member, :confirmed, true) do
          confirm_with_password.(member.email)
        else
          ensure_user.(member.email)
        end

      ensure_member.(tenant, user, member.role)
    end
  end

  directory =
    specs
    |> Enum.map_join("\n", fn spec ->
      emails = Enum.map_join(spec.members, ", ", & &1.email)
      "    #{spec.name} → #{scheme}://#{spec.slug}.#{base}/login\n      members: #{emails}"
    end)

  IO.puts("""
  Seeded dev tenants (password = DEV_USER_PASSWORD, default "change-me-please"):
  #{directory}

  Each user belongs to ONE tenant — signing in on another tenant's host is rejected.
  Unconfirmed users (newbie@acme.test) use the magic-link confirm flow.
  Read dev emails at http://localhost:4000/dev/mailbox.

  Site admins are NEVER seeded. Create one (works in every environment) with:
    mix qa.create_admin --email you@example.com --password "your-strong-password"
  Then sign in at http://localhost:4000/admin/login.
  """)
else
  IO.puts("Skipping dev seed (deploy_env=#{deploy_env}).")
end
