defmodule QuoteAssist.Policy do
  @moduledoc """
  The system-defined permission catalog and authorization checks.

  Permissions are a fixed, code-owned vocabulary (`"<resource>:<action>"`). Roles
  bundle them (`QuoteAssist.Accounts.Role`) and `can?/3` checks the active
  membership's role on a `QuoteAssist.Accounts.Scope`. New permissions = code +
  migration, never user input.
  """
  alias QuoteAssist.Accounts.Scope

  # Default permission bundle seeded for each persona's role. Tenant admins later
  # compose custom roles from this same catalog (R9).
  @site_admin ~w(tenant:manage vertical:manage plan:manage platform:view)
  @agency_admin ~w(tenant:configure user:manage role:manage approval:manage pricing:manage)
  @salesperson ~w(quote:create quote:price discount:apply approval:request)

  @doc "The default permission bundle for a persona."
  def permissions_for(:site_admin), do: @site_admin
  def permissions_for(:agency_admin), do: @agency_admin
  def permissions_for(:salesperson), do: @salesperson

  @doc "The full, flat permission catalog (the only valid permission strings)."
  def all_permissions, do: @site_admin ++ @agency_admin ++ @salesperson

  @doc """
  Whether the scope's active membership/role grants `<resource>:<action>`.

      Policy.can?(scope, :manage, :tenant)   # checks "tenant:manage"
  """
  def can?(%Scope{} = scope, action, resource) when is_atom(action) and is_atom(resource) do
    granted?(scope, "#{resource}:#{action}")
  end

  defp granted?(%Scope{membership: %{role: %{permissions: permissions}}}, permission)
       when is_list(permissions) do
    permission in permissions
  end

  defp granted?(_scope, _permission), do: false
end
