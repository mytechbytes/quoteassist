defmodule QuoteAssist.Authz.AdminPolicy do
  @moduledoc """
  Admin-side authorization — the protected-type predicate (RELEASE_PLAN.md,
  R4-retrofit), the platform mirror of `QuoteAssist.Authz.Policy`:

      can?(admin, perm) =
        admin.type == :super_admin       # protected type → always true (computed)
        or perm in self:* baseline       # implicit, scoped to own row
        or perm in permissions(role)     # normal type → role-driven

  The `super_admin` type holds **all** permissions, computed — a short-circuit `true`,
  never an enumerated list — so any permission added in a future release is held
  automatically. A normal `admin` holds the fixed `self:*` baseline plus whatever its
  role grants; the role must be preloaded (it is, by
  `QuoteAssist.Accounts.get_admin_by_session_token/1`).
  """
  alias QuoteAssist.Accounts.{Admin, AdminRole}
  alias QuoteAssist.Authz.AdminPermissions

  @doc """
  Whether `admin` may perform `permission`. The optional third argument is a
  resource/context for future per-resource rules; it is unused for now, which is why
  both `can?/2` and `can?/3` exist (mirrors the tenant `Policy`).
  """
  def can?(admin, permission, resource \\ nil)

  # Protected type → computed all-access. Checked first, before any role/baseline lookup.
  def can?(%Admin{type: :super_admin}, _permission, _resource), do: true

  def can?(%Admin{type: :admin} = admin, permission, _resource) when is_binary(permission) do
    AdminPermissions.baseline?(permission) or permission in permissions_for_admin(admin)
  end

  def can?(_admin, _permission, _resource), do: false

  @doc """
  The role-composable permission keys carried by an admin. A normal admin's keys come
  from its role; a super_admin carries none here — its all-access is computed in
  `can?/3` via the protected type, never an enumerated list.
  """
  def permissions_for_admin(%Admin{type: :super_admin}), do: []

  def permissions_for_admin(%Admin{role: %AdminRole{permissions: permissions}})
      when is_list(permissions),
      do: permissions

  def permissions_for_admin(_), do: []
end
