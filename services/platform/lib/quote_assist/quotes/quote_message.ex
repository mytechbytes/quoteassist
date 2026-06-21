defmodule QuoteAssist.Quotes.QuoteMessage do
  @moduledoc """
  One message in a quote's thread (RELEASE_PLAN.md, R12 — extended). Each row carries
  three independent facets:

  ## Status — the human-in-the-loop gate

      OUTBOUND:  draft ──▶ confirmed ──▶ sent        INBOUND:  received
                   ▲          │
                   └──────────┘  (agent edits → back to draft)

  No message reaches `sent` without a human `sent_by` — the gate is structural, not a UI
  convention.

  ## Provenance — "AI or agent?"

    * `author_type`     — `:ai | :human | :client` (who produced the content)
    * `authored_by`     — membership id of the human author (null for ai/client)
    * `sent_by`         — membership id of the human who confirmed & sent (null until sent)
    * `edited_by_human` — was an AI draft touched before sending

  `:ai` + `sent_by: nil` = an AI draft waiting; `:ai` + `sent_by: <agent>` = an AI draft a
  human approved. A future auto-send actor slots into `sent_by` with no schema change.

  ## Disposition — what a client reply means

  On a `received` message: `:question | :change_request | :acceptance | :rejection |
  :other`. `:acceptance`/`:rejection` resolve the quote; `:question`/`:change_request`
  keep it `quoted` and loop a fresh `draft → confirmed → sent`.

  Tenant-scoped + soft-delete-aware so it flows through `QuoteAssist.Tenancy.scope/2`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Quotes.QuoteRequest
  alias QuoteAssist.Tenants.{Membership, Tenant}

  @author_types [:ai, :human, :client]
  @statuses [:draft, :confirmed, :sent, :received]
  @dispositions [:question, :change_request, :acceptance, :rejection, :other]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "quote_messages" do
    field :author_type, Ecto.Enum, values: @author_types
    field :status, Ecto.Enum, values: @statuses, default: :draft
    field :disposition, Ecto.Enum, values: @dispositions
    field :body, :string
    field :edited_by_human, :boolean, default: false
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    belongs_to :quote_request, QuoteRequest
    belongs_to :authored_by_membership, Membership, foreign_key: :authored_by
    belongs_to :sent_by_membership, Membership, foreign_key: :sent_by

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "All valid author types / statuses / dispositions."
  def author_types, do: @author_types
  def statuses, do: @statuses
  def dispositions, do: @dispositions

  @doc "Whether `to` is a legal next message status from `from` (outbound gate)."
  def can_transition?(:draft, :confirmed), do: true
  def can_transition?(:draft, :sent), do: true
  def can_transition?(:confirmed, :sent), do: true
  def can_transition?(:confirmed, :draft), do: true
  def can_transition?(_from, _to), do: false

  @doc "Human label for a message status."
  def status_label(status), do: status |> to_string() |> String.capitalize()

  @doc "Human label for a disposition."
  def disposition_label(:change_request), do: "Change request"
  def disposition_label(disposition), do: disposition |> to_string() |> String.capitalize()

  @doc """
  Changeset for appending a message. `tenant_id`, `quote_request_id`, `author_type`, and
  the provenance ids are carried on the struct by the context (from the actor's scope),
  never cast from input — only the editable `body` (+ `disposition` for inbound) is cast.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :disposition])
    |> validate_required([:author_type, :status, :body, :tenant_id, :quote_request_id])
    |> validate_length(:body, min: 1, max: 10_000)
    |> assoc_constraint(:tenant)
    |> assoc_constraint(:quote_request)
  end

  @doc "Changeset to edit a draft's body (marks it human-edited)."
  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 10_000)
    |> put_change(:status, :draft)
    |> put_change(:edited_by_human, true)
  end
end
