defmodule QuoteAssist.Quotes do
  @moduledoc """
  Quote requests (leads) and their reply thread — the tenant-scoped lead-to-quote flow
  (RELEASE_PLAN.md R11/R12, extended to the full quote model).

  Two levels interact:

    * the **quote** carries the lead stage (`new → in_progress → quoted →
      accepted|rejected|expired`, + `cancelled`) plus the derived `awaiting` flag and
      `valid_until`;
    * each **message** carries the human-in-the-loop gate (`draft → confirmed → sent` /
      `received`), provenance (ai/human/client + who authored / sent), and a client-reply
      `disposition`.

  The interaction (the loop stays inside `quoted`, no status churn):

    * AI/agent drafts → a `draft` message; quote moves `new → in_progress`.
    * Agent confirms & sends → message `sent`; quote → `quoted`, `awaiting: :client`,
      `valid_until` set on the first send.
    * Client replies → a `received` message tagged with a disposition; `awaiting: :us`;
      `acceptance`/`rejection` resolve the quote, everything else keeps it `quoted`.

  Every query goes through `QuoteAssist.Tenancy.scope/2`; every mutation runs as the
  signed-in member and writes an audit row (`actor_subtype: owner | member`).
  """
  import Ecto.Query

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.AIService
  alias QuoteAssist.Audit
  alias QuoteAssist.Quotes.{QuoteMessage, QuoteRequest}
  alias QuoteAssist.Repo
  alias QuoteAssist.Tenancy

  # Days a sent quote stays valid before the (future) sweep flips it to expired.
  @validity_days 14

  # ── Quote requests ──────────────────────────────────────────────────────────────

  @doc """
  Live quote requests for the scope's tenant, newest first. `opts`:

    * `:status` — an atom status (or `:all`/`nil`) to filter by;
    * `:query`  — a search string matched against reference / subject / customer / route;
    * `:limit`  — cap the number of rows.
  """
  def list_quote_requests(%Scope{} = scope, opts \\ []) do
    QuoteRequest
    |> Tenancy.scope(scope)
    |> filter_status(opts[:status])
    |> filter_search(opts[:query])
    |> order_by([q], desc: q.inserted_at, desc: q.id)
    |> maybe_limit(opts[:limit])
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
            ilike(q.customer_email, ^like) or ilike(q.route, ^like) or
            ilike(q.reference, ^like)
        )
    end
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, n) when is_integer(n) and n > 0, do: limit(query, ^n)

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

  @doc """
  Creates a quote request (`quote:create`) in `new`, stamped with the actor's membership
  and a per-tenant reference (e.g. `QA-1042`). Audited.
  """
  def create_quote_request(%Scope{} = scope, attrs) do
    Repo.transact(fn ->
      changeset =
        %QuoteRequest{
          tenant_id: scope.tenant.id,
          submitted_by: scope.membership.id,
          reference: next_reference(scope.tenant.id)
        }
        |> QuoteRequest.changeset(attrs)

      with {:ok, quote_request} <- Repo.insert(changeset) do
        audit(scope, "quote.created", quote_request.id, %{"reference" => quote_request.reference})
        {:ok, quote_request}
      end
    end)
  end

  # Next per-tenant reference. Counts every quote ever created for the tenant (incl.
  # soft-deleted) so references are never reused; the unique index guards the rare race.
  defp next_reference(tenant_id) do
    n = Repo.aggregate(from(q in QuoteRequest, where: q.tenant_id == ^tenant_id), :count, :id)
    "QA-" <> Integer.to_string(1001 + n)
  end

  @doc "Edits a quote request's customer details / travel facts (`quote:update`). Audited."
  def update_quote_request(%Scope{} = scope, %QuoteRequest{} = quote_request, attrs) do
    Repo.transact(fn ->
      with {:ok, updated} <- quote_request |> QuoteRequest.changeset(attrs) |> Repo.update() do
        audit(scope, "quote.updated", updated.id, %{"reference" => updated.reference})
        {:ok, updated}
      end
    end)
  end

  @doc """
  Applies a guarded status transition (`quote:status`) and audits it. Used for the
  manual outcomes (cancel a lead, mark a quote accepted/rejected/expired). The
  send-driven `→ quoted` transition runs inside `send_message/2`.
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
        audit(scope, "quote.deleted", deleted.id, %{"reference" => deleted.reference})
        {:ok, deleted}
      end
    end)
  end

  @doc """
  Dashboard counts (R8) for the scope's tenant: open leads being worked (new/in_progress),
  quotes sent this calendar month, and the all-time total.
  """
  def dashboard_stats(%Scope{} = scope) do
    base = Tenancy.scope(QuoteRequest, scope)
    month_start = month_start()

    %{
      open: Repo.aggregate(where(base, [q], q.status in [:new, :in_progress]), :count, :id),
      quoted_this_month:
        Repo.aggregate(
          where(base, [q], q.status == :quoted and q.updated_at >= ^month_start),
          :count,
          :id
        ),
      total: Repo.aggregate(base, :count, :id)
    }
  end

  defp month_start do
    %{DateTime.utc_now() | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
  end

  # ── Message thread (the gate + provenance + disposition) ─────────────────────────

  @doc "Messages on a quote, oldest first, with author + sender memberships preloaded."
  def list_messages(%Scope{} = scope, %QuoteRequest{id: quote_request_id}) do
    QuoteMessage
    |> Tenancy.scope(scope)
    |> where([m], m.quote_request_id == ^quote_request_id)
    |> order_by([m], asc: m.inserted_at, asc: m.id)
    |> preload(authored_by_membership: :user, sent_by_membership: :user)
    |> Repo.all()
  end

  @doc "A single message in the scope's tenant by id, or nil. Safe for untrusted ids."
  def get_message(%Scope{} = scope, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        QuoteMessage |> Tenancy.scope(scope) |> where([m], m.id == ^uuid) |> Repo.one()

      :error ->
        nil
    end
  end

  @doc """
  Generates an AI draft reply (`quote:ai_generate`): appends an `ai`/`draft` message via
  `AIService.generate_reply/1` (a stub today) and moves a fresh lead `new → in_progress`.
  Nothing is sent — it waits for a human to confirm & send. Audited.
  """
  def generate_ai_reply(%Scope{} = scope, %QuoteRequest{} = quote_request) do
    body = AIService.generate_reply(quote_request)

    Repo.transact(fn ->
      with {:ok, message} <- insert_draft(scope, quote_request, :ai, body, nil),
           {:ok, _} <- maybe_start(scope, quote_request) do
        audit(scope, "quote.ai_drafted", quote_request.id, %{})
        {:ok, message}
      end
    end)
  end

  @doc """
  Composes a human draft reply (`quote:reply`): an `human`/`draft` message authored by the
  actor; moves a fresh lead `new → in_progress`. Audited.
  """
  def compose_draft(%Scope{} = scope, %QuoteRequest{} = quote_request, body) do
    Repo.transact(fn ->
      with {:ok, message} <- insert_draft(scope, quote_request, :human, body, scope.membership.id),
           {:ok, _} <- maybe_start(scope, quote_request) do
        audit(scope, "quote.draft_composed", quote_request.id, %{})
        {:ok, message}
      end
    end)
  end

  defp insert_draft(scope, quote_request, author_type, body, authored_by) do
    %QuoteMessage{
      tenant_id: scope.tenant.id,
      quote_request_id: quote_request.id,
      author_type: author_type,
      status: :draft,
      authored_by: authored_by
    }
    |> QuoteMessage.changeset(%{body: body})
    |> Repo.insert()
  end

  # Move a fresh lead into `in_progress` when the first draft is prepared; a no-op once
  # it's already in progress or further along.
  defp maybe_start(scope, %QuoteRequest{status: :new} = quote_request) do
    quote_request
    |> QuoteRequest.status_changeset(:in_progress)
    |> Repo.update()
    |> tap_audit(scope, quote_request, :in_progress)
  end

  defp maybe_start(_scope, quote_request), do: {:ok, quote_request}

  defp tap_audit({:ok, _} = ok, scope, quote_request, to) do
    audit(scope, "quote.status_changed", quote_request.id, %{
      "from" => to_string(quote_request.status),
      "to" => to_string(to)
    })

    ok
  end

  defp tap_audit(other, _scope, _quote_request, _to), do: other

  @doc "Edits a draft's body (`quote:reply`), marking it human-edited and resetting to draft."
  def edit_draft(%Scope{} = scope, %QuoteMessage{status: status} = message, body)
      when status in [:draft, :confirmed] do
    Repo.transact(fn ->
      with {:ok, updated} <-
             message |> QuoteMessage.edit_changeset(%{body: body}) |> Repo.update() do
        audit(scope, "quote.draft_edited", message.quote_request_id, %{})
        {:ok, updated}
      end
    end)
  end

  def edit_draft(%Scope{}, %QuoteMessage{}, _body), do: {:error, :not_a_draft}

  @doc "Confirms a draft for sending (`quote:reply`): `draft → confirmed`. Audited."
  def confirm_message(%Scope{} = scope, %QuoteMessage{status: :draft} = message) do
    Repo.transact(fn ->
      with {:ok, updated} <-
             message |> Ecto.Changeset.change(status: :confirmed) |> Repo.update() do
        audit(scope, "quote.message_confirmed", message.quote_request_id, %{})
        {:ok, updated}
      end
    end)
  end

  def confirm_message(%Scope{}, %QuoteMessage{}), do: {:error, :not_a_draft}

  @doc """
  Sends an outbound message (`quote:reply`) — the gate: `draft`/`confirmed → sent`, stamps
  the human `sent_by`, moves the quote `→ quoted` with `awaiting: :client`, and sets
  `valid_until` on the first send. Atomic + audited. Returns `{:ok, message}` or
  `{:error, :not_sendable}`.
  """
  def send_message(%Scope{} = scope, %QuoteMessage{status: status} = message)
      when status in [:draft, :confirmed] do
    Repo.transact(fn ->
      with {:ok, sent} <- mark_sent(scope, message),
           {:ok, _quote} <- mark_quoted(scope, message.quote_request_id) do
        audit(scope, "quote.sent", message.quote_request_id, %{})
        {:ok, sent}
      end
    end)
  end

  def send_message(%Scope{}, %QuoteMessage{}), do: {:error, :not_sendable}

  defp mark_sent(scope, message) do
    message
    |> Ecto.Changeset.change(status: :sent, sent_by: scope.membership.id)
    |> Repo.update()
  end

  # Move the quote to `quoted` (from new/in_progress), set ball-in-court to the client,
  # and stamp validity on the first send. Already-quoted leads just refresh `awaiting`.
  defp mark_quoted(scope, quote_request_id) do
    quote_request = Repo.get!(QuoteRequest, quote_request_id)

    cond do
      quote_request.status == :quoted ->
        quote_request |> QuoteRequest.awaiting_changeset(:client) |> Repo.update()

      QuoteRequest.can_transition?(quote_request.status, :quoted) ->
        extra = %{awaiting: :client, valid_until: validity_deadline(quote_request)}

        with {:ok, updated} <-
               quote_request |> QuoteRequest.status_changeset(:quoted, extra) |> Repo.update() do
          audit(scope, "quote.status_changed", quote_request.id, %{
            "from" => to_string(quote_request.status),
            "to" => "quoted"
          })

          {:ok, updated}
        end

      true ->
        {:ok, quote_request}
    end
  end

  defp validity_deadline(%QuoteRequest{valid_until: nil}),
    do: Date.add(Date.utc_today(), @validity_days)

  defp validity_deadline(%QuoteRequest{valid_until: existing}), do: existing

  @doc """
  Records a client's inbound reply (`quote:reply`) — a `received`/`client` message tagged
  with a `disposition`. Sets `awaiting: :us`; an `:acceptance` resolves the quote to
  `accepted`, a `:rejection` to `rejected`; other dispositions keep it `quoted` (the loop).
  Audited.
  """
  def receive_client_reply(%Scope{} = scope, %QuoteRequest{} = quote_request, body, disposition)
      when disposition in [:question, :change_request, :acceptance, :rejection, :other] do
    Repo.transact(fn ->
      with {:ok, message} <- insert_client_message(scope, quote_request, body, disposition),
           {:ok, _quote} <- apply_disposition(scope, quote_request, disposition) do
        audit(scope, "quote.client_replied", quote_request.id, %{
          "disposition" => to_string(disposition)
        })

        {:ok, message}
      end
    end)
  end

  defp insert_client_message(scope, quote_request, body, disposition) do
    %QuoteMessage{
      tenant_id: scope.tenant.id,
      quote_request_id: quote_request.id,
      author_type: :client,
      status: :received
    }
    |> QuoteMessage.changeset(%{body: body, disposition: disposition})
    |> Repo.insert()
  end

  # A client reply puts the ball in our court; acceptance/rejection resolve the quote
  # (when reachable), the rest keep it where it is.
  defp apply_disposition(scope, quote_request, :acceptance),
    do: resolve(scope, quote_request, :accepted)

  defp apply_disposition(scope, quote_request, :rejection),
    do: resolve(scope, quote_request, :rejected)

  defp apply_disposition(_scope, quote_request, _disposition),
    do: quote_request |> QuoteRequest.awaiting_changeset(:us) |> Repo.update()

  defp resolve(scope, quote_request, outcome) do
    if QuoteRequest.can_transition?(quote_request.status, outcome) do
      with {:ok, updated} <-
             quote_request
             |> QuoteRequest.status_changeset(outcome, %{awaiting: :us})
             |> Repo.update() do
        audit(scope, "quote.status_changed", quote_request.id, %{
          "from" => to_string(quote_request.status),
          "to" => to_string(outcome)
        })

        {:ok, updated}
      end
    else
      quote_request |> QuoteRequest.awaiting_changeset(:us) |> Repo.update()
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
