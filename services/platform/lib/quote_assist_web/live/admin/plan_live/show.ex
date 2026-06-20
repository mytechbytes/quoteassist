defmodule QuoteAssistWeb.Admin.PlanLive.Show do
  @moduledoc """
  Plan detail (`/admin/plans/:id`): attributes plus the live tenants on the plan.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Plans
  alias QuoteAssist.Tenants

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case QuoteAssistWeb.AdminAuth.authorize(socket, "plan:read") do
      {:cont, socket} -> {:ok, load(socket, id)}
      {:halt, socket} -> {:ok, socket}
    end
  end

  defp load(socket, id) do
    case Plans.get_plan(id) do
      nil ->
        socket
        |> put_flash(:error, "That plan no longer exists.")
        |> push_navigate(to: ~p"/admin/plans")

      plan ->
        assign(socket,
          page_title: plan.name,
          plan: plan,
          tenants: Tenants.list_tenants_for_plan(plan.id),
          logs: Audit.list_for_target("plan", plan.id)
        )
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
            Price ({@plan.interval})
          </div>
          <div class="mt-1.5 font-mono text-3xl font-bold" style="color:var(--mc-text)">
            {price_label(@plan)}
          </div>
        </div>
        <div class="mtb-kpi">
          <div class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
            Status
          </div>
          <div class="mt-1.5 font-mono text-3xl font-bold" style="color:var(--mc-text)">
            {if @plan.active, do: "Active", else: "Inactive"}
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

      <div class="mb-6 mtb-card overflow-hidden">
        <div
          class="px-6 py-4 font-semibold"
          style="font-family:var(--font-display);border-bottom:1px solid var(--mc-border)"
        >
          Feature limits
        </div>
        <dl class="grid grid-cols-2 gap-px lg:grid-cols-4" style="background:var(--mc-border)">
          <.limit label="Quotes / month" value={limit_value(@plan, "quotes_per_month")} />
          <.limit label="Seats" value={limit_value(@plan, "seats")} />
          <.limit label="AI / month" value={limit_value(@plan, "ai_generations_per_month")} />
          <.limit
            label="Custom domain"
            value={if truthy?(limit_value(@plan, "custom_domain")), do: "Yes", else: "No"}
          />
        </dl>
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

      <div class="mt-6 mtb-card p-6">
        <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
        <.audit_timeline logs={@logs} empty="No activity for this plan yet." />
      </div>
    </Layouts.admin>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp limit(assigns) do
    ~H"""
    <div class="px-6 py-4" style="background:var(--mc-surface)">
      <div class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
        {@label}
      </div>
      <div class="mt-1 font-mono text-lg font-bold" style="color:var(--mc-text)">{@value}</div>
    </div>
    """
  end

  defp price_label(%{price: price}) when price in [0, nil], do: "Free"

  defp price_label(%{price: price}) when is_integer(price) do
    "₹#{:erlang.float_to_binary(price / 100, decimals: 2)}"
  end

  defp limit_value(%{limits: limits}, key) when is_map(limits), do: Map.get(limits, key, "—")
  defp limit_value(_plan, _key), do: "—"

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false
end
