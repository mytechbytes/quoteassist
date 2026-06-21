defmodule QuoteAssist.Quotes do
  @moduledoc """
  Quote requests (leads) and their reply thread — the tenant-scoped lead-to-quote flow
  (RELEASE_PLAN.md R11-quotes + R12-quote-reply).

  Every query goes through `QuoteAssist.Tenancy.scope/2`, so a quote request is only ever
  visible to its own tenant; every mutation runs as the signed-in member and writes an
  audit row (`actor_subtype: owner | member`). Status moves through the
  `QuoteRequest` state machine (`open → in_progress → quoted → closed`); replies are
  appended messages (`human` or `ai`) and sending one advances the lead to `quoted`.
  """
  import Ecto.Query

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.AIService
  alias QuoteAssist.Audit
  alias QuoteAssist.Quotes.{QuoteMessage, QuoteRequest}
  alias QuoteAssist.Repo
  alias QuoteAssist.Tenancy

  # ── Quote requests (R11-quotes) ─────────────────────────────────────────────────

  @doc """
  Live quote requests for the scope's tenant, newest first. `opts`:

    * `:status` — an atom status (or `:all`/`nil`) to filter by;
    * `:query`  — a search string matched against subject / customer name / email.
  """
  def list_quote_requests(%Scope{} = scope, opts \\ []) do
    QuoteRequest
    |> Tenancy.scope(scope)
    |> filter_status(opts[:status])
    |> filter_search(opts[:query])
    |> order_by([q], desc: q.inserted_at, desc: q.id)
    |> preload(submitted_by_membership: :user)
    |> Repo.all()
  end

  defp filter_status(query, status) when status in [nil, :all], do: query

  defp filter_status(query, status) when is_atom(status),
    do: where(query, [q], q.status == ^status)

  defp filter_search(query, nil), do: query

  defp filter_search(query, search) do
    case String.trim(search) do
      "" ->
        query

      term ->
        like = "%#{term}%"

        where(
          query,
          [q],
          ilike(q.subject, ^like) or ilike(q.customer_name, ^like) or
            ilike(q.customer_email, ^like)
        )
    end
  end

  @doc "A live quote request in the scope's tenant by id (submitter preloaded), or nil."
  def get_quote_request(%Scope{} = scope, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        QuoteRequest
        |> Tenancy.scope(scope)
        |> where([q], q.id == ^uuid)
        |> preload(submitted_by_membership: :user)
        |> Repo.one()

      :error ->
        nil
    end
  end

  @doc "Changeset backing the create / edit form (seeded with the scope's tenant)."
  def change_quote_request(
        %Scope{} = scope,
        %QuoteRequest{} = quote_request \\ %QuoteRequest{},
        attrs \\ %{}
      ) do
    QuoteRequest.changeset(%{quote_request | tenant_id: scope.tenant.id}, attrs)
  end

  @doc "Creates a quote request (`quote:create`), stamped with the actor's membership. Audited."
  def create_quote_request(%Scope{} = scope, attrs) do
    changeset =
      %QuoteRequest{tenant_id: scope.tenant.id, submitted_by: scope.membership.id}
      |> QuoteRequest.changeset(attrs)

    Repo.transact(fn ->
      with {:ok, quote_request} <- Repo.insert(changeset) do
        audit(scope, "quote.created", quote_request.id, %{"subject" => quote_request.subject})
        {:ok, quote_request}
      end
    end)
  end

  @doc "Edits a quote request's customer details / body (`quote:update`). Audited."
  def update_quote_request(%Scope{} = scope, %QuoteRequest{} = quote_request, attrs) do
    Repo.transact(fn ->
      with {:ok, updated} <- quote_request |> QuoteRequest.changeset(attrs) |> Repo.update() do
        audit(scope, "quote.updated", updated.id, %{"subject" => updated.subject})
        {:ok, updated}
      end
    end)
  end

  @doc """
  Applies a guarded status transition (`quote:status`) and audits it, atomically. An
  illegal jump comes back as `{:error, changeset}` and never persists.
  """
  def transition_status(%Scope{} = scope, %QuoteRequest{} = quote_request, new_status) do
    Repo.transact(fn ->
      with {:ok, updated} <-
             quote_request |> QuoteRequest.status_changeset(new_status) |> Repo.update() do
        audit(scope, "quote.status_changed", updated.id, %{
          "from" => to_string(quote_request.status),
          "to" => to_string(new_status)
        })

        {:ok, updated}
      end
    end)
  end

  @doc "Soft-deletes a quote request (`quote:delete`). Audited."
  def soft_delete_quote_request(%Scope{} = scope, %QuoteRequest{} = quote_request) do
    Repo.transact(fn ->
      changeset = Ecto.Changeset.change(quote_request, deleted_at: DateTime.utc_now(:second))

      with {:ok, deleted} <- Repo.update(changeset) do
        audit(scope, "quote.deleted", deleted.id, %{"subject" => deleted.subject})
        {:ok, deleted}
      end
    end)
  end

  @doc """
  Dashboard counts (R8) for the scope's tenant: open leads and leads quoted this calendar
  month. Reads only — wired here once the table exists (R11).
  """
  def dashboard_stats(%Scope{} = scope) do
    base = Tenancy.scope(QuoteRequest, scope)
    month_start = month_start()

    %{
      open: Repo.aggregate(where(base, [q], q.status == :open), :count, :id),
      quoted_this_month:
        Repo.aggregate(
          where(base, [q], q.status == :quoted and q.updated_at >= ^month_start),
          :count,
          :id
        )
    }
  end

  defp month_start do
    %{DateTime.utc_now() | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  # ── Reply thread + AI hook (R12-quote-reply) ────────────────────────────────────

  @doc "Messages on a quote request, oldest first (the reply thread)."
  def list_messages(%Scope{} = scope, %QuoteRequest{id: quote_request_id}) do
    QuoteMessage
    |> Tenancy.scope(scope)
    |> where([m], m.quote_request_id == ^quote_request_id)
    |> order_by([m], asc: m.inserted_at, asc: m.id)
    |> preload(author_membership: :user)
    |> Repo.all()
  end

  @doc """
  Generates a draft reply via the AI service (`quote:ai_generate`). A stub today
  (`AIService.generate_reply/1`); when the real Python service lands, only that function
  changes. Returns the draft **string** for review in the composer — it does **not** send
  (human-in-the-loop, no auto-send ever). The generation is audited.
  """
  def generate_ai_reply(%Scope{} = scope, %QuoteRequest{} = quote_request) do
    draft = AIService.generate_reply(quote_request)
    audit(scope, "quote.ai_generated", quote_request.id, %{})
    {:ok, draft}
  end

  @doc """
  Sends a human reply (`quote:reply`): appends a `human` message and advances the lead to
  `quoted` (via the state machine, if reachable), atomically and audited. Returns
  `{:ok, message}` or `{:error, changeset}`.
  """
  def send_reply(%Scope{} = scope, %QuoteRequest{} = quote_request, body) do
    Repo.transact(fn ->
      with {:ok, message} <- insert_message(scope, quote_request, :human, body) do
        maybe_mark_quoted(scope, quote_request)
        audit(scope, "quote.replied", quote_request.id, %{})
        {:ok, message}
      end
    end)
  end

  defp insert_message(scope, quote_request, author_type, body) do
    %QuoteMessage{
      tenant_id: scope.tenant.id,
      quote_request_id: quote_request.id,
      author_id: scope.membership.id
    }
    |> QuoteMessage.changeset(%{author_type: author_type, body: body})
    |> Repo.insert()
  end

  # Move the lead to `quoted` when sending a reply, if that's a legal transition from its
  # current status (it is from open / in_progress). Already-quoted / closed leads are left
  # as-is — sending another reply shouldn't reopen or error.
  defp maybe_mark_quoted(scope, quote_request) do
    if QuoteRequest.can_transition?(quote_request.status, :quoted) do
      transition_status(scope, quote_request, :quoted)
    end
  end

  # ── Audit ──────────────────────────────────────────────────────────────────────

  defp audit(scope, action, target_id, metadata) do
    Audit.log(%{
      actor_type: :user,
      actor_subtype: scope.membership.type,
      actor_id: scope.user.id,
      tenant_id: scope.tenant.id,
      action: action,
      target_type: "quote_request",
      target_id: to_string(target_id),
      metadata: metadata
    })
  end
end
