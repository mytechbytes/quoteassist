defmodule QuoteAssist.Accounts.Role do
  @moduledoc """
  A named bundle of **system-defined** permissions (see `QuoteAssist.Policy`).

  `tenant_id` NULL = a platform/system role (e.g. the site-admin role); a non-NULL
  `tenant_id` = a tenant-owned role composed by an owner (R9). Admins compose roles
  from the fixed permission catalog; they cannot invent new permission strings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "roles" do
    field :name, :string
    field :permissions, {:array, :string}, default: []
    belongs_to :tenant, QuoteAssist.Tenancy.Tenant

    timestamps(type: :utc_datetime)
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :permissions, :tenant_id])
    |> validate_required([:name])
    |> validate_subset(:permissions, QuoteAssist.Policy.all_permissions(),
      message: "contains an unknown permission"
    )
    |> unique_constraint([:tenant_id, :name])
  end
end
