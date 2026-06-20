defmodule QuoteAssistWeb.Admin.PlanLive.Index do
  @moduledoc """
  Plan catalog (`/admin/plans`): list plans with the number of tenants on each, and link
  out to the dedicated create / edit pages (`Admin.PlanLive.Form`). Plan detail (with its
  activity feed) lives in `Admin.PlanLive.Show`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Plans
  alias QuoteAssist.Tenants

  @impl true
  def mount(_params, _session, socket) do
    case QuoteAssistWeb.AdminAuth.authorize(socket, "plan:list") do
      {:cont, socket} ->
        {:ok, socket |> assign(page_title: "Plans") |> load()}

      {:halt, socket} ->
        {:ok, socket}
    end
  end

  defp load(socket) do
    assign(socket, plans: Plans.list_plans(), counts: Tenants.tenant_count_by_plan())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_admin={@current_admin} active="plans" breadcrumb="Plans">
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Platform
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Plans
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Subscription plans agencies can be placed on.
          </p>
        </div>
        <.link
          :if={can?(@current_admin, "plan:create")}
          id="new-plan"
          navigate={~p"/admin/plans/new"}
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
        >
          <.icon name="hero-plus" class="size-4" /> New plan
        </.link>
      </div>

      <div class="mtb-card overflow-hidden">
        <table class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Plan
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Price
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Seats
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Status
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Tenants
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold" style="color:var(--mc-text-3)">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={plan <- @plans}
              id={"plan-#{plan.id}"}
              style="border-top:1px solid var(--mc-border)"
            >
              <td class="px-5 py-3 align-middle">
                <.link
                  navigate={~p"/admin/plans/#{plan.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {plan.name}
                </.link>
                <div class="font-mono text-[11px]" style="color:var(--mc-text-3)">{plan.slug}</div>
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {price_label(plan)}
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {limit_value(plan, "seats")}
              </td>
              <td class="px-4 py-3 align-middle">
                <span class={[
                  "mtb-badge",
                  if(plan.active, do: "mtb-badge-success", else: "mtb-badge-neutral")
                ]}>
                  {if plan.active, do: "Active", else: "Inactive"}
                </span>
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {Map.get(@counts, plan.id, 0)}
              </td>
              <td class="px-4 py-3 align-middle text-right">
                <.link
                  :if={can?(@current_admin, "plan:update")}
                  navigate={~p"/admin/plans/#{plan.id}/edit"}
                  class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                >
                  Edit
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.admin>
    """
  end

  defp price_label(%{price: price}) when price in [0, nil], do: "Free"

  defp price_label(%{price: price, interval: interval}) when is_integer(price) do
    "₹#{:erlang.float_to_binary(price / 100, decimals: 2)}/#{interval_suffix(interval)}"
  end

  defp interval_suffix(:yearly), do: "yr"
  defp interval_suffix(_), do: "mo"

  defp limit_value(%{limits: limits}, key) when is_map(limits), do: Map.get(limits, key, "—")
  defp limit_value(_plan, _key), do: "—"
end
