defmodule QuoteAssist.Tenants.Request do
  @moduledoc """
  A tenant request — the generic member→owner ask inbox (RELEASE_PLAN.md, R7-rbac).
  `:leave` is the first type; the schema is built to carry other types (access,
  plan_change, support, …) without a new table each time.

  `status` is a small state machine (`open → approved | declined | cancelled`) guarded
  by `can_transition?/2`; the requester may `cancel` their own open request, and only a
  `request:manage` holder may `approve`/`decline`. Every transition is audited
  (`QuoteAssist.Requests`). Membership-scoped, never identity-scoped: `requested_by`
  and `resolved_by` are **membership** ids (this tenant only), not global users.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Tenants.{Membership, Tenant}

  @types [:leave]
  @statuses [:open, :approved, :declined, :cancelled]

  # `open` is the only non-terminal state; approve / decline / cancel are all final.
  @transitions %{
    open: [:approved, :declined, :cancelled],
    approved: [],
    declined: [],
    cancelled: []
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "requests" do
    field :type, Ecto.Enum, values: @types
    field :status, Ecto.Enum, values: @statuses, default: :open
    field :note, :string
    field :resolution, :string
    field :resolved_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    belongs_to :requested_by_membership, Membership, foreign_key: :requested_by
    belongs_to :resolved_by_membership, Membership, foreign_key: :resolved_by

    timestamps(type: :utc_datetime)
  end

  @doc "All valid request types."
  def types, do: @types

  @doc "All valid request statuses."
  def statuses, do: @statuses

  @doc "Whether `to` is a legal next status from `from`."
  def can_transition?(from, to) when is_atom(from) and is_atom(to) do
    to in Map.get(@transitions, from, [])
  end

  @doc "Human label for a request type."
  def type_label(:leave), do: "Leave workspace"
  def type_label(type), do: type |> to_string() |> String.capitalize()

  @doc "Human label for a request status."
  def status_label(status), do: status |> to_string() |> String.capitalize()

  @doc """
  Changeset for raising a request. `tenant_id` and `requested_by` are carried on the
  struct by the context (set from the actor's scope, never cast from the form), so a
  crafted form can't raise a request for another tenant or member. `status` is forced
  to `:open`.
  """
  def create_changeset(request, attrs) do
    request
    |> cast(attrs, [:type, :note])
    |> put_change(:status, :open)
    |> validate_required([:type, :tenant_id, :requested_by])
    |> validate_length(:note, max: 1000)
    |> assoc_constraint(:tenant)
    |> assoc_constraint(:requested_by_membership)
    |> unique_constraint(:type,
      name: :requests_open_per_type_index,
      message: "you already have an open request of this type"
    )
  end

  @doc """
  Changeset applying a guarded status transition with a resolution note. Rejects an
  illegal jump at the changeset (so a resolved request can't be re-resolved), and
  stamps `resolved_at`. `resolved_by` is set by the context (the resolver's
  membership).
  """
  def resolve_changeset(%__MODULE__{status: from} = request, new_status, attrs)
      when is_atom(new_status) do
    changeset =
      request
      |> cast(attrs, [:resolution])
      |> validate_length(:resolution, max: 1000)

    if can_transition?(from, new_status) do
      changeset
      |> put_change(:status, new_status)
      |> put_change(:resolved_at, DateTime.utc_now(:second))
    else
      add_error(changeset, :status, "cannot transition from #{from} to #{new_status}")
    end
  end
end
