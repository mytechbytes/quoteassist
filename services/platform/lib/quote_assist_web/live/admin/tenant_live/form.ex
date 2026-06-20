defmodule QuoteAssistWeb.Admin.TenantLive.Form do
  @moduledoc """
  Create / edit an agency on a dedicated page (`/admin/tenants/new`,
  `/admin/tenants/:id/edit`). The create form carries more than three fields (name, slug,
  owner email, plan), so it lives on its own page. Create runs the `Ecto.Multi` (tenant +
  owner + membership + 15-day trial + invite email + audit); edit changes name + plan. The
  slug auto-fills from the name on create until edited. Gated by `tenant:create` /
  `tenant:update`.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Plans
  alias QuoteAssist.Slug
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Tenant
  alias QuoteAssistWeb.AdminAuth

  @impl true
  def mount(params, _session, socket) do
    socket = assign(socket, plans: Plans.list_plans())
    permission = if Map.has_key?(params, "id"), do: "tenant:update", else: "tenant:create"

    case AdminAuth.authorize(socket, permission) do
      {:cont, socket} -> {:ok, prepare(socket, params)}
      {:halt, socket} -> {:ok, socket}
    end
  end

  defp prepare(socket, %{"id" => id}) do
    case Tenants.get_tenant_for_admin(id) do
      %Tenant{} = tenant ->
        socket
        |> assign(action: :edit, tenant: tenant, slug_auto: false, slug_last: tenant.slug)
        |> assign_form(Tenants.change_tenant(tenant))

      nil ->
        socket
        |> put_flash(:error, "That agency no longer exists.")
        |> redirect(to: ~p"/admin/tenants")
    end
  end

  defp prepare(socket, _params) do
    socket
    |> assign(action: :new, tenant: %Tenant{}, slug_auto: true, slug_last: "")
    |> assign_form(Tenants.change_tenant_creation())
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="tenants"
      breadcrumb="Agencies"
    >
      <.link
        navigate={~p"/admin/tenants"}
        class="mb-4 inline-flex items-center gap-1.5 text-sm"
        style="color:var(--mc-text-2)"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to agencies
      </.link>

      <h1
        class="mb-2 text-3xl font-bold tracking-tight"
        style="font-family:var(--font-display);color:var(--mc-text)"
      >
        {if @action == :new, do: "New agency", else: "Edit agency"}
      </h1>
      <p class="mb-6 text-sm" style="color:var(--mc-text-2)">
        {if @action == :new,
          do: "Onboard a new tenant. The owner gets an email invite to set up access.",
          else: "Update the agency name and plan."}
      </p>

      <.form for={@form} id="tenant-form" phx-change="validate" phx-submit="save" class="max-w-xl">
        <div class="mtb-card space-y-1 p-6">
          <.input field={@form[:name]} type="text" label="Agency name" placeholder="Acme Travel" />
          <.input
            :if={@action == :new}
            field={@form[:slug]}
            type="text"
            label="Subdomain (slug)"
            placeholder="acme"
          />
          <.input
            :if={@action == :new}
            field={@form[:owner_email]}
            type="email"
            label="Owner email"
            placeholder="owner@acme.com"
          />
          <.input
            field={@form[:plan_id]}
            type="select"
            label="Plan"
            prompt="Select a plan"
            options={plan_options(@plans)}
          />
        </div>

        <div class="mt-5 flex items-center gap-2">
          <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
            {if @action == :new, do: "Create agency", else: "Save changes"}
          </.button>
          <.link navigate={~p"/admin/tenants"} class="mtb-btn mtb-btn-ghost mtb-btn-sm">Cancel</.link>
        </div>
      </.form>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("validate", %{"tenant" => params}, socket) do
    {params, slug_auto, slug_last} = apply_slug(params, socket)

    changeset =
      socket
      |> changeset_for(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket |> assign(slug_auto: slug_auto, slug_last: slug_last) |> assign_form(changeset)}
  end

  def handle_event("save", %{"tenant" => params}, socket) do
    case socket.assigns.action do
      :new -> create(socket, params)
      :edit -> update(socket, params)
    end
  end

  defp create(socket, params) do
    case Tenants.create_tenant_with_owner(socket.assigns.current_admin, params) do
      {:ok, tenant} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{tenant.name} created — an invite was emailed to the owner.")
         |> redirect(to: ~p"/admin/tenants")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp update(socket, params) do
    case Tenants.update_tenant(socket.assigns.current_admin, socket.assigns.tenant, params) do
      {:ok, tenant} ->
        {:noreply,
         socket |> put_flash(:info, "#{tenant.name} updated.") |> redirect(to: ~p"/admin/tenants")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp changeset_for(%{assigns: %{action: :new}}, params),
    do: Tenants.change_tenant_creation(params)

  defp changeset_for(%{assigns: %{action: :edit, tenant: tenant}}, params),
    do: Tenants.change_tenant(tenant, params)

  # Slug auto-fill applies only on create (the edit form has no slug field — slug is identity).
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

  defp plan_options(plans), do: Enum.map(plans, fn plan -> {plan.name, plan.id} end)
end
