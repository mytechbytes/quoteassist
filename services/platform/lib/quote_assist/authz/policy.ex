defmodule QuoteAssist.Authz.Policy do
  @moduledoc """
  Authorization checks against a scope's permissions. A scope's permissions are the
  set granted by the user's role for the resolved tenant (see
  `permissions_for_membership/1`). The owner role is seeded with every catalog key,
  so no role is special-cased here.
  """
  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Tenants.{Membership, Role}

  @doc """
  Whether `scope` may perform `permission`. The optional third argument is a
  resource/context for future per-resource rules (R7+); it is unused for now, which
  is why both `can?/2` and `can?/3` exist.
  """
  def can?(scope, permission, resource \\ nil)

  def can?(%Scope{permissions: permissions}, permission, _resource)
      when is_list(permissions) and is_binary(permission) do
    permission in permissions
  end

  def can?(_scope, _permission, _resource), do: false

  @doc "The permission keys granted by a membership's role (empty when absent)."
  def permissions_for_membership(%Membership{role: %Role{permissions: permissions}})
      when is_list(permissions),
      do: permissions

  def permissions_for_membership(_), do: []
end
