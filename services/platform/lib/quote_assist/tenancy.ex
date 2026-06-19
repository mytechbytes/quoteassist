defmodule QuoteAssist.Tenancy do
  @moduledoc """
  Tenant query scoping — the enforcement point for isolation. Every query on a
  tenant-owned table must go through `scope/2`, which constrains it to the resolved
  tenant and filters soft-deleted rows. It raises when no tenant is in scope, so a
  forgotten scope fails loud instead of silently leaking another tenant's data.

      Role |> Tenancy.scope(socket.assigns.current_scope) |> Repo.all()
  """
  import Ecto.Query

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Tenants.Membership

  defmodule NoTenantError do
    @moduledoc "Raised when a tenant-scoped query runs without a tenant in scope."
    defexception message: "no tenant in scope — refusing to run an unscoped tenant query"
  end

  @doc """
  Constrains `query` to the scope's tenant and to live (non-soft-deleted) rows.
  Raises `NoTenantError` when the scope carries no tenant — this is what makes a
  cross-tenant or unscoped read fail loud.
  """
  def scope(query, %Scope{tenant: %{id: tenant_id}}) when not is_nil(tenant_id) do
    from row in query, where: row.tenant_id == ^tenant_id and is_nil(row.deleted_at)
  end

  def scope(_query, _scope), do: raise(NoTenantError)

  @doc """
  Memberships visible to the scope's actor — the **query-layer** half of owner
  protection (RELEASE_PLAN.md, R2): a non-owner can never see owners. Returns a
  tenant-scoped, live-only `Membership` query; for a non-owner actor it additionally
  excludes `:owner` rows. Hiding owners only in the template would be a security bug,
  so the exclusion lives here, in the query, alongside `scope/2`.
  """
  def members_visible_to(%Scope{} = actor_scope) do
    base = scope(Membership, actor_scope)

    if owner?(actor_scope) do
      base
    else
      from m in base, where: m.type != :owner
    end
  end

  @doc """
  Membership types the scope's actor may assign — the other half of owner protection.
  Only an owner may assign `:owner`; a member may assign `:member` only, so a member
  can never grant the protected type or escalate themselves by any path.
  """
  def assignable_types_for(%Scope{} = actor_scope) do
    if owner?(actor_scope), do: [:owner, :member], else: [:member]
  end

  defp owner?(%Scope{membership: %Membership{type: :owner}}), do: true
  defp owner?(_), do: false
end
