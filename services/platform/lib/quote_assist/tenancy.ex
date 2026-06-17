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
end
