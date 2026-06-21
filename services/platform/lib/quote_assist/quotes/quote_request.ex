defmodule QuoteAssist.Quotes.QuoteRequest do
  @moduledoc """
  A quote request — an inbound **lead**, and the quote prepared against it
  (RELEASE_PLAN.md, R11/R12). Tenant-scoped and soft-deleted.

  ## Status — the lead's stage (one state machine)

      new ──▶ in_progress ──▶ quoted ──┬─▶ accepted   (terminal · won)
                                ▲       ├─▶ rejected   (terminal · lost)
                                │       └─▶ expired    (validity lapsed)
                       (negotiation loops in the message thread)
      any active ──▶ cancelled                          (terminal · withdrawn)

  The whole back-and-forth stays inside `quoted` — revisions are new messages in the
  thread, not status churn — so won/lost/conversion stays computable from the terminal
  states. Guarded by `can_transition?/2`; illegal jumps are rejected at the changeset.

  ## Supporting signals (not statuses)

    * `valid_until` — date the sent quote lapses (set when the first quote is sent); a
      background sweep flips `quoted → expired` once it passes.
    * `awaiting` — derived ball-in-court flag (`:us | :client`): sending sets `:client`,
      a client reply sets `:us`. Drives the "needs response" list.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Tenants.{Membership, Tenant}

  @statuses [:new, :in_progress, :quoted, :accepted, :rejected, :expired, :cancelled]
  @active_statuses [:new, :in_progress, :quoted]
  @awaiting [:us, :client]

  # `cancelled` is reachable from any active state (withdrawn). Terminal outcomes
  # (accepted/rejected/expired/cancelled) don't transition out — the thread, not the
  # status, carries the negotiation loop while `quoted`.
  @transitions %{
    new: [:in_progress, :quoted, :cancelled],
    in_progress: [:quoted, :cancelled],
    quoted: [:accepted, :rejected, :expired, :cancelled],
    accepted: [],
    rejected: [],
    expired: [],
    cancelled: []
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "quote_requests" do
    field :reference, :string
    field :customer_name, :string
    field :customer_email, :string
    field :subject, :string
    field :body, :string
    field :route, :string
    field :travel_dates, :string
    field :pax, :string
    field :total, :integer
    field :currency, :string, default: "GBP"
    field :status, Ecto.Enum, values: @statuses, default: :new
    field :awaiting, Ecto.Enum, values: @awaiting
    field :valid_until, :date
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    belongs_to :submitted_by_membership, Membership, foreign_key: :submitted_by

    timestamps(type: :utc_datetime)
  end

  @doc "All valid statuses."
  def statuses, do: @statuses

  @doc "The active (non-terminal) statuses."
  def active_statuses, do: @active_statuses

  @doc "Whether a status is terminal (a won/lost/lapsed/withdrawn outcome)."
  def terminal?(status), do: status not in @active_statuses

  @doc "Whether `to` is a legal next status from `from`."
  def can_transition?(from, to) when is_atom(from) and is_atom(to) do
    to in Map.get(@transitions, from, [])
  end

  @doc "Human label for a status."
  def status_label(:new), do: "New"
  def status_label(:in_progress), do: "In progress"
  def status_label(status), do: status |> to_string() |> String.capitalize()

  @doc "Human label for the awaiting flag."
  def awaiting_label(:us), do: "Awaiting us"
  def awaiting_label(:client), do: "Awaiting client"
  def awaiting_label(_), do: nil

  @doc """
  Changeset for creating / editing a quote request. `tenant_id`, `submitted_by`, and
  `reference` are carried on the struct by the context (never cast), so a crafted form
  can't write to another tenant or forge a reference. `status`, `awaiting`, and
  `valid_until` advance only through the context's guarded paths.
  """
  def changeset(quote_request, attrs) do
    quote_request
    |> cast(attrs, [
      :customer_name,
      :customer_email,
      :subject,
      :body,
      :route,
      :travel_dates,
      :pax,
      :total,
      :currency
    ])
    |> validate_required([:customer_name, :customer_email, :subject, :body, :tenant_id])
    |> validate_length(:customer_name, max: 160)
    |> validate_length(:subject, max: 200)
    |> validate_length(:body, max: 10_000)
    |> validate_length(:route, max: 120)
    |> validate_length(:travel_dates, max: 120)
    |> validate_length(:pax, max: 60)
    |> validate_number(:total, greater_than_or_equal_to: 0)
    |> validate_format(:customer_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:customer_email, max: 160)
    |> assoc_constraint(:tenant)
    |> unique_constraint(:reference, name: :quote_requests_tenant_reference_index)
  end

  @doc """
  Applies a guarded status transition, optionally stamping `awaiting` / `valid_until`
  (the context passes these for the send transition). Adds an error when `new_status`
  isn't reachable, so illegal jumps never persist.
  """
  def status_changeset(%__MODULE__{status: from} = quote_request, new_status, extra \\ %{})
      when is_atom(new_status) do
    changeset = change(quote_request, extra)

    if can_transition?(from, new_status) do
      put_change(changeset, :status, new_status)
    else
      add_error(changeset, :status, "cannot transition from #{from} to #{new_status}")
    end
  end

  @doc "Sets the derived `awaiting` flag without touching status."
  def awaiting_changeset(%__MODULE__{} = quote_request, awaiting) when awaiting in @awaiting do
    change(quote_request, awaiting: awaiting)
  end
end
