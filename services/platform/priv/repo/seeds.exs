# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# It also runs as part of `mix ecto.setup` / `mix ecto.reset`.
#
# ── R2 dev/staging seed ───────────────────────────────────────────────────────
# One tenant (`acme`) reachable on its subdomain (http://acme.lvh.me:4000) with the
# built-in role catalog seeded, plus a few members so you can exercise tenant-scoped
# sign-in end to end: password login, the magic-link flow, and role-scoped access.
#
# The magic-link handler stays silent for unknown emails (no user-enumeration), so
# without seeded users no email is ever sent — seed first, then request a link and
# read it at http://localhost:4000/dev/mailbox.
#
# Idempotent and guarded to dev/staging only. Password comes from DEV_USER_PASSWORD
# (must be >= 12 chars).

alias QuoteAssist.Accounts
alias QuoteAssist.Accounts.User
alias QuoteAssist.Repo
alias QuoteAssist.Tenants

deploy_env = Application.get_env(:quote_assist, :deploy_env, "dev")

if deploy_env in ["dev", "staging"] do
  password = System.get_env("DEV_USER_PASSWORD", "change-me-please")

  # 1) Tenant + role catalog.
  tenant =
    case Tenants.get_tenant_by_slug("acme") do
      nil ->
        {:ok, tenant} = Tenants.create_tenant(%{name: "Acme Travel", slug: "acme"})
        tenant

      existing ->
        existing
    end

  # Promote the dev tenant from trial → active via the guarded transition (writes an
  # audit row). No-op on re-runs once it is already active.
  tenant =
    if tenant.status == :trial do
      {:ok, active} = Tenants.transition_status(tenant, :active, :system)
      active
    else
      tenant
    end

  Tenants.seed_default_roles(tenant)

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

  ensure_member = fn %User{} = user, role_slug ->
    role = Tenants.get_role_by_slug(tenant, role_slug)

    case Tenants.get_active_membership(tenant, user) do
      nil -> {:ok, _membership} = Tenants.create_membership(tenant, user, role)
      _existing -> :ok
    end
  end

  # 2) Members — confirmed (password + magic link) and one unconfirmed.
  "owner@acme.test" |> confirm_with_password.() |> ensure_member.("owner")
  "agent@acme.test" |> confirm_with_password.() |> ensure_member.("agent")

  # Unconfirmed user — exercises the magic-link *confirmation* path; a viewer
  # membership lets them reach the workspace once confirmed.
  "newbie@acme.test" |> ensure_user.() |> ensure_member.("viewer")

  IO.puts("""
  Seeded dev tenant + members (password = DEV_USER_PASSWORD, default "change-me-please"):
    tenant:  acme (active)  →  http://acme.lvh.me:4000/login
    owner@acme.test   (owner,  password + magic link)
    agent@acme.test   (agent,  password + magic link)
    newbie@acme.test  (viewer, unconfirmed — magic-link confirm)
  Read dev emails at http://localhost:4000/dev/mailbox.
  """)
else
  IO.puts("Skipping dev seed (deploy_env=#{deploy_env}).")
end
