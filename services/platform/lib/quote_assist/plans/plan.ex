defmodule QuoteAssist.Plans.Plan do
  @moduledoc """
  A subscription plan. A small platform-level catalog (Starter + Growth seeded in
  `priv/repo/seeds.exs`); a tenant references one via `tenant.plan_id`. Carries the
  attributes the admin UI and future billing read. Soft-deleted via `deleted_at`;
  the slug is unique among live rows.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @slug_format ~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "plans" do
    field :name, :string
    field :slug, :string
    field :monthly_price, :integer, default: 0
    field :seat_limit, :integer, default: 0
    field :deleted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:name, :slug, :monthly_price, :seat_limit])
    |> validate_required([:name, :slug])
    |> update_change(:slug, fn slug -> slug |> String.trim() |> String.downcase() end)
    |> validate_length(:name, max: 80)
    |> validate_format(:slug, @slug_format,
      message: "must be lowercase letters, numbers, and hyphens"
    )
    |> validate_number(:monthly_price, greater_than_or_equal_to: 0)
    |> validate_number(:seat_limit, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug, name: :plans_slug_live_index)
  end

  @doc "Changeset for editing a plan. Slug is immutable once created (it's the key)."
  def update_changeset(plan, attrs) do
    plan
    |> cast(attrs, [:name, :monthly_price, :seat_limit])
    |> validate_required([:name])
    |> validate_length(:name, max: 80)
    |> validate_number(:monthly_price, greater_than_or_equal_to: 0)
    |> validate_number(:seat_limit, greater_than_or_equal_to: 0)
  end
end
