defmodule QuoteAssistWeb.App.QuoteLive.Show do
  @moduledoc """
  Quote detail (`/app/quotes/:id`) — ported from `designs/quote-detail.html`: the lead's
  header (reference · status · awaiting · trip line), trip facts + quote summary, the
  reply **thread with the human-in-the-loop gate**, and an activity feed.

  The gate: "Generate with AI" / "Compose" create a **draft** (quote → in_progress);
  **Confirm** then **Send** delivers it (quote → quoted, awaiting the client) — nothing
  sends without a human. Client replies are logged with a **disposition** that can resolve
  the quote (accepted/rejected) or keep it `quoted` (question/change request).

  Page gate: `quote:read`. Per-action gates: `quote:status` (cancel / mark outcome),
  `quote:reply` (draft / confirm / send / log client reply), `quote:ai_generate`
  (AI draft), `quote:update` (edit), `quote:delete`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Quotes
  alias QuoteAssist.Quotes.{QuoteMessage, QuoteRequest}
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "quote:read")

    {:ok,
     socket
     |> assign(compose: "", reply: "", reply_disposition: "question", editing: nil, edit_body: "")
     |> load(id)}
  end

  defp load(socket, id) do
    case Quotes.get_quote_request(socket.assigns.current_scope, id) do
      %QuoteRequest{} = quote ->
        assign(socket,
          page_title: quote.reference || quote.subject,
          quote: quote,
          messages: Quotes.list_messages(socket.assigns.current_scope, quote),
          logs: Audit.list_for_target("quote_request", quote.id)
        )

      nil ->
        socket
        |> put_flash(:error, "That quote no longer exists.")
        |> push_navigate(to: ~p"/app/quotes")
    end
  end

  defp reload(socket), do: load(socket, socket.assigns.quote.id)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="quotes"
      breadcrumb={@quote.reference || @quote.subject}
    >
      <div class="mb-6">
        <.link navigate={~p"/app/quotes"} class="text-xs font-semibold" style="color:var(--mc-text-3)">
          ← Quotes
        </.link>
        <div class="mt-1.5 flex flex-wrap items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2.5">
              <h1
                class="text-2xl font-bold tracking-tight"
                style="font-family:var(--font-display);color:var(--mc-text)"
              >
                {@quote.customer_name}
              </h1>
              <.quote_status_badge status={@quote.status} />
              <.awaiting_badge awaiting={@quote.awaiting} />
            </div>
            <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
              <span class="font-mono" style="color:var(--mc-brand)">{@quote.reference}</span>
              · {@quote.route || @quote.subject} <span :if={@quote.pax}>· {@quote.pax}</span>
              <span :if={@quote.travel_dates}>· {@quote.travel_dates}</span>
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-1.5">
            <button
              :for={{target, label} <- status_actions(@quote.status)}
              :if={can?(@current_scope, "quote:status")}
              phx-click="transition"
              phx-value-to={target}
              data-confirm={if target == :cancelled, do: "Cancel this quote?", else: nil}
              class="mtb-btn mtb-btn-ghost mtb-btn-sm"
            >
              {label}
            </button>
            <.link
              :if={can?(@current_scope, "quote:update")}
              navigate={~p"/app/quotes/#{@quote.id}/edit"}
              class="mtb-btn mtb-btn-secondary mtb-btn-sm"
            >
              Edit inputs
            </.link>
            <button
              :if={can?(@current_scope, "quote:delete")}
              phx-click="delete"
              data-confirm="Delete this quote?"
              class="mtb-btn mtb-btn-danger-outline mtb-btn-sm"
            >
              Delete
            </button>
          </div>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.5fr_1fr]">
        <%!-- LEFT: enquiry + thread --%>
        <div class="space-y-6">
          <div class="mtb-card p-6">
            <div class="mb-2 text-xs font-bold uppercase tracking-wide" style="color:var(--mc-text-3)">
              Customer enquiry
            </div>
            <p class="whitespace-pre-wrap text-sm" style="color:var(--mc-text-2);line-height:1.6">
              {@quote.body}
            </p>
          </div>

          <div class="mtb-card p-6">
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Reply thread</div>

            <p :if={@messages == []} class="text-sm" style="color:var(--mc-text-3)">
              No messages yet. Draft a reply below — or generate one with AI.
            </p>

            <ol :if={@messages != []} class="space-y-4">
              <li
                :for={m <- @messages}
                id={"message-#{m.id}"}
                class="rounded-lg p-3"
                style={message_bg(m)}
              >
                <div class="mb-1 flex flex-wrap items-center gap-2">
                  <.message_status_badge status={m.status} />
                  <.disposition_badge :if={m.author_type == :client} disposition={m.disposition} />
                  <span :if={m.author_type == :ai} class="mtb-badge mtb-badge-brand">AI</span>
                  <span :if={m.edited_by_human} class="text-[11px]" style="color:var(--mc-text-3)">edited</span>
                  <span class="text-xs font-medium" style="color:var(--mc-text-2)">{message_author(m)}</span>
                  <span class="ml-auto font-mono text-[11px]" style="color:var(--mc-text-3)">
                    {format_datetime(m.inserted_at)}
                  </span>
                </div>

                <%= if @editing == m.id do %>
                  <form phx-submit="save_edit" id={"edit-#{m.id}"}>
                    <input type="hidden" name="message_id" value={m.id} />
                    <textarea name="body" rows="5" class="mtb-input w-full">{@edit_body}</textarea>
                    <div class="mt-2 flex gap-2">
                      <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">Save</.button>
                      <button
                        type="button"
                        phx-click="cancel_edit"
                        class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                      >
                        Cancel
                      </button>
                    </div>
                  </form>
                <% else %>
                  <p class="whitespace-pre-wrap text-sm" style="color:var(--mc-text);line-height:1.6">
                    {m.body}
                  </p>
                  <div :if={outbound_actions?(@current_scope, m)} class="mt-2 flex flex-wrap gap-1.5">
                    <button
                      phx-click="edit"
                      phx-value-id={m.id}
                      class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                    >Edit</button>
                    <button
                      :if={m.status == :draft}
                      phx-click="confirm"
                      phx-value-id={m.id}
                      class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                    >
                      Confirm
                    </button>
                    <button
                      phx-click="send"
                      phx-value-id={m.id}
                      class="mtb-btn mtb-btn-primary mtb-btn-sm"
                    >
                      {if m.status == :confirmed, do: "Send", else: "Confirm & send"}
                    </button>
                  </div>
                <% end %>
              </li>
            </ol>

            <%!-- Composer (draft a reply) --%>
            <div
              :if={can?(@current_scope, "quote:reply") and not terminal?(@quote)}
              class="mt-5 border-t pt-5"
              style="border-color:var(--mc-border)"
            >
              <form phx-submit="compose" id="composer">
                <label class="mtb-label">Draft a reply</label>
                <textarea
                  name="body"
                  rows="4"
                  class="mtb-input w-full"
                  placeholder="Write a reply, or generate one with AI…"
                >{@compose}</textarea>
                <div class="mt-3 flex flex-wrap items-center gap-2">
                  <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
                    Save draft
                  </.button>
                  <button
                    :if={can?(@current_scope, "quote:ai_generate")}
                    type="button"
                    phx-click="generate"
                    class="mtb-btn mtb-btn-secondary mtb-btn-sm"
                    phx-disable-with="Generating…"
                  >
                    <.icon name="hero-sparkles" class="size-4" /> Generate with AI
                  </button>
                </div>
              </form>

              <%!-- Log an inbound client reply --%>
              <form phx-submit="log_reply" id="client-reply" class="mt-5">
                <label class="mtb-label">Log a client reply</label>
                <textarea
                  name="body"
                  rows="3"
                  class="mtb-input w-full"
                  placeholder="What did the client say?"
                >{@reply}</textarea>
                <div class="mt-3 flex flex-wrap items-center gap-2">
                  <select name="disposition" class="mtb-input mtb-select" style="width:200px">
                    <option
                      :for={d <- QuoteMessage.dispositions()}
                      value={d}
                      selected={@reply_disposition == to_string(d)}
                    >
                      {QuoteMessage.disposition_label(d)}
                    </option>
                  </select>
                  <.button class="mtb-btn mtb-btn-secondary mtb-btn-sm" phx-disable-with="Logging…">
                    Log client reply
                  </.button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <%!-- RIGHT: summary + trip facts + activity --%>
        <div class="space-y-6">
          <div class="mtb-card p-6">
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">
              Quote summary
            </div>
            <div class="rounded-xl p-4" style="background:var(--mc-brand-soft)">
              <div class="text-xs font-semibold" style="color:var(--mc-brand)">Quote total</div>
              <div class="mt-1 font-mono text-2xl font-bold" style="color:var(--mc-brand)">
                {format_total(@quote)}
              </div>
            </div>
            <p :if={@quote.valid_until} class="mt-3 text-xs" style="color:var(--mc-text-2)">
              Valid until <span class="font-mono">{Calendar.strftime(@quote.valid_until, "%d %b %Y")}</span>.
            </p>
          </div>

          <div class="mtb-card p-6">
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Trip facts</div>
            <div class="grid grid-cols-2 gap-3">
              <.fact label="Route" value={@quote.route} mono />
              <.fact label="Travel dates" value={@quote.travel_dates} />
              <.fact label="Passengers" value={@quote.pax} />
              <.fact label="Customer" value={@quote.customer_email} mono />
            </div>
          </div>

          <div class="mtb-card p-6">
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
            <.audit_timeline logs={@logs} empty="No activity for this quote yet." />
          </div>
        </div>
      </div>
    </Layouts.workspace>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :mono, :boolean, default: false

  defp fact(assigns) do
    ~H"""
    <div class="rounded-lg p-3" style="background:var(--mc-surface-2)">
      <div class="text-[11px]" style="color:var(--mc-text-3)">{@label}</div>
      <div class={["mt-0.5 text-sm font-medium", @mono && "font-mono"]} style="color:var(--mc-text)">
        {@value || "—"}
      </div>
    </div>
    """
  end

  # ── Events ─────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("transition", %{"to" => to}, socket) do
    with true <- can?(socket.assigns.current_scope, "quote:status"),
         {:ok, status} <- cast_status(to),
         {:ok, _} <-
           Quotes.transition_status(socket.assigns.current_scope, socket.assigns.quote, status) do
      {:noreply, socket |> put_flash(:info, "Status updated.") |> reload()}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, socket |> put_flash(:error, "Couldn't update the status.") |> reload()}
    end
  end

  def handle_event("delete", _params, socket) do
    with true <- can?(socket.assigns.current_scope, "quote:delete"),
         {:ok, _} <-
           Quotes.soft_delete_quote_request(socket.assigns.current_scope, socket.assigns.quote) do
      {:noreply,
       socket |> put_flash(:info, "Quote deleted.") |> push_navigate(to: ~p"/app/quotes")}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, put_flash(socket, :error, "Couldn't delete that quote.")}
    end
  end

  def handle_event("generate", _params, socket) do
    with true <- can?(socket.assigns.current_scope, "quote:ai_generate"),
         {:ok, _} <- Quotes.generate_ai_reply(socket.assigns.current_scope, socket.assigns.quote) do
      {:noreply, socket |> put_flash(:info, "AI draft added.") |> reload()}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, put_flash(socket, :error, "Couldn't generate a draft.")}
    end
  end

  def handle_event("compose", %{"body" => body}, socket) do
    cond do
      not can?(socket.assigns.current_scope, "quote:reply") -> {:noreply, denied(socket)}
      blank?(body) -> {:noreply, put_flash(socket, :error, "Write something first.")}
      true -> do_compose(socket, body)
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case message(socket, id) do
      %QuoteMessage{} = m -> {:noreply, assign(socket, editing: m.id, edit_body: m.body)}
      nil -> {:noreply, reload(socket)}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: nil, edit_body: "")}
  end

  def handle_event("save_edit", %{"message_id" => id, "body" => body}, socket) do
    with %QuoteMessage{} = m <- message(socket, id),
         {:ok, _} <- Quotes.edit_draft(socket.assigns.current_scope, m, body) do
      {:noreply,
       socket
       |> assign(editing: nil, edit_body: "")
       |> put_flash(:info, "Draft updated.")
       |> reload()}
    else
      _ ->
        {:noreply,
         socket
         |> assign(editing: nil)
         |> put_flash(:error, "Couldn't update that draft.")
         |> reload()}
    end
  end

  def handle_event("confirm", %{"id" => id}, socket) do
    act_on_message(socket, id, &Quotes.confirm_message/2, "Reply confirmed.")
  end

  def handle_event("send", %{"id" => id}, socket) do
    act_on_message(socket, id, &Quotes.send_message/2, "Reply sent.")
  end

  def handle_event("log_reply", %{"body" => body, "disposition" => disposition}, socket) do
    with true <- can?(socket.assigns.current_scope, "quote:reply"),
         false <- blank?(body),
         {:ok, d} <- cast_disposition(disposition),
         {:ok, _} <-
           Quotes.receive_client_reply(
             socket.assigns.current_scope,
             socket.assigns.quote,
             body,
             d
           ) do
      {:noreply,
       socket |> assign(reply: "") |> put_flash(:info, "Client reply logged.") |> reload()}
    else
      false -> {:noreply, denied(socket)}
      true -> {:noreply, put_flash(socket, :error, "Write the client's reply first.")}
      _ -> {:noreply, put_flash(socket, :error, "Couldn't log that reply.")}
    end
  end

  defp do_compose(socket, body) do
    case Quotes.compose_draft(socket.assigns.current_scope, socket.assigns.quote, body) do
      {:ok, _} ->
        {:noreply, socket |> assign(compose: "") |> put_flash(:info, "Draft saved.") |> reload()}

      _ ->
        {:noreply, put_flash(socket, :error, "Couldn't save that draft.")}
    end
  end

  defp act_on_message(socket, id, fun, ok_msg) do
    with true <- can?(socket.assigns.current_scope, "quote:reply"),
         %QuoteMessage{} = m <- message(socket, id),
         {:ok, _} <- fun.(socket.assigns.current_scope, m) do
      {:noreply, socket |> put_flash(:info, ok_msg) |> reload()}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, socket |> put_flash(:error, "Couldn't update that message.") |> reload()}
    end
  end

  defp message(socket, id), do: Quotes.get_message(socket.assigns.current_scope, id)

  # Meaningful status moves per current status (a subset of the schema's legal
  # transitions, so a button can never trigger an illegal jump).
  defp status_actions(:new), do: [{:cancelled, "Cancel"}]
  defp status_actions(:in_progress), do: [{:cancelled, "Cancel"}]

  defp status_actions(:quoted),
    do: [
      {:accepted, "Mark accepted"},
      {:rejected, "Mark rejected"},
      {:expired, "Mark expired"},
      {:cancelled, "Cancel"}
    ]

  defp status_actions(_terminal), do: []

  # Outbound (ai/human) messages that aren't sent yet get the confirm/send/edit gate.
  defp outbound_actions?(scope, %QuoteMessage{author_type: t, status: s}),
    do: t in [:ai, :human] and s in [:draft, :confirmed] and can?(scope, "quote:reply")

  defp terminal?(%QuoteRequest{status: status}), do: QuoteRequest.terminal?(status)

  defp message_bg(%QuoteMessage{author_type: :client}), do: "background:var(--mc-surface-2)"
  defp message_bg(_message), do: "background:var(--mc-surface)"

  defp cast_status(value) do
    case Enum.find(QuoteRequest.statuses(), &(to_string(&1) == value)) do
      nil -> :error
      status -> {:ok, status}
    end
  end

  defp cast_disposition(value) do
    case Enum.find(QuoteMessage.dispositions(), &(to_string(&1) == value)) do
      nil -> :error
      d -> {:ok, d}
    end
  end

  defp blank?(v), do: is_nil(v) or String.trim(to_string(v)) == ""

  defp denied(socket), do: put_flash(socket, :error, "You don't have permission to do that.")
end
