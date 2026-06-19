defmodule QuoteAssist.Accounts.AdminRole do
  @moduledoc """
  A platform admin role: a named bundle of permission keys drawn from the code-owned
  admin catalog (`QuoteAssist.Authz.AdminPermissions`). The admin-side mirror of
  `QuoteAssist.Tenants.Role`, but platform-global — there is no `tenant_id`.

  The protected `super_admin` type carries **no** role (its all-access is computed in
  `QuoteAssist.Authz.AdminPolicy`), so this table only ever holds normal-admin roles;
  there is no "super_admin role" row to hide. Built-ins are seeded
  (`QuoteAssist.Accounts.seed_default_admin_roles/0`) and not deletable in the UI. The
  catalog is never invented in the DB — `permissions` are validated against it here.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Accounts.Admin
  alias QuoteAssist.Authz.AdminPermissions

  @slug_format ~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admin_roles" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :permissions, {:array, :string}, default: []
    field :builtin, :boolean, default: false
    field :deleted_at, :utc_datetime

    has_many :admins, Admin, foreign_key: :role_id

    timestamps(type: :utc_datetime)
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :slug, :description, :permissions, :builtin])
    |> validate_required([:name, :slug])
    |> update_change(:slug, fn slug -> slug |> String.trim() |> String.downcase() end)
    |> validate_length(:name, max: 80)
    |> validate_format(:slug, @slug_format)
    |> validate_permissions()
    |> unique_constraint(:slug, name: :admin_roles_slug_live_index)
  end

  # Rejects any permission key not in the code-owned admin catalog.
  defp validate_permissions(changeset) do
    validate_change(changeset, :permissions, fn :permissions, permissions ->
      case Enum.reject(permissions, &AdminPermissions.valid?/1) do
        [] -> []
        unknown -> [permissions: "unknown permission(s): #{Enum.join(unknown, ", ")}"]
      end
    end)
  end
end
