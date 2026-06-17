defmodule QuoteAssistWeb.Admin.PlanLive.Show do
  @moduledoc """
  Plan detail (`/admin/plans/:id`): attributes plus the live tenants on the plan.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Plans
  alias QuoteAssist.Tenants

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Plans.get_plan(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That plan no longer exists.")
         |> push_navigate(to: ~p"/admin/plans")}

      plan ->
        {:ok,
         assign(socket,
           page_title: plan.name,
           plan: plan,
           tenants: Tenants.list_tenants_for_plan(plan.id)
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="plans"
      breadcrumb={@plan.name}
    >
      <div class="mb-6">
        <.link
          navigate={~p"/admin/plans"}
          class="text-xs font-semibold"
          style="color:var(--mc-text-3)"
        >
          ← Plans
        </.link>
        <h1
          class="mt-1.5 text-3xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          {@plan.name}
        </h1>
        <div class="mt-1 font-mono text-sm" style="color:var(--mc-text-3)">{@plan.slug}</div>
      </div>

      <div class="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-3">
        <div class="mtb-kpi">
          <div class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
            Monthly price
          </div>
          <div class="mt-1.5 font-mono text-3xl font-bold" style="color:var(--mc-text)">
            ${@plan.monthly_price}
          </div>
        </div>
        <div class="mtb-kpi">
          <div class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
            Seat limit
          </div>
          <div class="mt-1.5 font-mono text-3xl font-bold" style="color:var(--mc-text)">
            {@plan.seat_limit}
          </div>
        </div>
        <div class="mtb-kpi">
          <div class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
            Tenants
          </div>
          <div class="mt-1.5 font-mono text-3xl font-bold" style="color:var(--mc-text)">
            {length(@tenants)}
          </div>
        </div>
      </div>

      <div class="mtb-card overflow-hidden">
        <div
          class="px-6 py-4 font-semibold"
          style="font-family:var(--font-display);border-bottom:1px solid var(--mc-border)"
        >
          Tenants on this plan
        </div>
        <p :if={@tenants == []} class="px-6 py-8 text-center text-sm" style="color:var(--mc-text-3)">
          No tenants are on this plan yet.
        </p>
        <table :if={@tenants != []} class="mtb-table">
          <tbody>
            <tr :for={tenant <- @tenants} style="border-top:1px solid var(--mc-border)">
              <td class="px-6 py-3 align-middle">
                <.link
                  navigate={~p"/admin/tenants/#{tenant.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {tenant.name}
                </.link>
                <div class="font-mono text-[11px]" style="color:var(--mc-text-3)">{tenant.slug}</div>
              </td>
              <td class="px-6 py-3 text-right align-middle">
                <.status_badge status={tenant.status} />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.admin>
    """
  end
end
