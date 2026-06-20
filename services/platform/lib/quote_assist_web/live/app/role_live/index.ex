defmodule QuoteAssistWeb.App.RoleLive.Index do
  @moduledoc """
  Tenant roles (`/app/roles`): list roles and link out to the dedicated create / edit
  pages (`QuoteAssistWeb.App.RoleLive.Form`), where permissions are composed in a matrix
  over the code-owned catalog. Gated by the `role:*` permissions (owner-only by default —
  `manager` holds only `role:list`/`role:read`). The `self:*` baseline is never shown
  (implicit, non-composable); built-in roles can't be deleted; the owner protected type is
  not a role and never appears here. Every mutation is audited.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Role
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(_params, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "role:list")
    {:ok, socket |> assign(page_title: "Roles", delete: nil) |> load_roles()}
  end

  defp load_roles(socket) do
    assign(socket, :roles, Tenants.list_roles(socket.assigns.current_scope.tenant))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} active="roles" breadcrumb="Roles">
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Account
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Roles
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Bundles of permissions assigned to members. Owners hold every permission and need no
            role; everyone keeps the implicit self-service baseline.
          </p>
        </div>
        <.link
          :if={can?(@current_scope, "role:create")}
          id="new-role"
          navigate={~p"/app/roles/new"}
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
        >
          <.icon name="hero-plus" class="size-4" /> New role
        </.link>
      </div>

      <div class="mtb-card overflow-hidden">
        <table class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Role
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Permissions
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Kind
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold" style="color:var(--mc-text-3)">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={role <- @roles}
              id={"role-#{role.id}"}
              style="border-top:1px solid var(--mc-border)"
            >
              <td class="px-5 py-3 align-middle">
                <div class="text-sm font-semibold" style="color:var(--mc-text)">{role.name}</div>
                <div class="text-[11px]" style="color:var(--mc-text-3)">
                  <span class="font-mono">{role.slug}</span>
                </div>
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {length(role.permissions)}
              </td>
              <td class="px-4 py-3 align-middle">
                <span class={[
                  "mtb-badge",
                  if(role.builtin, do: "mtb-badge-neutral", else: "mtb-badge-success")
                ]}>
                  {if role.builtin, do: "Built-in", else: "Custom"}
                </span>
              </td>
              <td class="px-4 py-3 align-middle">
                <div class="flex items-center justify-end gap-1.5">
                  <.link
                    :if={can?(@current_scope, "role:update")}
                    navigate={~p"/app/roles/#{role.id}/edit"}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Edit
                  </.link>
                  <button
                    :if={not role.builtin and can?(@current_scope, "role:delete")}
                    phx-click="delete"
                    phx-value-id={role.id}
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

      <.delete_modal :if={@delete} role={@delete} />
    </Layouts.workspace>
    """
  end

  attr :role, :any, required: true

  defp delete_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:460px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            Remove {@role.name}?
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
            This removes the
            <span class="font-semibold" style="color:var(--mc-text)">{@role.name}</span>
            role. It can only be removed while no member is assigned to it.
          </p>
        </div>
        <div class="mtb-modal-foot">
          <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            Cancel
          </button>
          <button
            phx-click="confirm_delete"
            phx-value-id={@role.id}
            class="mtb-btn mtb-btn-danger mtb-btn-sm"
          >
            Remove role
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_scope, "role:delete"),
         %Role{} = role <- fetch(socket, id) do
      {:noreply, assign(socket, delete: role)}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
    end
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_scope, "role:delete"),
         %Role{} = role <- fetch(socket, id) do
      remove_role(socket, role)
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, delete: nil)}
  end

  defp remove_role(socket, role) do
    case Tenants.soft_delete_role(socket.assigns.current_scope, role) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{role.name} removed.")
         |> assign(delete: nil)
         |> load_roles()}

      {:error, :builtin} ->
        {:noreply, close_with_error(socket, "Built-in roles can't be removed.")}

      {:error, :role_in_use} ->
        {:noreply,
         close_with_error(
           socket,
           "That role is still assigned to a member — reassign them first."
         )}
    end
  end

  defp fetch(socket, id), do: Tenants.get_role(socket.assigns.current_scope.tenant, id)

  defp denied(socket) do
    socket |> put_flash(:error, "You don't have permission to do that.") |> assign(delete: nil)
  end

  defp missing(socket) do
    socket
    |> put_flash(:error, "That role no longer exists.")
    |> assign(delete: nil)
    |> load_roles()
  end

  defp close_with_error(socket, message) do
    socket |> put_flash(:error, message) |> assign(delete: nil) |> load_roles()
  end
end
