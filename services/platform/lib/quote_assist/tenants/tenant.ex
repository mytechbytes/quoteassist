defmodule QuoteAssist.Tenants.Tenant do
  @moduledoc """
  An organisation's isolated workspace. Reached on its own subdomain
  (`<slug>.quoteassist.mytechbytes.in`) and, optionally, a verified custom domain.

  `status` is a state machine (`trial → active → suspended → cancelled`) guarded by
  `can_transition?/2`; illegal jumps are rejected at the changeset and unreachable
  from the UI. Every applied transition writes an audit row — see
  `QuoteAssist.Tenants.transition_status/3`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Tenants.{Membership, Role}

  @statuses [:trial, :active, :suspended, :cancelled]
  @custom_domain_statuses [:none, :pending, :verified]

  # Allowed status transitions. `suspended → active` is the reactivate path (R3);
  # `cancelled` is terminal.
  @transitions %{
    trial: [:active, :suspended, :cancelled],
    active: [:suspended, :cancelled],
    suspended: [:active, :cancelled],
    cancelled: []
  }

  # Statuses that resolve to a live workspace. Suspended / cancelled tenants 404 at
  # the resolver (RELEASE_PLAN.md).
  @resolvable_statuses [:trial, :active]

  # Reserved slugs that would collide with platform hosts / routes.
  @reserved_slugs ~w(www admin api app dev mail)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tenants" do
    field :name, :string
    field :slug, :string
    field :status, Ecto.Enum, values: @statuses, default: :trial
    field :custom_domain, :string
    field :custom_domain_status, Ecto.Enum, values: @custom_domain_statuses, default: :none
    field :custom_domain_token, :string
    field :deleted_at, :utc_datetime

    has_many :memberships, Membership
    has_many :roles, Role

    timestamps(type: :utc_datetime)
  end

  @doc "All valid tenant statuses."
  def statuses, do: @statuses

  @doc "Statuses that resolve to a live workspace (others 404 at the resolver)."
  def resolvable_statuses, do: @resolvable_statuses

  @doc "Whether `to` is a legal next status from `from`."
  def can_transition?(from, to) when is_atom(from) and is_atom(to) do
    to in Map.get(@transitions, from, [])
  end

  # RFC-1123-ish label: lowercase alphanumerics and hyphens, no leading/trailing hyphen.
  @slug_format ~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/

  @doc """
  Changeset for creating / editing core tenant fields. Two fields are deliberately
  *not* settable here, so neither can be forged by a future HTTP caller:

    * `status` — advanced only via `status_changeset/2` (guarded transitions);
    * `custom_domain_status` / `custom_domain_token` — advanced only by the R-CD
      verification flow after a real DNS check. A tenant may store a `custom_domain`
      string, but it stays unverified (and so unresolvable) until that flow runs.
  """
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :slug, :custom_domain])
    |> validate_required([:name, :slug])
    |> update_change(:slug, &normalize_host_part/1)
    |> update_change(:custom_domain, &normalize_host_part/1)
    |> validate_length(:name, max: 160)
    |> validate_length(:slug, min: 2, max: 63)
    |> validate_format(:slug, @slug_format,
      message: "must be lowercase letters, numbers, and hyphens"
    )
    |> validate_exclusion(:slug, @reserved_slugs, message: "is reserved")
    |> unique_constraint(:slug, name: :tenants_slug_live_index)
    |> unique_constraint(:custom_domain, name: :tenants_custom_domain_live_index)
  end

  @doc """
  Applies a guarded status transition. Adds an error when `new_status` is not
  reachable from the current status, so illegal jumps never persist.
  """
  def status_changeset(%__MODULE__{status: from} = tenant, new_status) when is_atom(new_status) do
    changeset = change(tenant)

    if can_transition?(from, new_status) do
      put_change(changeset, :status, new_status)
    else
      add_error(changeset, :status, "cannot transition from #{from} to #{new_status}")
    end
  end

  defp normalize_host_part(nil), do: nil

  defp normalize_host_part(value) do
    case value |> String.trim() |> String.downcase() do
      "" -> nil
      normalized -> normalized
    end
  end
end
