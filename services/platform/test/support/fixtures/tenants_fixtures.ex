defmodule QuoteAssist.TenantsFixtures do
  @moduledoc """
  Test helpers for creating tenants, roles, and memberships via the
  `QuoteAssist.Tenants` context.
  """

  alias QuoteAssist.Accounts.User
  alias QuoteAssist.AccountsFixtures
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Tenant

  def unique_tenant_slug, do: "t#{System.unique_integer([:positive])}"

  @doc "A trial tenant with the built-in roles seeded. `:slug`/`:name` overridable."
  def tenant_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Tenant #{System.unique_integer([:positive])}",
        slug: unique_tenant_slug()
      })

    {:ok, tenant} = Tenants.create_tenant(attrs)
    Tenants.seed_default_roles(tenant)
    tenant
  end

  @doc "An active (resolvable) tenant with built-in roles seeded."
  def active_tenant_fixture(attrs \\ %{}) do
    {:ok, tenant} = Tenants.transition_status(tenant_fixture(attrs), :active, :system)
    tenant
  end

  @doc """
  Sets a tenant's custom domain + status directly, simulating the R-CD verification
  flow (which the public `Tenant.changeset/2` deliberately cannot do).
  """
  def put_custom_domain!(%Tenant{} = tenant, domain, status) do
    tenant
    |> Ecto.Changeset.change(custom_domain: String.downcase(domain), custom_domain_status: status)
    |> QuoteAssist.Repo.update!()
  end

  @doc "Transitions a tenant to a target status via the guarded transition."
  def tenant_with_status_fixture(status, attrs \\ %{}) do
    {:ok, tenant} = Tenants.transition_status(tenant_fixture(attrs), status, :system)
    tenant
  end

  @doc "A custom (non-builtin) tenant-scoped role."
  def role_fixture(%Tenant{} = tenant, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Role #{System.unique_integer([:positive])}",
        slug: "role#{System.unique_integer([:positive])}",
        permissions: []
      })

    {:ok, role} = Tenants.create_role(tenant, attrs)
    role
  end

  @doc "A live membership for `user` in `tenant` with the given built-in role slug."
  def membership_fixture(%Tenant{} = tenant, %User{} = user, role_slug \\ "owner") do
    role = Tenants.get_role_by_slug(tenant, role_slug)
    {:ok, membership} = Tenants.create_membership(tenant, user, role)
    membership
  end

  @doc "A fresh user with a membership in `tenant`. Returns `{user, membership}`."
  def member_fixture(%Tenant{} = tenant, role_slug \\ "owner") do
    user = AccountsFixtures.user_fixture()
    {user, membership_fixture(tenant, user, role_slug)}
  end
end
