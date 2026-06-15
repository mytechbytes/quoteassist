defmodule QuoteAssist.Accounts.Membership do
  @moduledoc """
  Grants a user a **persona** (and a role) within a tenant.

  `tenant_id` is NULL for the platform-level `:site_admin` persona (exempt from
  tenant scoping); tenant personas (`:agency_admin`, `:salesperson`) require one.
  `seller_level` applies to salespeople (drives discount quotas from R10).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @personas ~w(site_admin agency_admin salesperson)a
  def personas, do: @personas

  schema "memberships" do
    field :persona, Ecto.Enum, values: @personas
    field :seller_level, :string
    belongs_to :user, QuoteAssist.Accounts.User
    belongs_to :tenant, QuoteAssist.Tenancy.Tenant
    belongs_to :role, QuoteAssist.Accounts.Role

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:persona, :seller_level, :user_id, :tenant_id, :role_id])
    |> validate_required([:persona, :user_id])
    |> validate_tenant_for_persona()
    |> assoc_constraint(:user)
    |> assoc_constraint(:tenant)
    |> assoc_constraint(:role)
    |> unique_constraint([:user_id, :tenant_id, :persona],
      name: :memberships_user_id_tenant_id_persona_index
    )
  end

  # site_admin is platform-level (no tenant); the tenant personas require a tenant.
  defp validate_tenant_for_persona(changeset) do
    persona = get_field(changeset, :persona)
    tenant_id = get_field(changeset, :tenant_id)

    cond do
      persona == :site_admin and not is_nil(tenant_id) ->
        add_error(changeset, :tenant_id, "must be empty for the site_admin persona")

      persona in [:agency_admin, :salesperson] and is_nil(tenant_id) ->
        add_error(changeset, :tenant_id, "is required for tenant personas")

      true ->
        changeset
    end
  end
end
