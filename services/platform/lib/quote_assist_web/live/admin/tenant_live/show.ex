defmodule QuoteAssistWeb.Admin.TenantLive.Show do
  @moduledoc """
  Tenant detail (`/admin/tenants/:id`): full profile (plan, status, trial, owner,
  members) plus an audit timeline, with the same admin actions as the index — edit,
  suspend/reactivate/cancel, and soft-delete — hosted on the page. Every action goes
  through the audited `Tenants` functions. Guarded by `on_mount :require_admin`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Plans
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Membership

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Tenants.get_tenant_for_admin(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That agency no longer exists.")
         |> push_navigate(to: ~p"/admin/tenants")}

      tenant ->
        {:ok,
         socket
         |> assign(plans: Plans.list_plans(), modal: nil, form: nil)
         |> load(tenant)}
    end
  end

  defp load(socket, tenant) do
    assign(socket,
      page_title: tenant.name,
      tenant: tenant,
      logs: Audit.list_for_tenant(tenant.id)
    )
  end

  defp reload(socket) do
    case Tenants.get_tenant_for_admin(socket.assigns.tenant.id) do
      nil -> push_navigate(socket, to: ~p"/admin/tenants")
      tenant -> load(socket, tenant)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="tenants"
      breadcrumb={@tenant.name}
    >
      <div class="mb-6 flex items-start justify-between gap-4">
        <div>
          <.link
            navigate={~p"/admin/tenants"}
            class="text-xs font-semibold"
            style="color:var(--mc-text-3)"
          >
            ← Agencies
          </.link>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            {@tenant.name}
          </h1>
          <div class="mt-2 flex items-center gap-2">
            <span class="font-mono text-sm" style="color:var(--mc-text-3)">{@tenant.slug}</span>
            <.status_badge status={@tenant.status} />
          </div>
        </div>

        <div class="flex flex-wrap items-center justify-end gap-1.5">
          <button phx-click="edit" class="mtb-btn mtb-btn-secondary mtb-btn-sm">Edit</button>
          <button
            :if={@tenant.status in [:trial, :active]}
            phx-click="transition"
            phx-value-to="suspended"
            class="mtb-btn mtb-btn-ghost mtb-btn-sm"
          >
            Suspend
          </button>
          <button
            :if={@tenant.status == :suspended}
            phx-click="transition"
            phx-value-to="active"
            class="mtb-btn mtb-btn-ghost mtb-btn-sm"
          >
            Reactivate
          </button>
          <button
            :if={@tenant.status in [:trial, :active, :suspended]}
            phx-click="transition"
            phx-value-to="cancelled"
            class="mtb-btn mtb-btn-ghost mtb-btn-sm"
          >
            Cancel
          </button>
          <button phx-click="delete" class="mtb-btn mtb-btn-danger-outline mtb-btn-sm">Remove</button>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
        <div class="space-y-6">
          <div class="mtb-card p-6">
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Details</div>
            <dl class="grid grid-cols-2 gap-y-3">
              <.detail label="Plan" value={plan_name(@tenant)} />
              <.detail label="Status" value={status_label(@tenant.status)} />
              <.detail label="Trial ends" value={trial_label(@tenant)} mono />
              <.detail label="Owner" value={Tenants.owner_email(@tenant) || "—"} />
            </dl>
          </div>

          <div class="mtb-card overflow-hidden">
            <div
              class="px-6 py-4 font-semibold"
              style="font-family:var(--font-display);border-bottom:1px solid var(--mc-border)"
            >
              Members
            </div>
            <p
              :if={@tenant.memberships == []}
              class="px-6 py-5 text-sm"
              style="color:var(--mc-text-3)"
            >
              No members yet.
            </p>
            <table :if={@tenant.memberships != []} class="mtb-table">
              <tbody>
                <tr
                  :for={membership <- @tenant.memberships}
                  style="border-top:1px solid var(--mc-border)"
                >
                  <td class="px-6 py-3 text-sm" style="color:var(--mc-text)">
                    {membership.user.email}
                  </td>
                  <td class="px-6 py-3 text-right">
                    <span class="mtb-badge mtb-badge-neutral">{Membership.role_label(membership)}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
          <.audit_timeline logs={@logs} empty="No activity recorded for this agency yet." />
        </div>
      </div>

      <.edit_modal :if={@modal == :edit} form={@form} plans={@plans} />
      <.delete_modal :if={@modal == :delete} tenant={@tenant} />
    </Layouts.admin>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :mono, :boolean, default: false

  defp detail(assigns) do
    ~H"""
    <div>
      <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
        {@label}
      </dt>
      <dd class={["mt-0.5 text-sm", @mono && "font-mono"]} style="color:var(--mc-text)">{@value}</dd>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :plans, :list, required: true

  defp edit_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:480px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            Edit agency
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
        <.form for={@form} id="tenant-edit-form" phx-change="validate" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <.input field={@form[:name]} type="text" label="Agency name" />
            <.input
              field={@form[:plan_id]}
              type="select"
              label="Plan"
              prompt="Select a plan"
              options={plan_options(@plans)}
            />
          </div>
          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
              Save changes
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
            from QuoteAssist. The workspace stops resolving immediately. History and the
            audit trail are preserved (a soft delete) — this is not a permanent purge.
          </p>
        </div>
        <div class="mtb-modal-foot">
          <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            Cancel
          </button>
          <button phx-click="confirm_delete" class="mtb-btn mtb-btn-danger mtb-btn-sm">
            Remove agency
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("edit", _params, socket) do
    {:noreply,
     assign(socket, modal: :edit, form: to_form(Tenants.change_tenant(socket.assigns.tenant)))}
  end

  def handle_event("validate", %{"tenant" => params}, socket) do
    changeset =
      socket.assigns.tenant
      |> Tenants.change_tenant(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"tenant" => params}, socket) do
    case Tenants.update_tenant(socket.assigns.current_admin, socket.assigns.tenant, params) do
      {:ok, _updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agency updated.")
         |> assign(modal: nil, form: nil)
         |> reload()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("transition", %{"to" => to}, socket) do
    case parse_status(to) do
      nil ->
        {:noreply, put_flash(socket, :error, "That status change isn't allowed.")}

      status ->
        case Tenants.transition_status(
               socket.assigns.tenant,
               status,
               socket.assigns.current_admin
             ) do
          {:ok, _updated} ->
            {:noreply, socket |> put_flash(:info, "Agency is now #{status}.") |> reload()}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "That status change isn't allowed.")}
        end
    end
  end

  def handle_event("delete", _params, socket), do: {:noreply, assign(socket, modal: :delete)}

  def handle_event("confirm_delete", _params, socket) do
    tenant = socket.assigns.tenant
    {:ok, _deleted} = Tenants.soft_delete_tenant(socket.assigns.current_admin, tenant)

    {:noreply,
     socket
     |> put_flash(:info, "#{tenant.name} removed.")
     |> push_navigate(to: ~p"/admin/tenants")}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  defp plan_options(plans), do: Enum.map(plans, fn plan -> {plan.name, plan.id} end)

  defp parse_status("active"), do: :active
  defp parse_status("suspended"), do: :suspended
  defp parse_status("cancelled"), do: :cancelled
  defp parse_status(_other), do: nil
end
