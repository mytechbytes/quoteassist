defmodule QuoteAssistWeb.App.QuoteLive.Show do
  @moduledoc """
  Quote request detail (`/app/quotes/:id`) — the lead, its status controls, the reply
  thread, and an activity feed (R11-quotes + R12-quote-reply). Page gate: `quote:read`.
  Per-action gates: status moves (`quote:status`), edit (`quote:update`), delete
  (`quote:delete`), reply (`quote:reply`), and AI draft (`quote:ai_generate`).

  Replies are human-in-the-loop: "Generate with AI" only fills the composer with a draft
  (`QuoteAssist.AIService`, a stub today); nothing sends until a member clicks Send, which
  appends the message and advances the lead to `quoted`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Quotes
  alias QuoteAssist.Quotes.QuoteRequest
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "quote:read")
    {:ok, socket |> assign(draft: "") |> load(id)}
  end

  defp load(socket, id) do
    case Quotes.get_quote_request(socket.assigns.current_scope, id) do
      %QuoteRequest{} = quote ->
        assign(socket,
          page_title: quote.subject,
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
      breadcrumb={@quote.subject}
    >
      <div class="mb-6">
        <.link navigate={~p"/app/quotes"} class="text-xs font-semibold" style="color:var(--mc-text-3)">
          ← Quotes
        </.link>
        <div class="mt-1.5 flex flex-wrap items-start justify-between gap-3">
          <div>
            <div class="flex items-center gap-2.5">
              <h1
                class="text-2xl font-bold tracking-tight"
                style="font-family:var(--font-display);color:var(--mc-text)"
              >
                {@quote.subject}
              </h1>
              <.quote_status_badge status={@quote.status} />
            </div>
            <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
              {@quote.customer_name} · <span class="font-mono">{@quote.customer_email}</span>
            </p>
          </div>
          <div class="flex flex-wrap items-center gap-1.5">
            <button
              :for={{target, label} <- status_actions(@quote.status)}
              :if={can?(@current_scope, "quote:status")}
              phx-click="transition"
              phx-value-to={target}
              class="mtb-btn mtb-btn-ghost mtb-btn-sm"
            >
              {label}
            </button>
            <.link
              :if={can?(@current_scope, "quote:update")}
              navigate={~p"/app/quotes/#{@quote.id}/edit"}
              class="mtb-btn mtb-btn-secondary mtb-btn-sm"
            >
              Edit
            </.link>
            <button
              :if={can?(@current_scope, "quote:delete")}
              phx-click="delete"
              data-confirm="Delete this quote request?"
              class="mtb-btn mtb-btn-danger-outline mtb-btn-sm"
            >
              Delete
            </button>
          </div>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.5fr_1fr]">
        <div class="space-y-6">
          <div class="mtb-card p-6">
            <div class="mb-2 text-xs font-bold uppercase tracking-wide" style="color:var(--mc-text-3)">
              Request
            </div>
            <p class="whitespace-pre-wrap text-sm" style="color:var(--mc-text-2);line-height:1.6">
              {@quote.body}
            </p>
          </div>

          <div class="mtb-card p-6">
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Replies</div>
            <p :if={@messages == []} class="text-sm" style="color:var(--mc-text-3)">
              No replies yet.
            </p>
            <ol :if={@messages != []} class="space-y-4">
              <li :for={message <- @messages} id={"message-#{message.id}"} class="flex flex-col gap-1">
                <div class="flex items-center gap-2">
                  <span class={[
                    "mtb-badge",
                    if(message.author_type == :ai, do: "mtb-badge-brand", else: "mtb-badge-neutral")
                  ]}>
                    {if message.author_type == :ai, do: "AI", else: "Reply"}
                  </span>
                  <span class="text-xs font-medium" style="color:var(--mc-text-2)">
                    {message_author(message)}
                  </span>
                  <span class="font-mono text-[11px]" style="color:var(--mc-text-3)">
                    {format_datetime(message.inserted_at)}
                  </span>
                </div>
                <p class="whitespace-pre-wrap text-sm" style="color:var(--mc-text);line-height:1.6">
                  {message.body}
                </p>
              </li>
            </ol>

            <.composer
              :if={can?(@current_scope, "quote:reply")}
              draft={@draft}
              can_generate={can?(@current_scope, "quote:ai_generate")}
            />
          </div>
        </div>

        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
          <.audit_timeline logs={@logs} empty="No activity for this quote yet." />
        </div>
      </div>
    </Layouts.workspace>
    """
  end

  attr :draft, :string, required: true
  attr :can_generate, :boolean, required: true

  defp composer(assigns) do
    ~H"""
    <form
      id="reply-form"
      phx-change="draft_change"
      phx-submit="send"
      class="mt-5 border-t pt-5"
      style="border-color:var(--mc-border)"
    >
      <textarea
        name="reply[body]"
        rows="4"
        placeholder="Write a reply, or generate a draft with AI…"
        class="mtb-input w-full"
      >{@draft}</textarea>
      <div class="mt-3 flex items-center gap-2">
        <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Sending…">
          Send reply
        </.button>
        <button
          :if={@can_generate}
          type="button"
          phx-click="generate"
          class="mtb-btn mtb-btn-secondary mtb-btn-sm"
          phx-disable-with="Generating…"
        >
          <.icon name="hero-sparkles" class="size-4" /> Generate with AI
        </button>
      </div>
    </form>
    """
  end

  @impl true
  def handle_event("transition", %{"to" => to}, socket) do
    with true <- can?(socket.assigns.current_scope, "quote:status"),
         {:ok, status} <- cast_status(to),
         {:ok, _quote} <-
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

  def handle_event("draft_change", %{"reply" => %{"body" => body}}, socket) do
    {:noreply, assign(socket, draft: body)}
  end

  def handle_event("generate", _params, socket) do
    with true <- can?(socket.assigns.current_scope, "quote:ai_generate"),
         {:ok, draft} <-
           Quotes.generate_ai_reply(socket.assigns.current_scope, socket.assigns.quote) do
      {:noreply, socket |> assign(draft: draft) |> reload()}
    else
      false -> {:noreply, denied(socket)}
    end
  end

  def handle_event("send", %{"reply" => %{"body" => body}}, socket) do
    cond do
      not can?(socket.assigns.current_scope, "quote:reply") ->
        {:noreply, denied(socket)}

      String.trim(body) == "" ->
        {:noreply, put_flash(socket, :error, "Write a reply before sending.")}

      true ->
        send_reply(socket, body)
    end
  end

  defp send_reply(socket, body) do
    case Quotes.send_reply(socket.assigns.current_scope, socket.assigns.quote, body) do
      {:ok, _message} ->
        {:noreply, socket |> put_flash(:info, "Reply sent.") |> assign(draft: "") |> reload()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Couldn't send that reply.")}
    end
  end

  # Reachable, meaningful status moves per current status — kept a subset of the schema's
  # legal transitions so the buttons can never trigger an illegal jump.
  defp status_actions(:open), do: [{:in_progress, "Start"}, {:closed, "Close"}]
  defp status_actions(:in_progress), do: [{:quoted, "Mark quoted"}, {:closed, "Close"}]
  defp status_actions(:quoted), do: [{:closed, "Close"}]
  defp status_actions(:closed), do: [{:open, "Reopen"}]

  defp cast_status(value) do
    if value in Enum.map(QuoteRequest.statuses(), &to_string/1),
      do: {:ok, String.to_existing_atom(value)},
      else: :error
  end

  defp message_author(%{author_type: :ai}), do: "AI draft"
  defp message_author(%{author_membership: %{} = membership}), do: member_name(membership)
  defp message_author(_message), do: "—"

  defp denied(socket), do: put_flash(socket, :error, "You don't have permission to do that.")
end
