defmodule QuoteAssist.Tenancy do
  @moduledoc """
  Tenant context + the **non-negotiable** tenant-isolation helper.

  Every tenant-owned query must go through `scope/2`, which constrains it to the
  caller's active tenant. The tenant is resolved from the current membership
  (LiveView) or JWT claims (API) — never from request params.
  """
  import Ecto.Query, warn: false

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Repo
  alias QuoteAssist.Tenancy.Tenant

  @doc """
  Constrains `query` to the scope's active tenant (matches `tenant_id`).

  Raises if the scope carries no active tenant — this is deliberate: it makes an
  accidental cross-tenant query fail loudly rather than leak data. Site-admin
  (cross-tenant) reads live in admin contexts and don't use this helper.
  """
  def scope(query, %Scope{tenant: %Tenant{id: tenant_id}}) do
    from(row in query, where: row.tenant_id == ^tenant_id)
  end

  def scope(_query, %Scope{} = _scope) do
    raise ArgumentError, "Tenancy.scope/2 requires a scope with an active tenant"
  end

  def list_tenants do
    Repo.all(from t in Tenant, order_by: [asc: t.name])
  end

  def get_tenant!(id), do: Repo.get!(Tenant, id)

  def get_tenant_by_slug(slug) when is_binary(slug), do: Repo.get_by(Tenant, slug: slug)

  def create_tenant(attrs) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  def change_tenant(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.changeset(tenant, attrs)
  end
end
