defmodule QuoteAssist.Tenants.Membership do
  @moduledoc """
  Joins a global `User` identity to a `Tenant`. The many-to-many association between
  users and tenants lives only here (RELEASE_PLAN.md): one email can belong to several
  tenants, one (live) membership each. Soft-deleted via `deleted_at`; a removed member
  can rejoin (the unique index is partial on live rows).

  ## `type` — the protected-type pattern (R2)

  A `type` sits above the role and gates authorization before any role check:

    * `:owner` — the protected type. Computed all-access (`QuoteAssist.Authz.Policy`
      short-circuits), so it carries **no** `role_id`. Invisible/immutable/unassignable
      to members, guarded by a last-active-owner invariant.
    * `:member` — the normal type. Authorization is role-driven, so a `role_id` is
      **required**.

  `active` gates future access (deactivation); `deleted_at` is removal. They are
  distinct: a deactivated member keeps their row (and can be reactivated), a removed
  one is soft-deleted.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Accounts.User
  alias QuoteAssist.Tenants.{Role, Tenant}

  @types [:owner, :member]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memberships" do
    field :type, Ecto.Enum, values: @types, default: :member
    field :active, :boolean, default: true
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    belongs_to :user, User
    belongs_to :role, Role

    timestamps(type: :utc_datetime)
  end

  @doc "All valid membership types."
  def types, do: @types

  @doc """
  Display label for a membership: the protected `owner` type renders as "Owner"
  (it carries no role); a member renders its role's name. Safe when the role is
  absent or not loaded — owners would otherwise blow up `membership.role.name`.
  """
  def role_label(%__MODULE__{type: :owner}), do: "Owner"
  def role_label(%__MODULE__{role: %Role{name: name}}), do: name
  def role_label(_membership), do: "Member"

  @doc """
  Changeset for a **member** (normal type): a `role_id` is required, and `type` is
  forced to `:member` so a member can never be created as an owner by a crafted param.
  """
  def member_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:tenant_id, :user_id, :role_id, :active])
    |> put_change(:type, :member)
    |> validate_required([:tenant_id, :user_id, :role_id])
    |> common_validations()
    |> assoc_constraint(:role)
  end

  @doc """
  Changeset for an **owner** (protected type): no `role_id` (computed all-access), so
  it is cleared even if supplied.
  """
  def owner_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:tenant_id, :user_id, :active])
    |> put_change(:type, :owner)
    |> put_change(:role_id, nil)
    |> validate_required([:tenant_id, :user_id])
    |> common_validations()
  end

  @doc """
  Changeset for reassigning a **member's** role (R7-rbac). Casts only `role_id`, so it
  can neither change the `type` nor touch an owner: the context refuses an owner target
  before this is ever reached (an owner has no role — its access is computed).
  """
  def role_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role_id])
    |> validate_required([:role_id])
    |> assoc_constraint(:role)
  end

  @doc """
  Changeset promoting a member to the protected **owner** type (R7-rbac, owner-only):
  clears `role_id` (owners carry no role — computed all-access). Type is set directly,
  never cast, so promotion is only reachable through this function.
  """
  def promote_changeset(membership) do
    membership
    |> change()
    |> put_change(:type, :owner)
    |> put_change(:role_id, nil)
  end

  @doc """
  Changeset demoting an owner back to a normal **member** (R7-rbac, owner-only): a
  `role_id` becomes required (a member's access is role-driven). The last-active-owner
  guard runs in the context's transaction, never here.
  """
  def demote_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role_id])
    |> put_change(:type, :member)
    |> validate_required([:role_id])
    |> assoc_constraint(:role)
  end

  defp common_validations(changeset) do
    changeset
    |> assoc_constraint(:tenant)
    |> assoc_constraint(:user)
    |> unique_constraint([:tenant_id, :user_id], name: :memberships_tenant_user_live_index)
  end
end
