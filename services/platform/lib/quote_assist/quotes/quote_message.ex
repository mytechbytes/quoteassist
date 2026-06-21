defmodule QuoteAssist.Quotes.QuoteMessage do
  @moduledoc """
  One message in a quote request's reply thread (RELEASE_PLAN.md, R12-quote-reply).
  `author_type` is `:human` (a member's reply) or `:ai` (a draft the AI service produced
  and the member sent — human-in-the-loop, nothing auto-sends). Tenant-scoped and
  soft-delete-aware so it flows through `QuoteAssist.Tenancy.scope/2` like every other
  tenant-owned row. Append-only in practice — messages aren't edited.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias QuoteAssist.Quotes.QuoteRequest
  alias QuoteAssist.Tenants.{Membership, Tenant}

  @author_types [:human, :ai]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "quote_messages" do
    field :author_type, Ecto.Enum, values: @author_types
    field :body, :string
    field :deleted_at, :utc_datetime

    belongs_to :tenant, Tenant
    belongs_to :quote_request, QuoteRequest
    belongs_to :author_membership, Membership, foreign_key: :author_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "All valid author types."
  def author_types, do: @author_types

  @doc """
  Changeset for appending a message. `tenant_id`, `quote_request_id`, and `author_id` are
  carried on the struct by the context (from the actor's scope), never cast from input.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:author_type, :body])
    |> validate_required([:author_type, :body, :tenant_id, :quote_request_id])
    |> validate_length(:body, min: 1, max: 10_000)
    |> assoc_constraint(:tenant)
    |> assoc_constraint(:quote_request)
  end
end
