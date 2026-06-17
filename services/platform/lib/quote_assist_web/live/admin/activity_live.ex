defmodule QuoteAssistWeb.Admin.ActivityLive do
  @moduledoc """
  Platform activity (`/admin/activity`) — a read-only view of the most recent
  `audit_logs` entries across every tenant and platform action.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Audit

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Activity", logs: Audit.list_recent(100))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="activity"
      breadcrumb="Activity"
    >
      <div class="mb-6">
        <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
          Platform
        </div>
        <h1
          class="mt-1.5 text-3xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          Activity
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          The most recent privileged actions and status changes across the platform.
        </p>
      </div>

      <div class="mtb-card overflow-hidden">
        <p :if={@logs == []} class="px-6 py-12 text-center text-sm" style="color:var(--mc-text-3)">
          No activity recorded yet.
        </p>
        <table :if={@logs != []} class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Action
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Actor
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Target
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                When
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={log <- @logs} style="border-top:1px solid var(--mc-border)">
              <td class="px-5 py-3 align-middle text-sm font-medium" style="color:var(--mc-text)">
                {action_label(log.action)}
              </td>
              <td class="px-4 py-3 align-middle">
                <span class="mtb-badge mtb-badge-neutral">{actor_label(log.actor_type)}</span>
              </td>
              <td class="px-4 py-3 align-middle text-sm" style="color:var(--mc-text-2)">
                {log.target_type || "—"}
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {format_datetime(log.inserted_at)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.admin>
    """
  end
end
