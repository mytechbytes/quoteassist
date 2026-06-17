defmodule QuoteAssist.Audit do
  @moduledoc """
  Append-only audit log. Use `log/1` (or `log!/1`) for every privileged action and
  status transition from R2 onward. There is intentionally no update or delete.
  Never pass full message bodies in `:metadata` — references + masked values only.

      Audit.log(%{
        actor_type: :user,
        actor_id: user.id,
        tenant_id: tenant.id,
        action: "user.login",
        target_type: "user",
        target_id: user.id,
        metadata: %{"method" => "password"}
      })
  """
  alias QuoteAssist.Audit.Log
  alias QuoteAssist.Repo

  @doc "Inserts an audit row. Returns `{:ok, log}` or `{:error, changeset}`."
  def log(attrs) do
    %Log{} |> Log.changeset(attrs) |> Repo.insert()
  end

  @doc "Like `log/1`, but raises on invalid input."
  def log!(attrs) do
    %Log{} |> Log.changeset(attrs) |> Repo.insert!()
  end
end
