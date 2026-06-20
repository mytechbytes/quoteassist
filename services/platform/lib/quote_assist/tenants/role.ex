defmodule QuoteAssist.Tenants.Role do
  @moduledoc """
  A tenant-scoped role: a named bundle of permission keys drawn from the code-owned
  catalog (`QuoteAssist.Authz.Permissions`). Each tenant gets its own set seeded at
  creation (see `QuoteAssist.Tenants.seed_default_roles/1`); R7-rbac builds the UI to
  compose them. The catalog is never invented in the DB — `permissions` are
  validated against it here.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Authz.Permissions
  alias QuoteAssist.Tenants.{Membership, Tenant}

  @slug_format ~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "roles" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :permissions, {:array, :string}, default: []
    field :builtin, :boolean, default: false
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    has_many :memberships, Membership

    timestamps(type: :utc_datetime)
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :slug, :description, :permissions, :builtin, :tenant_id])
    |> validate_required([:name, :slug, :tenant_id])
    |> update_change(:slug, fn slug -> slug |> String.trim() |> String.downcase() end)
    |> validate_length(:name, max: 80)
    |> validate_format(:slug, @slug_format)
    |> validate_permissions()
    |> assoc_constraint(:tenant)
    |> unique_constraint(:slug, name: :roles_tenant_slug_live_index)
  end

  # Rejects any permission key not in the code-owned catalog.
  defp validate_permissions(changeset) do
    validate_change(changeset, :permissions, fn :permissions, permissions ->
      case Enum.reject(permissions, &Permissions.valid?/1) do
        [] -> []
        unknown -> [permissions: "unknown permission(s): #{Enum.join(unknown, ", ")}"]
      end
    end)
  end
end
