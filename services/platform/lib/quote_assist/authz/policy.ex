defmodule QuoteAssist.Authz.Policy do
  @moduledoc """
  Tenant-side authorization — the protected-type predicate (RELEASE_PLAN.md, R2):

      can?(actor, perm) =
        actor.type == :owner            # protected type → always true (computed)
        or perm in member baseline      # self:* + request:create, held by every member
        or perm in permissions(role)    # normal type → role-driven

  The `owner` type holds **all** permissions, computed — a short-circuit `true`, never
  an enumerated list — so any permission added in a future release is held
  automatically. Members hold the member baseline (the fixed `self:*` keys plus
  `request:create`, so any member can raise a request) plus whatever their role grants.
  A scope's `permissions` are the keys granted by the membership's role (see
  `permissions_for_membership/1`); owners carry no role and so no enumerated keys.
  """
  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Authz.Permissions
  alias QuoteAssist.Tenants.{Membership, Role}

  @doc """
  Whether `scope` may perform `permission`. The optional third argument is a
  resource/context for future per-resource rules (R7+); it is unused for now, which
  is why both `can?/2` and `can?/3` exist.
  """
  def can?(scope, permission, resource \\ nil)

  # Protected type → computed all-access. Checked first, before any role/baseline lookup.
  def can?(%Scope{membership: %Membership{type: :owner}}, _permission, _resource), do: true

  def can?(%Scope{} = scope, permission, _resource) when is_binary(permission) do
    Permissions.member_baseline?(permission) or
      (is_list(scope.permissions) and permission in scope.permissions)
  end

  def can?(_scope, _permission, _resource), do: false

  @doc """
  The role-composable permission keys carried by a membership. A member's keys come
  from its role; an owner carries none here — its all-access is computed in `can?/3`
  via the protected type, never an enumerated list.
  """
  def permissions_for_membership(%Membership{type: :owner}), do: []

  def permissions_for_membership(%Membership{role: %Role{permissions: permissions}})
      when is_list(permissions),
      do: permissions

  def permissions_for_membership(_), do: []
end
