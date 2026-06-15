defmodule QuoteAssist.Tenancy.Tenant do
  @moduledoc """
  A tenant (agency) — the isolation boundary every tenant-owned row hangs off.

  R2 keeps this minimal (name, slug, status); the vertical and plan associations
  arrive with R3/R5.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(active trial suspended)a
  def statuses, do: @statuses

  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :status, Ecto.Enum, values: @statuses, default: :active

    timestamps(type: :utc_datetime)
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :status])
    |> validate_required([:name, :slug])
    |> update_change(:slug, &String.downcase/1)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "only lowercase letters, numbers and dashes"
    )
    |> validate_length(:slug, min: 2, max: 60)
    |> unique_constraint(:slug)
  end
end
