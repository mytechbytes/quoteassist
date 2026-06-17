defmodule QuoteAssist.Tenants.Membership do
  @moduledoc """
  Joins a global `User` identity to a `Tenant` with a `Role`. The many-to-many
  association between users and tenants lives only here (RELEASE_PLAN.md): one email
  can belong to several tenants, one (live) membership each. Soft-deleted via
  `deleted_at`; a removed member can rejoin (the unique index is partial on live rows).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Accounts.User
  alias QuoteAssist.Tenants.{Role, Tenant}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memberships" do
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    belongs_to :user, User
    belongs_to :role, Role

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:tenant_id, :user_id, :role_id])
    |> validate_required([:tenant_id, :user_id, :role_id])
    |> assoc_constraint(:tenant)
    |> assoc_constraint(:user)
    |> assoc_constraint(:role)
    |> unique_constraint([:tenant_id, :user_id], name: :memberships_tenant_user_live_index)
  end
end
