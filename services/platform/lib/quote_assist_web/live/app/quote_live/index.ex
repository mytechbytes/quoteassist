defmodule QuoteAssistWeb.App.QuoteLive.Index do
  @moduledoc """
  Quote requests (`/app/quotes`) — the lead inbox (R11-quotes). Lists live quote requests
  for the tenant with a status filter and a search box, and links out to the dedicated
  create page and per-lead detail. Page gate: `quote:list` (raise → branded 403);
  the New button is gated by `quote:create`, row links by `quote:read`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Quotes
  alias QuoteAssist.Quotes.QuoteRequest
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(_params, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "quote:list")

    {:ok,
     socket
     |> assign(page_title: "Quotes", status: :all, query: "")
     |> load_quotes()}
  end

  defp load_quotes(socket) do
    quotes =
      Quotes.list_quote_requests(socket.assigns.current_scope,
        status: socket.assigns.status,
        query: socket.assigns.query
      )

    assign(socket, :quotes, quotes)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="quotes"
      breadcrumb="Quotes"
    >
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Workspace
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Quote requests
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Inbound enquiries to quote. Capture a lead, work it, and send the quote.
          </p>
        </div>
        <.link
          :if={can?(@current_scope, "quote:create")}
          id="new-quote"
          navigate={~p"/app/quotes/new"}
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
        >
          <.icon name="hero-plus" class="size-4" /> New quote
        </.link>
      </div>

      <form id="quote-filter" phx-change="filter" class="mb-4 flex flex-wrap items-center gap-3">
        <div class="relative flex-1" style="min-width:220px">
          <input
            type="text"
            name="query"
            value={@query}
            placeholder="Search subject, customer, email…"
            phx-debounce="300"
            class="mtb-input w-full"
          />
        </div>
        <select name="status" class="mtb-input" style="max-width:200px">
          <option value="all" selected={@status == :all}>All statuses</option>
          <option
            :for={s <- QuoteRequest.statuses()}
            value={s}
            selected={@status == s}
          >
            {QuoteRequest.status_label(s)}
          </option>
        </select>
      </form>

      <div class="mtb-card overflow-hidden">
        <p
          :if={@quotes == []}
          class="px-5 py-12 text-center text-sm"
          style="color:var(--mc-text-3)"
        >
          No quote requests {if @status != :all or @query != "", do: "match your filters", else: "yet"}.
        </p>

        <table :if={@quotes != []} class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Customer
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Subject
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Status
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Updated
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={quote <- @quotes}
              id={"quote-#{quote.id}"}
              style="border-top:1px solid var(--mc-border)"
            >
              <td class="px-5 py-3 align-middle">
                <.link
                  :if={can?(@current_scope, "quote:read")}
                  navigate={~p"/app/quotes/#{quote.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {quote.customer_name}
                </.link>
                <div
                  :if={not can?(@current_scope, "quote:read")}
                  class="text-sm font-semibold"
                  style="color:var(--mc-text)"
                >
                  {quote.customer_name}
                </div>
                <div class="font-mono text-[11px]" style="color:var(--mc-text-3)">
                  {quote.customer_email}
                </div>
              </td>
              <td class="px-4 py-3 align-middle text-sm" style="color:var(--mc-text-2)">
                {quote.subject}
              </td>
              <td class="px-4 py-3 align-middle">
                <.quote_status_badge status={quote.status} />
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-3)">
                {format_datetime(quote.updated_at)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.workspace>
    """
  end

  @impl true
  def handle_event("filter", params, socket) do
    status = parse_status(params["status"])
    query = params["query"] || ""

    {:noreply, socket |> assign(status: status, query: query) |> load_quotes()}
  end

  defp parse_status(nil), do: :all
  defp parse_status("all"), do: :all

  defp parse_status(value) when is_binary(value) do
    if value in Enum.map(QuoteRequest.statuses(), &to_string/1),
      do: String.to_existing_atom(value),
      else: :all
  end
end
