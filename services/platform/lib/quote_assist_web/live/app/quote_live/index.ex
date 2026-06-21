defmodule QuoteAssistWeb.App.QuoteLive.Index do
  @moduledoc """
  Quote requests (`/app/quotes`) — the lead inbox, ported from `designs/quotes.html` on a
  list engine (the design's `qa-listkit.js`, in LiveView): **table / cards / list** views,
  a search box, **add / remove filters** (status · customer · route · pax · total ·
  created), **sort** (created · total · customer · reference · status), and paging.

  Filtering / sorting / paging run in memory over the tenant's live quotes (loaded once),
  matching the design's client-side engine. Page gate: `quote:list` (raise → branded 403);
  the New button is gated by `quote:create`, row links by `quote:read`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Quotes
  alias QuoteAssist.Quotes.QuoteRequest
  alias QuoteAssistWeb.UserAuth

  @page_size 8

  # Filter fields → the operators they offer and the value input to render.
  @filter_defs %{
    "status" => %{label: "Status", ops: ["is", "is not"], input: :status},
    "customer" => %{label: "Customer", ops: ["contains", "does not contain"], input: :text},
    "route" => %{label: "Route", ops: ["contains", "does not contain"], input: :text},
    "pax" => %{label: "Passengers", ops: ["contains", "does not contain"], input: :text},
    "total" => %{label: "Total", ops: ["greater than", "less than"], input: :number},
    "created" => %{label: "Created (days)", ops: ["within"], input: :number}
  }
  @filter_order ~w(status customer route pax total created)

  @sort_defs %{
    "created" => "Created",
    "total" => "Total",
    "customer" => "Customer",
    "reference" => "Reference",
    "status" => "Status"
  }
  @sort_order ~w(created total customer reference status)

  @impl true
  def mount(_params, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "quote:list")

    {:ok,
     socket
     |> assign(
       page_title: "Quotes",
       all: Quotes.list_quote_requests(socket.assigns.current_scope),
       view: "table",
       query: "",
       filters: [],
       next_filter_id: 1,
       sort_field: "created",
       sort_dir: "desc",
       page: 1
     )
     |> recompute()}
  end

  # ── Derived view state ───────────────────────────────────────────────────────────

  defp recompute(socket) do
    items =
      socket.assigns.all
      |> search(socket.assigns.query)
      |> apply_filters(socket.assigns.filters)
      |> sort_items(socket.assigns.sort_field, socket.assigns.sort_dir)

    total = length(items)
    page_count = max(1, ceil(total / @page_size))
    page = socket.assigns.page |> min(page_count) |> max(1)
    visible = items |> Enum.drop((page - 1) * @page_size) |> Enum.take(@page_size)

    assign(socket, visible: visible, filtered_count: total, page_count: page_count, page: page)
  end

  defp search(items, query) do
    case String.trim(query || "") do
      "" ->
        items

      term ->
        t = String.downcase(term)

        Enum.filter(items, fn q ->
          String.contains?(
            String.downcase("#{q.reference} #{q.customer_name} #{q.route} #{q.subject}"),
            t
          )
        end)
    end
  end

  defp apply_filters(items, filters) do
    Enum.reduce(filters, items, fn filter, acc ->
      if blank?(filter.value), do: acc, else: Enum.filter(acc, &match_filter?(&1, filter))
    end)
  end

  defp match_filter?(q, %{field: "status", op: op, value: v}) do
    sv = to_status(v)
    if op == "is not", do: q.status != sv, else: q.status == sv
  end

  defp match_filter?(q, %{field: "customer", op: op, value: v}),
    do: text_match(q.customer_name, op, v)

  defp match_filter?(q, %{field: "route", op: op, value: v}), do: text_match(q.route, op, v)
  defp match_filter?(q, %{field: "pax", op: op, value: v}), do: text_match(q.pax, op, v)

  defp match_filter?(q, %{field: "total", op: op, value: v}) do
    total = q.total || 0
    n = to_number(v)
    if op == "less than", do: total < n, else: total > n
  end

  defp match_filter?(q, %{field: "created", value: v}) do
    DateTime.diff(DateTime.utc_now(), q.inserted_at, :day) <= to_number(v)
  end

  defp match_filter?(_q, _filter), do: true

  defp text_match(field, op, v) do
    contains? = String.contains?(String.downcase(field || ""), String.downcase(v))
    if op == "does not contain", do: not contains?, else: contains?
  end

  defp sort_items(items, field, dir) do
    sorter = if dir == "asc", do: :asc, else: :desc
    Enum.sort_by(items, &sort_key(&1, field), sorter)
  end

  defp sort_key(q, "total"), do: q.total || 0
  defp sort_key(q, "customer"), do: String.downcase(q.customer_name || "")
  defp sort_key(q, "reference"), do: q.reference || ""
  defp sort_key(q, "status"), do: Enum.find_index(QuoteRequest.statuses(), &(&1 == q.status)) || 0
  defp sort_key(q, _created), do: q.inserted_at

  # ── Render ───────────────────────────────────────────────────────────────────────

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
            Workspace · History
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Quotes
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Every enquiry and quote, with its source, travel facts and status.
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

      <%!-- TOOLBAR: search · sort · views --%>
      <div class="mtb-card mb-4 flex flex-wrap items-center gap-3 p-3">
        <form id="quote-search" phx-change="search" class="relative min-w-[200px] flex-1">
          <.icon
            name="hero-magnifying-glass"
            class="absolute left-3 top-1/2 size-4 -translate-y-1/2"
            style="color:var(--mc-text-3)"
          />
          <input
            type="text"
            name="query"
            value={@query}
            placeholder="Search ref, customer, route…"
            phx-debounce="200"
            class="mtb-input w-full pl-9"
          />
        </form>

        <button phx-click="add_filter" class="mtb-btn mtb-btn-secondary mtb-btn-sm">
          <.icon name="hero-funnel" class="size-4" /> Add filter
        </button>

        <form id="quote-sort" phx-change="sort" class="flex items-center gap-2">
          <span class="text-xs font-semibold" style="color:var(--mc-text-3)">Sort</span>
          <select name="field" class="mtb-input mtb-select" style="width:140px">
            <option :for={f <- @sort_order} value={f} selected={@sort_field == f}>
              {@sort_labels[f]}
            </option>
          </select>
          <select name="dir" class="mtb-input mtb-select" style="width:120px">
            <option value="desc" selected={@sort_dir == "desc"}>
              {sort_dir_label(@sort_field, "desc")}
            </option>
            <option value="asc" selected={@sort_dir == "asc"}>
              {sort_dir_label(@sort_field, "asc")}
            </option>
          </select>
        </form>

        <div class="flex items-center gap-1">
          <button
            :for={
              {v, icon} <- [
                {"table", "hero-table-cells"},
                {"cards", "hero-squares-2x2"},
                {"list", "hero-bars-3"}
              ]
            }
            phx-click="set_view"
            phx-value-view={v}
            class={[
              "mtb-btn mtb-btn-sm mtb-btn-icon",
              if(@view == v, do: "mtb-btn-primary", else: "mtb-btn-ghost")
            ]}
            title={v}
          >
            <.icon name={icon} class="size-4" />
          </button>
        </div>
      </div>

      <%!-- ACTIVE FILTERS (add/remove) --%>
      <form
        :if={@filters != []}
        id="quote-filters"
        phx-change="filters_changed"
        class="mtb-card mb-4 space-y-2 p-3"
      >
        <div :for={f <- @filters} class="flex flex-wrap items-center gap-2">
          <select name={"filters[#{f.id}][field]"} class="mtb-input mtb-select" style="width:150px">
            <option :for={key <- @filter_order} value={key} selected={f.field == key}>
              {@filter_defs[key].label}
            </option>
          </select>
          <select name={"filters[#{f.id}][op]"} class="mtb-input mtb-select" style="width:160px">
            <option :for={op <- @filter_defs[f.field].ops} value={op} selected={f.op == op}>
              {op}
            </option>
          </select>
          <%= if @filter_defs[f.field].input == :status do %>
            <select name={"filters[#{f.id}][value]"} class="mtb-input mtb-select" style="width:150px">
              <option value="" selected={f.value == ""}>Any</option>
              <option :for={s <- QuoteRequest.statuses()} value={s} selected={f.value == to_string(s)}>
                {QuoteRequest.status_label(s)}
              </option>
            </select>
          <% else %>
            <input
              type={if @filter_defs[f.field].input == :number, do: "number", else: "text"}
              name={"filters[#{f.id}][value]"}
              value={f.value}
              placeholder="value"
              class="mtb-input"
              style="width:170px"
            />
          <% end %>
          <button
            type="button"
            phx-click="remove_filter"
            phx-value-id={f.id}
            class="mtb-btn mtb-btn-ghost mtb-btn-sm mtb-btn-icon"
            title="Remove filter"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
      </form>

      <%!-- RESULTS --%>
      <p
        :if={@visible == []}
        class="mtb-card px-5 py-12 text-center text-sm"
        style="color:var(--mc-text-3)"
      >
        No quotes match.
      </p>

      <.table_view :if={@visible != [] and @view == "table"} scope={@current_scope} quotes={@visible} />
      <.cards_view :if={@visible != [] and @view == "cards"} scope={@current_scope} quotes={@visible} />
      <.list_view :if={@visible != [] and @view == "list"} scope={@current_scope} quotes={@visible} />

      <%!-- PAGING --%>
      <div
        :if={@filtered_count > 0}
        class="mt-4 flex items-center justify-between text-xs"
        style="color:var(--mc-text-3)"
      >
        <span class="font-mono">{page_range(@page, @page_count, @filtered_count)}</span>
        <div class="flex items-center gap-1.5">
          <button
            phx-click="page"
            phx-value-delta="-1"
            disabled={@page <= 1}
            class="mtb-btn mtb-btn-ghost mtb-btn-sm"
          >
            ← Prev
          </button>
          <span class="font-mono">{@page} / {@page_count}</span>
          <button
            phx-click="page"
            phx-value-delta="1"
            disabled={@page >= @page_count}
            class="mtb-btn mtb-btn-ghost mtb-btn-sm"
          >
            Next →
          </button>
        </div>
      </div>
    </Layouts.workspace>
    """
  end

  attr :scope, :map, required: true
  attr :quotes, :list, required: true

  defp table_view(assigns) do
    ~H"""
    <div class="mtb-card overflow-hidden">
      <table class="mtb-table">
        <thead>
          <tr style="border-bottom:1px solid var(--mc-border)">
            <th
              :for={h <- ~w(Reference Customer Route Dates Pax Total Status Created)}
              class="px-4 py-3 text-left text-xs font-semibold"
              style="color:var(--mc-text-3)"
            >
              {h}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={q <- @quotes} id={"quote-#{q.id}"} style="border-top:1px solid var(--mc-border)">
            <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-brand)">
              <.ref_link scope={@scope} quote={q} />
            </td>
            <td class="px-4 py-3 align-middle text-sm font-medium" style="color:var(--mc-text)">
              {q.customer_name}
            </td>
            <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
              {q.route || "—"}
            </td>
            <td class="px-4 py-3 align-middle text-xs" style="color:var(--mc-text-2)">
              {q.travel_dates || "—"}
            </td>
            <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
              {q.pax || "—"}
            </td>
            <td class="px-4 py-3 align-middle text-right font-mono text-sm">{format_total(q)}</td>
            <td class="px-4 py-3 align-middle"><.quote_status_badge status={q.status} /></td>
            <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-3)">
              {format_datetime(q.inserted_at)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :scope, :map, required: true
  attr :quotes, :list, required: true

  defp cards_view(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <div :for={q <- @quotes} id={"quote-#{q.id}"} class="mtb-card flex flex-col gap-3 p-5">
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <div class="font-mono text-xs" style="color:var(--mc-brand)">
              <.ref_link scope={@scope} quote={q} />
            </div>
            <div class="mt-1.5 truncate text-sm font-semibold" style="color:var(--mc-text)">
              {q.customer_name}
            </div>
            <div class="mt-1 truncate font-mono text-xs" style="color:var(--mc-text-2)">
              {q.route || "—"} · {q.pax || "—"}
            </div>
          </div>
          <.quote_status_badge status={q.status} />
        </div>
        <div class="text-xs" style="color:var(--mc-text-3)">
          {q.travel_dates || "—"} · created {format_datetime(q.inserted_at)}
        </div>
        <div
          class="flex items-center justify-between border-t pt-3"
          style="border-color:var(--mc-border)"
        >
          <span class="font-mono text-base font-semibold" style="color:var(--mc-text)">{format_total(
            q
          )}</span>
        </div>
      </div>
    </div>
    """
  end

  attr :scope, :map, required: true
  attr :quotes, :list, required: true

  defp list_view(assigns) do
    ~H"""
    <div class="mtb-card divide-y overflow-hidden" style="border-color:var(--mc-border)">
      <div
        :for={q <- @quotes}
        id={"quote-#{q.id}"}
        class="flex items-center gap-3 px-4 py-3"
        style="border-color:var(--mc-border)"
      >
        <span class="w-[78px] flex-shrink-0 font-mono text-xs" style="color:var(--mc-brand)">
          <.ref_link scope={@scope} quote={q} />
        </span>
        <div class="min-w-0 flex-1">
          <div class="truncate text-sm font-semibold" style="color:var(--mc-text)">
            {q.customer_name}
          </div>
          <div class="truncate font-mono text-[11px]" style="color:var(--mc-text-3)">
            {q.route || "—"} · {q.travel_dates || "—"}
          </div>
        </div>
        <span class="w-[90px] text-right font-mono text-sm">{format_total(q)}</span>
        <span class="w-[110px]"><.quote_status_badge status={q.status} /></span>
      </div>
    </div>
    """
  end

  attr :scope, :map, required: true
  attr :quote, :any, required: true

  defp ref_link(assigns) do
    ~H"""
    <.link
      :if={can?(@scope, "quote:read")}
      navigate={~p"/app/quotes/#{@quote.id}"}
      class="no-underline hover:underline"
      style="color:var(--mc-brand)"
    >
      {@quote.reference}
    </.link>
    <span :if={not can?(@scope, "quote:read")}>{@quote.reference}</span>
    """
  end

  # ── Events ─────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, socket |> assign(query: query, page: 1) |> recompute()}
  end

  def handle_event("set_view", %{"view" => view}, socket) when view in ~w(table cards list) do
    {:noreply, assign(socket, view: view)}
  end

  def handle_event("sort", %{"field" => field, "dir" => dir}, socket)
      when is_map_key(@sort_defs, field) and dir in ~w(asc desc) do
    {:noreply, socket |> assign(sort_field: field, sort_dir: dir, page: 1) |> recompute()}
  end

  def handle_event("add_filter", _params, socket) do
    id = socket.assigns.next_filter_id
    filter = %{id: id, field: "status", op: "is", value: ""}

    {:noreply,
     assign(socket, filters: socket.assigns.filters ++ [filter], next_filter_id: id + 1)}
  end

  def handle_event("remove_filter", %{"id" => id}, socket) do
    id = String.to_integer(id)
    filters = Enum.reject(socket.assigns.filters, &(&1.id == id))
    {:noreply, socket |> assign(filters: filters, page: 1) |> recompute()}
  end

  def handle_event("filters_changed", %{"filters" => params}, socket) do
    filters =
      Enum.map(socket.assigns.filters, fn f ->
        case params[to_string(f.id)] do
          %{} = row -> normalize_filter(f, row)
          _ -> f
        end
      end)

    {:noreply, socket |> assign(filters: filters, page: 1) |> recompute()}
  end

  def handle_event("page", %{"delta" => delta}, socket) do
    page = socket.assigns.page + String.to_integer(delta)
    {:noreply, socket |> assign(page: page) |> recompute()}
  end

  # Keep a filter row valid: when its field changes, reset op (and value) to that field's
  # first operator so the row never holds an operator the new field doesn't offer.
  defp normalize_filter(prev, %{"field" => field} = row) when is_map_key(@filter_defs, field) do
    ops = @filter_defs[field].ops

    if field != prev.field do
      %{prev | field: field, op: hd(ops), value: ""}
    else
      op = if row["op"] in ops, do: row["op"], else: hd(ops)
      %{prev | field: field, op: op, value: row["value"] || ""}
    end
  end

  defp normalize_filter(prev, _row), do: prev

  # ── Helpers ──────────────────────────────────────────────────────────────────────

  defp blank?(v), do: is_nil(v) or String.trim(to_string(v)) == ""

  defp to_status(v) do
    Enum.find(QuoteRequest.statuses(), &(to_string(&1) == v))
  end

  defp to_number(v) do
    case Float.parse(to_string(v)) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp sort_dir_label(field, dir) do
    case {field, dir} do
      {"created", "desc"} -> "Newest"
      {"created", "asc"} -> "Oldest"
      {"total", "asc"} -> "Low → High"
      {"total", "desc"} -> "High → Low"
      {_, "asc"} -> "A → Z"
      {_, "desc"} -> "Z → A"
    end
  end

  defp page_range(_page, _count, 0), do: "0 of 0"

  defp page_range(page, _count, total) do
    from = (page - 1) * @page_size + 1
    to = min(page * @page_size, total)
    "#{from}–#{to} of #{total}"
  end

  # Expose the static defs to the template via assigns.
  defp assign_defs(socket) do
    assign(socket,
      filter_defs: @filter_defs,
      filter_order: @filter_order,
      sort_labels: @sort_defs,
      sort_order: @sort_order
    )
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, assign_defs(socket)}
end
