defmodule QuoteAssistWeb.AppHomeLive do
  @moduledoc """
  Tenant workspace landing (`/app`) — the post-login dashboard, ported to the
  `designs/dashboard.html` layout with **real data** (R8-dashboard, re-ported post-R12):
  KPI tiles, a recent-quotes table, and an enquiry queue of open leads, plus a
  tenant-scoped recent-activity feed and quick links. The mock "drafted vs sent" chart
  from the design is intentionally omitted — there's no historical series to back it.

  Everything respects the signed-in member's permissions (owners see all — computed
  all-access): the quote KPIs, recent-quotes table, and enquiry queue are gated by
  `quote:list`; the team KPI + Team link by `user:list`; the Roles link by `role:list`.
  Activity, Requests, and Account are always available (tenant-scoped / baseline).

  Reads only — no writes, no new tables. Guarded by `on_mount :require_tenant_member`, so
  `current_scope` always carries a tenant, membership, and permissions.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Quotes

  @activity_limit 8
  @recent_limit 6
  @queue_limit 5

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    can_quotes? = can?(scope, "quote:list")

    {:ok,
     socket
     |> assign(
       page_title: "Overview",
       stats: Quotes.dashboard_stats(scope),
       team_size: QuoteAssist.Tenants.active_member_count(scope.tenant),
       recent: recent_quotes(scope, can_quotes?),
       queue: open_leads(scope, can_quotes?),
       activity: Audit.list_for_tenant(scope.tenant.id, @activity_limit)
     )}
  end

  defp recent_quotes(scope, true), do: Quotes.list_quote_requests(scope, limit: @recent_limit)
  defp recent_quotes(_scope, false), do: []

  defp open_leads(scope, true),
    do: Quotes.list_quote_requests(scope, status: :new, limit: @queue_limit)

  defp open_leads(_scope, false), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} active="overview">
      <div
        :if={is_nil(@current_scope.user.hashed_password)}
        class="mtb-card mb-6 flex items-start gap-3 px-5 py-4"
        style="border-color:color-mix(in oklch,var(--mc-warning) 40%,transparent);background:color-mix(in oklch,var(--mc-warning) 10%,var(--mc-surface))"
      >
        <.icon name="hero-sparkles" class="mt-0.5 size-5 shrink-0" style="color:var(--mc-warning)" />
        <div class="min-w-0 flex-1">
          <p class="text-sm font-semibold" style="color:var(--mc-text)">
            Finish setting up your account
          </p>
          <p class="mt-0.5 text-sm" style="color:var(--mc-text-2)">
            Set your name and a password so you can sign in without a magic link.
          </p>
          <.link navigate={~p"/app/welcome"} class="mtb-btn mtb-btn-primary mtb-btn-sm mt-3">
            Set up account <span aria-hidden="true">→</span>
          </.link>
        </div>
      </div>

      <div class="mb-7 flex flex-wrap items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Workspace · Overview
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            {greeting(@current_scope)}
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Here's what's happening across {@current_scope.tenant.name}.
          </p>
        </div>
        <.link
          :if={can?(@current_scope, "quote:create")}
          navigate={~p"/app/quotes/new"}
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
        >
          <.icon name="hero-plus" class="size-4" /> New quote
        </.link>
      </div>

      <%!-- KPI TILES — each gated by the permission that owns its data. --%>
      <div class="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <.kpi
          :if={can?(@current_scope, "quote:list")}
          key="open-requests"
          icon="hero-document-text"
          label="Open requests"
          value={@stats.open}
        />
        <.kpi
          :if={can?(@current_scope, "quote:list")}
          key="quoted-this-month"
          icon="hero-check-circle"
          label="Quoted · this month"
          value={@stats.quoted_this_month}
        />
        <.kpi
          :if={can?(@current_scope, "quote:list")}
          key="total-quotes"
          icon="hero-inbox-stack"
          label="Total quotes"
          value={@stats.total}
        />
        <.kpi
          :if={can?(@current_scope, "user:list")}
          key="team-size"
          icon="hero-users"
          label="Team"
          value={@team_size}
        />
      </div>

      <%!-- RECENT QUOTES + ENQUIRY QUEUE (gated by quote:list). --%>
      <div
        :if={can?(@current_scope, "quote:list")}
        class="mb-6 grid grid-cols-1 gap-4 lg:grid-cols-[1.6fr_1fr]"
      >
        <.recent_quotes scope={@current_scope} quotes={@recent} />
        <.enquiry_queue queue={@queue} open_count={@stats.open} />
      </div>

      <%!-- RECENT ACTIVITY + QUICK LINKS. --%>
      <div class="grid grid-cols-1 gap-4 lg:grid-cols-[1.5fr_1fr]">
        <div class="mtb-card overflow-hidden">
          <div class="px-6 pb-2 pt-5">
            <div class="font-semibold" style="font-family:var(--font-display);color:var(--mc-text)">
              Recent activity
            </div>
            <div class="text-xs" style="color:var(--mc-text-3)">
              The latest changes across your workspace.
            </div>
          </div>
          <div class="px-6 pb-5 pt-3">
            <.audit_timeline
              logs={@activity}
              empty="No activity yet — it'll show up here as your team works."
            />
          </div>
        </div>

        <div class="mtb-card px-6 py-5">
          <div class="mb-3 text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Quick links
          </div>
          <div class="flex flex-col gap-1">
            <.quick_link
              :if={can?(@current_scope, "quote:list")}
              href={~p"/app/quotes"}
              icon="hero-document-text"
              label="Quote requests"
            />
            <.quick_link
              :if={can?(@current_scope, "user:list")}
              href={~p"/app/team"}
              icon="hero-users"
              label="Team & access"
            />
            <.quick_link
              :if={can?(@current_scope, "role:list")}
              href={~p"/app/roles"}
              icon="hero-key"
              label="Roles & permissions"
            />
            <.quick_link href={~p"/app/requests"} icon="hero-inbox" label="Requests" />
            <.quick_link href={~p"/app/account"} icon="hero-user-circle" label="Your account" />
          </div>
        </div>
      </div>
    </Layouts.workspace>
    """
  end

  attr :key, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp kpi(assigns) do
    ~H"""
    <div class="mtb-card p-5" data-stat={@key}>
      <div class="flex items-center gap-2 text-xs font-semibold" style="color:var(--mc-text-3)">
        <.icon name={@icon} class="size-4" />
        <span class="uppercase tracking-widest">{@label}</span>
      </div>
      <div class="mt-2 font-mono text-3xl font-bold tracking-tight" style="color:var(--mc-text)">
        {@value}
      </div>
    </div>
    """
  end

  attr :scope, :map, required: true
  attr :quotes, :list, required: true

  defp recent_quotes(assigns) do
    ~H"""
    <div class="mtb-card overflow-hidden">
      <div
        class="flex items-end justify-between px-5 py-4"
        style="border-bottom:1px solid var(--mc-border)"
      >
        <div>
          <div class="font-semibold" style="font-family:var(--font-display);color:var(--mc-text)">
            Recent quotes
          </div>
          <div class="text-xs" style="color:var(--mc-text-3)">Your latest enquiries and quotes.</div>
        </div>
        <.link navigate={~p"/app/quotes"} class="mtb-btn mtb-btn-ghost mtb-btn-sm">View all →</.link>
      </div>

      <div :if={@quotes == []} class="px-5 py-12 text-center">
        <p class="text-sm" style="color:var(--mc-text-3)">No quote requests yet.</p>
        <.link
          :if={can?(@scope, "quote:create")}
          navigate={~p"/app/quotes/new"}
          class="mtb-btn mtb-btn-primary mtb-btn-sm mt-3"
        >
          Capture your first lead <span aria-hidden="true">→</span>
        </.link>
      </div>

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
          <tr :for={q <- @quotes} style="border-top:1px solid var(--mc-border)">
            <td class="px-5 py-3 align-middle">
              <.link
                :if={can?(@scope, "quote:read")}
                navigate={~p"/app/quotes/#{q.id}"}
                class="text-sm font-semibold no-underline hover:underline"
                style="color:var(--mc-text)"
              >
                {q.customer_name}
              </.link>
              <span
                :if={not can?(@scope, "quote:read")}
                class="text-sm font-semibold"
                style="color:var(--mc-text)"
              >
                {q.customer_name}
              </span>
            </td>
            <td class="px-4 py-3 align-middle text-sm" style="color:var(--mc-text-2)">{q.subject}</td>
            <td class="px-4 py-3 align-middle"><.quote_status_badge status={q.status} /></td>
            <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-3)">
              {format_datetime(q.updated_at)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :queue, :list, required: true
  attr :open_count, :integer, required: true

  defp enquiry_queue(assigns) do
    ~H"""
    <div class="mtb-card p-6">
      <div class="mb-4 flex items-center justify-between">
        <div class="font-semibold" style="font-family:var(--font-display);color:var(--mc-text)">
          Enquiry queue
        </div>
        <span class="mtb-badge mtb-badge-brand font-mono">{@open_count} open</span>
      </div>

      <p :if={@queue == []} class="text-sm" style="color:var(--mc-text-3)">
        No open enquiries — you're all caught up.
      </p>

      <div :if={@queue != []} class="space-y-3">
        <.link
          :for={lead <- @queue}
          navigate={~p"/app/quotes/#{lead.id}"}
          class="flex items-start gap-3 no-underline"
          style="color:inherit"
        >
          <div
            class="grid size-8 flex-shrink-0 place-items-center rounded-full text-xs font-bold text-white"
            style="background:linear-gradient(135deg, var(--mc-grad-1), var(--mc-grad-2))"
          >
            {initials(lead.customer_name)}
          </div>
          <div class="min-w-0 flex-1 text-sm leading-snug">
            <span class="font-semibold" style="color:var(--mc-text)">{lead.customer_name}</span>
            <span style="color:var(--mc-text-2)"> · {lead.subject}</span>
            <div class="mt-0.5 font-mono text-[11px]" style="color:var(--mc-text-3)">
              {format_datetime(lead.inserted_at)}
            </div>
          </div>
          <span class="mtb-status mtb-status-build mt-1 text-[10px]">New</span>
        </.link>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp quick_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="flex items-center gap-3 rounded-lg px-2.5 py-2 text-sm font-medium no-underline transition-colors hover:bg-[var(--mc-surface-2)]"
      style="color:var(--mc-text)"
    >
      <.icon name={@icon} class="size-[17px]" style="color:var(--mc-text-3)" />
      <span>{@label}</span>
      <.icon name="hero-chevron-right-micro" class="ml-auto size-3.5" style="color:var(--mc-text-3)" />
    </.link>
    """
  end

  # A name-aware greeting for the header. The scope carries the user directly (the
  # membership's `:user` isn't preloaded), so read from there: display name, else the
  # email local part.
  defp greeting(%{user: user}) do
    name =
      case user.display_name do
        n when is_binary(n) and n != "" -> n
        _ -> user.email |> String.split("@") |> List.first()
      end

    "Welcome back, #{name}."
  end

  # Two-letter monogram for the enquiry-queue avatar (initials of the customer name).
  defp initials(name) when is_binary(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
    |> case do
      "" -> "?"
      monogram -> monogram
    end
  end

  defp initials(_name), do: "?"
end
