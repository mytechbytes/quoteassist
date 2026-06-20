defmodule QuoteAssistWeb.AppHomeLive do
  @moduledoc """
  Tenant workspace landing (`/app`) — the post-login dashboard (R8-dashboard). Fills the
  empty R2 shell with a real overview: stat cards (open quote requests, quoted this
  month, team size), a recent-activity feed from `audit_logs` (tenant-scoped), and quick
  links into Quotes / Team / Roles. Reads only — no new tables.

  Everything respects the signed-in member's permissions (owners see all — computed
  all-access): the quote cards are gated by `quote:list`, the team card + Team link by
  `user:list`, the Roles link by `role:list`; Requests and Account are always linked
  (`request:create` + `self:*` baselines).

  **Quote stats are placeholders until R11-quotes.** The `quote_requests` table doesn't
  exist yet, so open/quoted counts read `0` here and the section shows the brand-new-tenant
  empty state. R11 wires `dashboard_quote_stats/1` to the real table — no UI change.

  Guarded by `on_mount :require_tenant_member`, so `current_scope` always carries a
  tenant, membership, and permissions.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Tenants

  @activity_limit 8

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    quote_stats = dashboard_quote_stats(scope.tenant)

    {:ok,
     socket
     |> assign(
       page_title: "Overview",
       team_size: Tenants.active_member_count(scope.tenant),
       open_quotes: quote_stats.open,
       quoted_this_month: quote_stats.quoted_this_month,
       activity: Audit.list_for_tenant(scope.tenant.id, @activity_limit)
     )}
  end

  # Quote-request stats for the dashboard. The `quote_requests` table lands in
  # R11-quotes; until then every tenant has zero, which is exactly the empty-state we
  # render. R11 replaces this body with the real aggregate (open count + quoted-this-
  # month count) — the assigns and template stay the same.
  defp dashboard_quote_stats(_tenant), do: %{open: 0, quoted_this_month: 0}

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

      <div class="mb-7">
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

      <%!-- STAT CARDS — each gated by the permission that owns its data. --%>
      <div class="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-3">
        <.stat_card
          :if={can?(@current_scope, "quote:list")}
          key="open-requests"
          icon="hero-document-text"
          label="Open requests"
          value={@open_quotes}
        />
        <.stat_card
          :if={can?(@current_scope, "quote:list")}
          key="quoted-this-month"
          icon="hero-check-circle"
          label="Quoted this month"
          value={@quoted_this_month}
        />
        <.stat_card
          :if={can?(@current_scope, "user:list")}
          key="team-size"
          icon="hero-users"
          label="Team size"
          value={@team_size}
        />
      </div>

      <div class="grid grid-cols-1 gap-4 lg:grid-cols-[1.5fr_1fr]">
        <%!-- RECENT ACTIVITY — tenant-scoped audit feed. --%>
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

        <%!-- QUOTES EMPTY-STATE + QUICK LINKS. --%>
        <div class="space-y-4">
          <div
            :if={can?(@current_scope, "quote:list")}
            class="mtb-card flex flex-col items-start gap-2 px-6 py-6"
          >
            <div
              class="grid h-10 w-10 place-items-center rounded-xl"
              style="background:var(--mc-brand-soft);color:var(--mc-brand)"
            >
              <.icon name="hero-inbox-arrow-down" class="size-5" />
            </div>
            <div class="font-semibold" style="font-family:var(--font-display);color:var(--mc-text)">
              No quote requests yet
            </div>
            <p class="text-sm" style="color:var(--mc-text-2);line-height:1.5">
              Lead capture arrives in an upcoming release. Inbound enquiries will land here ready to quote.
            </p>
          </div>

          <div class="mtb-card px-6 py-5">
            <div
              class="mb-3 text-xs font-bold uppercase tracking-widest"
              style="color:var(--mc-text-3)"
            >
              Quick links
            </div>
            <div class="flex flex-col gap-1">
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
      </div>
    </Layouts.workspace>
    """
  end

  attr :key, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp stat_card(assigns) do
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
end
