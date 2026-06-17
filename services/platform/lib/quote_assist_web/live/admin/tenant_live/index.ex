defmodule QuoteAssistWeb.Admin.TenantLive.Index do
  @moduledoc """
  Admin tenant management (`/admin/tenants`): list every live tenant and create, edit,
  suspend, reactivate, or soft-delete them. Create runs an `Ecto.Multi` (tenant + owner
  + membership + 15-day trial + invite email + audit); status changes go through the
  guarded state machine; every action is audited (actor = admin). Modals are driven by
  LiveView assigns; client interactions use `Phoenix.LiveView.JS` only.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Plans
  alias QuoteAssist.Tenants

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Agencies", plans: Plans.list_plans(), modal: nil, form: nil)
     |> load_tenants()}
  end

  defp load_tenants(socket), do: assign(socket, :tenants, Tenants.list_tenants_for_admin())

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="tenants"
      breadcrumb="Agencies"
    >
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Platform
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Agencies
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Every tenant on QuoteAssist. Create agencies, change plans, suspend or remove.
          </p>
        </div>
        <button id="new-agency" phx-click="new" class="mtb-btn mtb-btn-primary mtb-btn-sm">
          <.icon name="hero-plus" class="size-4" /> New agency
        </button>
      </div>

      <div :if={@tenants == []} class="mtb-card px-6 py-14 text-center">
        <p class="text-sm font-semibold" style="color:var(--mc-text)">No agencies yet</p>
        <p class="mx-auto mt-1 max-w-sm text-sm" style="color:var(--mc-text-3)">
          Create the first agency to onboard an organisation onto QuoteAssist.
        </p>
        <button phx-click="new" class="mtb-btn mtb-btn-primary mtb-btn-sm mx-auto mt-4">
          <.icon name="hero-plus" class="size-4" /> New agency
        </button>
      </div>

      <div :if={@tenants != []} class="mtb-card overflow-hidden">
        <table class="mtb-table">
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
              <th class="px-4 py-3 text-right text-xs font-semibold" style="color:var(--mc-text-3)">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={tenant <- @tenants}
              id={"tenant-#{tenant.id}"}
              style="border-top:1px solid var(--mc-border)"
            >
              <td class="px-5 py-3 align-middle">
                <.link
                  navigate={~p"/admin/tenants/#{tenant.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {tenant.name}
                </.link>
                <div class="text-[11px]" style="color:var(--mc-text-3)">
                  <span class="font-mono">{tenant.slug}</span>
                  · {Tenants.owner_email(tenant) || "no owner"}
                </div>
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
              <td class="px-4 py-3 align-middle">
                <div class="flex items-center justify-end gap-1.5">
                  <button
                    phx-click="edit"
                    phx-value-id={tenant.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Edit
                  </button>
                  <button
                    :if={tenant.status in [:trial, :active]}
                    phx-click="transition"
                    phx-value-id={tenant.id}
                    phx-value-to="suspended"
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Suspend
                  </button>
                  <button
                    :if={tenant.status == :suspended}
                    phx-click="transition"
                    phx-value-id={tenant.id}
                    phx-value-to="active"
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Reactivate
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={tenant.id}
                    class="mtb-btn mtb-btn-danger-outline mtb-btn-sm"
                  >
                    Remove
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.new_or_edit_modal
        :if={@modal in [:new] or match?({:edit, _}, @modal)}
        form={@form}
        plans={@plans}
        modal={@modal}
      />
      <.delete_modal :if={match?({:delete, _}, @modal)} tenant={elem(@modal, 1)} />
    </Layouts.admin>
    """
  end

  attr :form, :any, required: true
  attr :plans, :list, required: true
  attr :modal, :any, required: true

  defp new_or_edit_modal(assigns) do
    assigns = assign(assigns, :new?, assigns.modal == :new)

    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:520px">
        <div class="mtb-modal-head">
          <div>
            <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
              {if @new?, do: "New agency", else: "Edit agency"}
            </div>
            <div class="mt-0.5 text-xs" style="color:var(--mc-text-3)">
              {if @new?,
                do: "Onboard a new tenant. The owner gets an email invite to set up access.",
                else: "Update the agency name and plan."}
            </div>
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

        <.form for={@form} id="tenant-form" phx-change="validate" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <.input field={@form[:name]} type="text" label="Agency name" placeholder="Acme Travel" />

            <.input
              :if={@new?}
              field={@form[:slug]}
              type="text"
              label="Subdomain (slug)"
              placeholder="acme"
            />

            <.input
              :if={@new?}
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

          <div class="mtb-modal-foot">
            <button
              type="button"
              phx-click="close_modal"
              class="mtb-btn mtb-btn-ghost mtb-btn-sm"
            >
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
              {if @new?, do: "Create agency", else: "Save changes"}
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :tenant, :any, required: true

  defp delete_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:460px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            Remove {@tenant.name}?
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
        <div class="mtb-modal-body">
          <p class="text-sm" style="color:var(--mc-text-2);line-height:1.55">
            This removes
            <span class="font-semibold" style="color:var(--mc-text)">{@tenant.name}</span>
            from QuoteAssist. The workspace stops resolving immediately. Quote history and
            the audit trail are preserved (a soft delete) — this is not a permanent purge.
          </p>
        </div>
        <div class="mtb-modal-foot">
          <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            Cancel
          </button>
          <button
            phx-click="confirm_delete"
            phx-value-id={@tenant.id}
            class="mtb-btn mtb-btn-danger mtb-btn-sm"
          >
            Remove agency
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("new", _params, socket) do
    {:noreply, assign(socket, modal: :new, form: to_form(Tenants.change_tenant_creation()))}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case Tenants.get_tenant_for_admin(id) do
      nil ->
        {:noreply, missing(socket)}

      tenant ->
        {:noreply,
         assign(socket, modal: {:edit, tenant}, form: to_form(Tenants.change_tenant(tenant)))}
    end
  end

  def handle_event("validate", %{"tenant" => params}, socket) do
    changeset =
      case socket.assigns.modal do
        :new -> Tenants.change_tenant_creation(params)
        {:edit, tenant} -> Tenants.change_tenant(tenant, params)
      end

    {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save", %{"tenant" => params}, socket) do
    case socket.assigns.modal do
      :new -> create_tenant(socket, params)
      {:edit, tenant} -> update_tenant(socket, tenant, params)
    end
  end

  def handle_event("transition", %{"id" => id, "to" => to}, socket) do
    # Map the incoming string to a known status — never String.to_existing_atom on
    # untrusted input. The state machine still rejects illegal jumps below.
    case {parse_status(to), Tenants.get_tenant_for_admin(id)} do
      {nil, _tenant} ->
        {:noreply, put_flash(socket, :error, "That status change isn't allowed.")}

      {_status, nil} ->
        {:noreply, missing(socket)}

      {status, tenant} ->
        case Tenants.transition_status(tenant, status, socket.assigns.current_admin) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "#{tenant.name} is now #{status}.")
             |> load_tenants()}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "That status change isn't allowed.")}
        end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Tenants.get_tenant_for_admin(id) do
      nil -> {:noreply, missing(socket)}
      tenant -> {:noreply, assign(socket, modal: {:delete, tenant})}
    end
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    case Tenants.get_tenant_for_admin(id) do
      nil ->
        {:noreply, missing(socket)}

      tenant ->
        {:ok, _deleted} = Tenants.soft_delete_tenant(socket.assigns.current_admin, tenant)

        {:noreply,
         socket
         |> put_flash(:info, "#{tenant.name} removed.")
         |> assign(modal: nil)
         |> load_tenants()}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  defp create_tenant(socket, params) do
    case Tenants.create_tenant_with_owner(socket.assigns.current_admin, params) do
      {:ok, tenant} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{tenant.name} created — an invite was emailed to the owner.")
         |> assign(modal: nil, form: nil)
         |> load_tenants()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp update_tenant(socket, tenant, params) do
    case Tenants.update_tenant(socket.assigns.current_admin, tenant, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{updated.name} updated.")
         |> assign(modal: nil, form: nil)
         |> load_tenants()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp missing(socket) do
    socket
    |> put_flash(:error, "That agency no longer exists.")
    |> assign(modal: nil, form: nil)
    |> load_tenants()
  end

  defp plan_options(plans), do: Enum.map(plans, fn plan -> {plan.name, plan.id} end)

  defp parse_status("active"), do: :active
  defp parse_status("suspended"), do: :suspended
  defp parse_status("cancelled"), do: :cancelled
  defp parse_status(_other), do: nil
end
