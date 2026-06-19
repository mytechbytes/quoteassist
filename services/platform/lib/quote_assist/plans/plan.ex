defmodule QuoteAssist.Plans.Plan do
  @moduledoc """
  A subscription plan — platform-level (no `tenant_id`); a tenant references one via
  `tenant.plan_id`. Three are seeded (Starter / Growth / Scale) in
  `priv/repo/seeds.exs`.

  Plans are not bare labels: each carries `price` (smallest currency unit — paise;
  0 = free), a billing `interval`, an `active` flag (offerable to new tenants), and a
  `limits` map (RELEASE_PLAN.md, "Plans are DB-backed with feature limits"):

    * `quotes_per_month`          — quote requests creatable per calendar month
    * `seats`                     — max active memberships per tenant
    * `ai_generations_per_month`  — "Generate with AI" calls per month
    * `custom_domain`             — whether the tenant may add a custom domain

  Limits are read from the plan, never copied onto the tenant. *Enforcing* them is a
  later concern; modelling them now means no migration when enforcement lands.
  Soft-deleted via `deleted_at`; the slug is unique among live rows.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @slug_format ~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/
  @intervals [:monthly, :yearly]

  # Known limit dimensions. `custom_domain` is boolean; the rest are non-negative ints.
  @int_limit_keys ~w(quotes_per_month seats ai_generations_per_month)
  @bool_limit_keys ~w(custom_domain)
  @limit_keys @int_limit_keys ++ @bool_limit_keys

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "plans" do
    field :name, :string
    field :slug, :string
    field :price, :integer, default: 0
    field :interval, Ecto.Enum, values: @intervals, default: :monthly
    field :limits, :map, default: %{}
    field :active, :boolean, default: true
    field :deleted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "All valid billing intervals."
  def intervals, do: @intervals

  @doc "The known limit keys."
  def limit_keys, do: @limit_keys

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:name, :slug, :price, :interval, :active, :limits])
    |> validate_required([:name, :slug])
    |> update_change(:slug, fn slug -> slug |> String.trim() |> String.downcase() end)
    |> validate_length(:name, max: 80)
    |> validate_format(:slug, @slug_format,
      message: "must be lowercase letters, numbers, and hyphens"
    )
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> normalize_limits()
    |> unique_constraint(:slug, name: :plans_slug_live_index)
  end

  @doc "Changeset for editing a plan. Slug is immutable once created (it's the key)."
  def update_changeset(plan, attrs) do
    plan
    |> cast(attrs, [:name, :price, :interval, :active, :limits])
    |> validate_required([:name])
    |> validate_length(:name, max: 80)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> normalize_limits()
  end

  # Coerce the limits map to known keys with typed values (form params arrive as
  # strings; jsonb stores string keys), dropping anything unrecognised.
  defp normalize_limits(changeset) do
    case fetch_change(changeset, :limits) do
      {:ok, limits} when is_map(limits) -> put_change(changeset, :limits, clean_limits(limits))
      _ -> changeset
    end
  end

  defp clean_limits(limits) do
    for {key, value} <- limits, to_string(key) in @limit_keys, into: %{} do
      {to_string(key), coerce_limit(to_string(key), value)}
    end
  end

  defp coerce_limit(key, value) when key in @bool_limit_keys, do: truthy?(value)
  defp coerce_limit(_key, value), do: to_non_neg_int(value)

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false

  defp to_non_neg_int(value) when is_integer(value) and value >= 0, do: value

  defp to_non_neg_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} when int >= 0 -> int
      _ -> 0
    end
  end

  defp to_non_neg_int(_), do: 0
end
