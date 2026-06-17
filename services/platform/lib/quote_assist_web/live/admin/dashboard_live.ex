defmodule QuoteAssistWeb.Admin.DashboardLive do
  @moduledoc """
  Admin console landing (`/admin`) — a minimal platform overview: tenant counts by
  status and the most recent tenants. Tenant management lives in
  `QuoteAssistWeb.Admin.TenantLive.Index`; self-registration review arrives in R4.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Tenants

  @impl true
  def mount(_params, _session, socket) do
    tenants = Tenants.list_tenants_for_admin()

    {:ok,
     assign(socket,
       page_title: "Admin overview",
       tenants: tenants,
       counts: counts(tenants)
     )}
  end

  defp counts(tenants) do
    by_status = Enum.frequencies_by(tenants, & &1.status)

    %{
      total: length(tenants),
      active: Map.get(by_status, :active, 0),
      trial: Map.get(by_status, :trial, 0),
      suspended: Map.get(by_status, :suspended, 0)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="overview"
      breadcrumb="Overview"
    >
      <div class="mb-7 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Platform · Overview
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Platform overview
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Every agency on QuoteAssist, and the state of their trials.
          </p>
        </div>
        <.link navigate={~p"/admin/tenants"} class="mtb-btn mtb-btn-primary mtb-btn-sm">
          <.icon name="hero-plus" class="size-4" /> New agency
        </.link>
      </div>

      <div class="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <.kpi label="Agencies" value={@counts.total} />
        <.kpi label="Active" value={@counts.active} />
        <.kpi label="On trial" value={@counts.trial} />
        <.kpi label="Suspended" value={@counts.suspended} />
      </div>

      <div class="mtb-card overflow-hidden">
        <div
          class="flex items-end justify-between px-5 py-4"
          style="border-bottom:1px solid var(--mc-border)"
        >
          <div>
            <div class="font-semibold" style="font-family:var(--font-display);color:var(--mc-text)">
              Recent agencies
            </div>
            <div class="text-xs" style="color:var(--mc-text-3)">Newest tenants and their status.</div>
          </div>
          <.link navigate={~p"/admin/tenants"} class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            All agencies →
          </.link>
        </div>

        <p :if={@tenants == []} class="px-5 py-12 text-center text-sm" style="color:var(--mc-text-3)">
          No agencies yet. Create the first from <.link
            navigate={~p"/admin/tenants"}
            class="font-semibold"
            style="color:var(--mc-brand)"
          >
            Agencies
          </.link>.
        </p>

        <table :if={@tenants != []} class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Agency
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Plan
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Trial ends
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Status
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={tenant <- Enum.take(@tenants, 5)}
              style="border-top:1px solid var(--mc-border)"
            >
              <td class="px-5 py-3 align-middle">
                <div class="text-sm font-semibold" style="color:var(--mc-text)">{tenant.name}</div>
                <div class="font-mono text-[11px]" style="color:var(--mc-text-3)">{tenant.slug}</div>
              </td>
              <td class="px-4 py-3 align-middle">
                <span class="mtb-badge mtb-badge-neutral">{plan_name(tenant)}</span>
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {trial_label(tenant)}
              </td>
              <td class="px-4 py-3 align-middle">
                <.status_badge status={tenant.status} />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.admin>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp kpi(assigns) do
    ~H"""
    <div class="mtb-kpi">
      <div class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
        {@label}
      </div>
      <div class="mt-1.5 font-mono text-3xl font-bold" style="color:var(--mc-text)">{@value}</div>
    </div>
    """
  end
end
