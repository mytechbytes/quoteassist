defmodule QuoteAssist.Accounts.AdminToken do
  @moduledoc """
  Admin session tokens. Mirrors `UserToken` but is session-only — admins log in with
  a password (no magic-link, no remember-me), so there are no email tokens here.
  Tokens are stored in the DB so a session can be revoked at logout and expires
  independently of the signed cookie.
  """
  use Ecto.Schema
  import Ecto.Query

  alias QuoteAssist.Accounts.AdminToken

  @rand_size 32
  @session_validity_in_days 14

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "admins_tokens" do
    field :token, :binary
    field :context, :string
    field :authenticated_at, :utc_datetime
    belongs_to :admin, QuoteAssist.Accounts.Admin

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Builds an opaque session token + its row for the given admin."
  def build_session_token(admin) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = DateTime.utc_now(:second)

    {token,
     %AdminToken{token: token, context: "session", admin_id: admin.id, authenticated_at: dt}}
  end

  @doc """
  Query that returns the admin for a valid, unexpired session token. Soft-deleted
  admins never authenticate.
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: admin in assoc(token, :admin),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        where: is_nil(admin.deleted_at),
        select: admin

    {:ok, query}
  end

  defp by_token_and_context_query(token, context) do
    from AdminToken, where: [token: ^token, context: ^context]
  end
end
