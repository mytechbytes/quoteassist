defmodule QuoteAssist.Audit.Log do
  @moduledoc """
  An append-only audit record. Written for every privileged action and status
  transition from R2 onward. The actor is polymorphic (`admin | user | system`) and
  `tenant_id` is null for platform-level actions, so neither is a foreign key.

  Append-only by design: `inserted_at` only (no `updated_at`), and the
  `QuoteAssist.Audit` context exposes no update or delete. Never store full message
  bodies — references + masked values only.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @actor_types [:admin, :user, :system]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "audit_logs" do
    field :actor_type, Ecto.Enum, values: @actor_types
    field :actor_id, :binary_id
    field :tenant_id, :binary_id
    field :action, :string
    field :target_type, :string
    field :target_id, :string
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "All valid actor types."
  def actor_types, do: @actor_types

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :actor_type,
      :actor_id,
      :tenant_id,
      :action,
      :target_type,
      :target_id,
      :metadata
    ])
    |> validate_required([:actor_type, :action])
  end
end
