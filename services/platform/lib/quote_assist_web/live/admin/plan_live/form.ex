defmodule QuoteAssistWeb.Admin.PlanLive.Form do
  @moduledoc """
  Create / edit a plan on a dedicated page (`/admin/plans/new`, `/admin/plans/:id/edit`).
  Plans carry more than three fields (name, slug, price, interval, four limits, active), so
  the form lives on its own page rather than a modal. The slug auto-fills from the name on
  create until edited. Gated by `plan:create` / `plan:update`; saves are audited.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Plans
  alias QuoteAssist.Plans.Plan
  alias QuoteAssist.Slug
  alias QuoteAssistWeb.AdminAuth

  @impl true
  def mount(params, _session, socket) do
    permission = if Map.has_key?(params, "id"), do: "plan:update", else: "plan:create"

    case AdminAuth.authorize(socket, permission) do
      {:cont, socket} -> {:ok, prepare(socket, params)}
      {:halt, socket} -> {:ok, socket}
    end
  end

  defp prepare(socket, %{"id" => id}) do
    case Plans.get_plan(id) do
      %Plan{} = plan ->
        socket
        |> assign(action: :edit, plan: plan, slug_auto: false, slug_last: plan.slug)
        |> assign_form(Plans.change_plan_update(plan))

      nil ->
        socket
        |> put_flash(:error, "That plan no longer exists.")
        |> redirect(to: ~p"/admin/plans")
    end
  end

  defp prepare(socket, _params) do
    socket
    |> assign(action: :new, plan: %Plan{}, slug_auto: true, slug_last: "")
    |> assign_form(Plans.change_plan())
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_admin={@current_admin} active="plans" breadcrumb="Plans">
      <.link
        navigate={~p"/admin/plans"}
        class="mb-4 inline-flex items-center gap-1.5 text-sm"
        style="color:var(--mc-text-2)"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to plans
      </.link>

      <h1
        class="mb-6 text-3xl font-bold tracking-tight"
        style="font-family:var(--font-display);color:var(--mc-text)"
      >
        {if @action == :new, do: "New plan", else: "Edit plan"}
      </h1>

      <.form for={@form} id="plan-form" phx-change="validate" phx-submit="save" class="max-w-2xl">
        <div class="mtb-card space-y-1 p-6">
          <.input field={@form[:name]} type="text" label="Plan name" placeholder="Growth" />
          <.input
            :if={@action == :new}
            field={@form[:slug]}
            type="text"
            label="Slug"
            placeholder="growth"
          />
          <div :if={@action == :edit}>
            <label class="mtb-label">Slug</label>
            <p class="font-mono text-sm" style="color:var(--mc-text-3)">{@plan.slug}</p>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <.input field={@form[:price]} type="number" label="Price (paise) — 0 = free" />
            <.input
              field={@form[:interval]}
              type="select"
              label="Billing interval"
              options={[{"Monthly", :monthly}, {"Yearly", :yearly}]}
            />
          </div>

          <% limits = current_limits(@form) %>
          <div class="grid grid-cols-3 gap-3">
            <label class="block text-sm">
              <span style="color:var(--mc-text-2)">Quotes / mo</span>
              <input
                type="number"
                name="plan[limits][quotes_per_month]"
                value={Map.get(limits, "quotes_per_month")}
                min="0"
                class="mtb-input mt-1 w-full"
              />
            </label>
            <label class="block text-sm">
              <span style="color:var(--mc-text-2)">Seats</span>
              <input
                type="number"
                name="plan[limits][seats]"
                value={Map.get(limits, "seats")}
                min="0"
                class="mtb-input mt-1 w-full"
              />
            </label>
            <label class="block text-sm">
              <span style="color:var(--mc-text-2)">AI / mo</span>
              <input
                type="number"
                name="plan[limits][ai_generations_per_month]"
                value={Map.get(limits, "ai_generations_per_month")}
                min="0"
                class="mtb-input mt-1 w-full"
              />
            </label>
          </div>

          <label class="flex items-center gap-2 py-1 text-sm" style="color:var(--mc-text-2)">
            <input type="hidden" name="plan[limits][custom_domain]" value="false" />
            <input
              type="checkbox"
              name="plan[limits][custom_domain]"
              value="true"
              checked={truthy?(Map.get(limits, "custom_domain"))}
            /> Custom domain allowed
          </label>
          <.input field={@form[:active]} type="checkbox" label="Offerable to new tenants (active)" />
        </div>

        <div class="mt-5 flex items-center gap-2">
          <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
            {if @action == :new, do: "Create plan", else: "Save changes"}
          </.button>
          <.link navigate={~p"/admin/plans"} class="mtb-btn mtb-btn-ghost mtb-btn-sm">Cancel</.link>
        </div>
      </.form>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("validate", %{"plan" => params}, socket) do
    {params, slug_auto, slug_last} = apply_slug(params, socket)

    changeset =
      socket
      |> changeset_for(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket |> assign(slug_auto: slug_auto, slug_last: slug_last) |> assign_form(changeset)}
  end

  def handle_event("save", %{"plan" => params}, socket) do
    result =
      case socket.assigns.action do
        :new ->
          Plans.admin_create_plan(socket.assigns.current_admin, params)

        :edit ->
          Plans.admin_update_plan(socket.assigns.current_admin, socket.assigns.plan, params)
      end

    case result do
      {:ok, plan} ->
        {:noreply,
         socket |> put_flash(:info, "#{plan.name} saved.") |> redirect(to: ~p"/admin/plans")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp changeset_for(%{assigns: %{action: :new}}, params), do: Plans.change_plan(%Plan{}, params)

  defp changeset_for(%{assigns: %{action: :edit, plan: plan}}, params),
    do: Plans.change_plan_update(plan, params)

  # Slug auto-fill applies only on create (the edit form has no slug field).
  defp apply_slug(params, %{assigns: %{action: :new}} = socket) do
    {slug, auto?, last} =
      Slug.auto(
        params["name"] || "",
        params["slug"] || "",
        socket.assigns.slug_last,
        socket.assigns.slug_auto
      )

    {Map.put(params, "slug", slug), auto?, last}
  end

  defp apply_slug(params, socket),
    do: {params, socket.assigns.slug_auto, socket.assigns.slug_last}

  defp current_limits(form) do
    case form[:limits].value do
      limits when is_map(limits) -> Map.new(limits, fn {k, v} -> {to_string(k), v} end)
      _ -> %{}
    end
  end

  defp truthy?(value) when value in [true, "true", "on", "1", 1], do: true
  defp truthy?(_), do: false
end
