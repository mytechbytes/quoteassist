defmodule QuoteAssist.Quotes.QuoteRequest do
  @moduledoc """
  A quote request — an inbound **lead** (RELEASE_PLAN.md, R11-quotes). Captured by a
  tenant user now; the reply (manual, then AI) is the quote (R12). Tenant-scoped and
  soft-deleted like every tenant-owned row.

  `status` is a state machine (`open → in_progress → quoted → closed`) guarded by
  `can_transition?/2`; illegal jumps are rejected at the changeset and unreachable from
  the UI. Every applied transition writes an audit row — see
  `QuoteAssist.Quotes.transition_status/3`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Tenants.{Membership, Tenant}

  @statuses [:open, :in_progress, :quoted, :closed]

  # Workflow: `open` (to-do) → `in_progress` (start) → `quoted` → `closed`. A lead can
  # always be closed, and steps can be walked back — but `open` is reachable **only from
  # `in_progress`**: you can't jump a `quoted`/`closed` lead straight back to to-do, you
  # first move it to `in_progress`, then to `open` if needed. So `closed` reopens to
  # `in_progress`, never to `open`. Sending a reply advances an active lead to `quoted`
  # (R12); close / reopen are the manual lifecycle controls (R11).
  @transitions %{
    open: [:in_progress, :quoted, :closed],
    in_progress: [:open, :quoted, :closed],
    quoted: [:in_progress, :closed],
    closed: [:in_progress]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "quote_requests" do
    field :customer_name, :string
    field :customer_email, :string
    field :subject, :string
    field :body, :string
    field :status, Ecto.Enum, values: @statuses, default: :open
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    belongs_to :submitted_by_membership, Membership, foreign_key: :submitted_by

    timestamps(type: :utc_datetime)
  end

  @doc "All valid quote-request statuses."
  def statuses, do: @statuses

  @doc "Whether `to` is a legal next status from `from`."
  def can_transition?(from, to) when is_atom(from) and is_atom(to) do
    to in Map.get(@transitions, from, [])
  end

  @doc "Human label for a status."
  def status_label(:in_progress), do: "In progress"
  def status_label(status), do: status |> to_string() |> String.capitalize()

  @doc """
  Changeset for creating / editing a quote request. `tenant_id` and `submitted_by` are
  carried on the struct by the context (from the actor's scope, never cast), so a crafted
  form can't write to another tenant. `status` is advanced only via `status_changeset/2`.
  """
  def changeset(quote_request, attrs) do
    quote_request
    |> cast(attrs, [:customer_name, :customer_email, :subject, :body])
    |> validate_required([:customer_name, :customer_email, :subject, :body, :tenant_id])
    |> validate_length(:customer_name, max: 160)
    |> validate_length(:subject, max: 200)
    |> validate_length(:body, max: 10_000)
    |> validate_format(:customer_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:customer_email, max: 160)
    |> assoc_constraint(:tenant)
  end

  @doc """
  Applies a guarded status transition. Adds an error when `new_status` isn't reachable
  from the current status, so illegal jumps never persist.
  """
  def status_changeset(%__MODULE__{status: from} = quote_request, new_status)
      when is_atom(new_status) do
    changeset = change(quote_request)

    if can_transition?(from, new_status) do
      put_change(changeset, :status, new_status)
    else
      add_error(changeset, :status, "cannot transition from #{from} to #{new_status}")
    end
  end
end
