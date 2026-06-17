defmodule QuoteAssistWeb.Admin.PlanLive.Index do
  @moduledoc """
  Plan catalog (`/admin/plans`): list plans with the number of tenants on each, and
  create/edit them (audited). Plan detail lives in `Admin.PlanLive.Show`.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Plans
  alias QuoteAssist.Plans.Plan
  alias QuoteAssist.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Plans", modal: nil, form: nil) |> load()}
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
        <button id="new-plan" phx-click="new" class="mtb-btn mtb-btn-primary mtb-btn-sm">
          <.icon name="hero-plus" class="size-4" /> New plan
        </button>
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
                ${plan.monthly_price}/mo
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {plan.seat_limit}
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {Map.get(@counts, plan.id, 0)}
              </td>
              <td class="px-4 py-3 align-middle text-right">
                <button
                  phx-click="edit"
                  phx-value-id={plan.id}
                  class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                >
                  Edit
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.plan_modal :if={@modal != nil} form={@form} modal={@modal} />
    </Layouts.admin>
    """
  end

  attr :form, :any, required: true
  attr :modal, :any, required: true

  defp plan_modal(assigns) do
    assigns = assign(assigns, :new?, assigns.modal == :new)

    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:480px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            {if @new?, do: "New plan", else: "Edit plan"}
          </div>
          <button
            type="button"
            phx-click="close_modal"
            class="mtb-btn mtb-btn-sm mtb-btn-icon mtb-btn-ghost"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
        <.form for={@form} id="plan-form" phx-change="validate" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <.input field={@form[:name]} type="text" label="Plan name" placeholder="Growth" />
            <.input :if={@new?} field={@form[:slug]} type="text" label="Slug" placeholder="growth" />
            <.input field={@form[:monthly_price]} type="number" label="Monthly price ($)" />
            <.input field={@form[:seat_limit]} type="number" label="Seat limit" />
          </div>
          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
              {if @new?, do: "Create plan", else: "Save changes"}
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, modal: :new, form: to_form(Plans.change_plan()))}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case Plans.get_plan(id) do
      nil ->
        {:noreply, missing(socket)}

      plan ->
        {:noreply,
         assign(socket, modal: {:edit, plan}, form: to_form(Plans.change_plan_update(plan)))}
    end
  end

  def handle_event("validate", %{"plan" => params}, socket) do
    changeset =
      case socket.assigns.modal do
        :new -> Plans.change_plan(%Plan{}, params)
        {:edit, plan} -> Plans.change_plan_update(plan, params)
      end

    {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save", %{"plan" => params}, socket) do
    result =
      case socket.assigns.modal do
        :new -> Plans.admin_create_plan(socket.assigns.current_admin, params)
        {:edit, plan} -> Plans.admin_update_plan(socket.assigns.current_admin, plan, params)
      end

    case result do
      {:ok, plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{plan.name} saved.")
         |> assign(modal: nil, form: nil)
         |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  defp missing(socket) do
    socket
    |> put_flash(:error, "That plan no longer exists.")
    |> assign(modal: nil, form: nil)
    |> load()
  end
end
