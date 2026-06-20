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
  import Ecto.Query

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

  @doc "Recent audit rows for a tenant, newest first (for the tenant detail timeline)."
  def list_for_tenant(tenant_id, limit \\ 50) do
    Repo.all(
      from l in Log,
        where: l.tenant_id == ^tenant_id,
        order_by: [desc: l.inserted_at, desc: l.id],
        limit: ^limit
    )
  end

  @doc "Recent audit rows across the whole platform, newest first (the activity view)."
  def list_recent(limit \\ 50) do
    Repo.all(from l in Log, order_by: [desc: l.inserted_at, desc: l.id], limit: ^limit)
  end

  @doc """
  Recent audit rows about a specific target resource, newest first — the activity feed on
  a resource's detail page. Keyed on `target_type` + `target_id` (ids are UUIDs, globally
  unique, so this is safe across tenants).
  """
  def list_for_target(target_type, target_id, limit \\ 50) when is_binary(target_type) do
    target_id = to_string(target_id)

    Repo.all(
      from l in Log,
        where: l.target_type == ^target_type and l.target_id == ^target_id,
        order_by: [desc: l.inserted_at, desc: l.id],
        limit: ^limit
    )
  end

  @doc "Recent audit rows for a specific admin actor, newest first (the admin detail page)."
  def list_for_admin(admin_id, limit \\ 50) do
    Repo.all(
      from l in Log,
        where: l.actor_type == :admin and l.actor_id == ^admin_id,
        order_by: [desc: l.inserted_at, desc: l.id],
        limit: ^limit
    )
  end
end
