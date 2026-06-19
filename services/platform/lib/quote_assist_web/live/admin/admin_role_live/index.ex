defmodule QuoteAssistWeb.Admin.AdminRoleLive.Index do
  @moduledoc """
  Admin role management (`/admin/roles`): list admin roles and compose them from the
  code-owned admin permission catalog (`QuoteAssist.Authz.AdminPermissions`). Gated by
  the `admin_role:*` permissions; a super_admin holds them all (computed). Built-in
  roles can't be deleted; the `super_admin` protected type is not a role and never
  appears here. Every mutation is audited (actor = admin).
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Accounts
  alias QuoteAssist.Authz.AdminPermissions

  @impl true
  def mount(_params, _session, socket) do
    case QuoteAssistWeb.AdminAuth.authorize(socket, "admin_role:list") do
      {:cont, socket} ->
        {:ok,
         socket
         |> assign(page_title: "Admin roles", modal: nil, form: nil)
         |> load_roles()}

      {:halt, socket} ->
        {:ok, socket}
    end
  end

  defp load_roles(socket), do: assign(socket, :roles, Accounts.list_admin_roles())

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_admin={@current_admin} active="roles" breadcrumb="Roles">
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Platform
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Admin roles
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Bundles of platform permissions assigned to scoped administrators. Super admins
            hold every permission and need no role.
          </p>
        </div>
        <button
          :if={can?(@current_admin, "admin_role:create")}
          id="new-role"
          phx-click="new"
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
        >
          <.icon name="hero-plus" class="size-4" /> New role
        </button>
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
                <.link
                  navigate={~p"/admin/roles/#{role.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {role.name}
                </.link>
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
                  <button
                    :if={can?(@current_admin, "admin_role:update")}
                    phx-click="edit"
                    phx-value-id={role.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Edit
                  </button>
                  <button
                    :if={not role.builtin and can?(@current_admin, "admin_role:delete")}
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

      <.role_modal
        :if={@modal in [:new] or match?({:edit, _}, @modal)}
        form={@form}
        modal={@modal}
      />
      <.delete_modal :if={match?({:delete, _}, @modal)} role={elem(@modal, 1)} />
    </Layouts.admin>
    """
  end

  attr :form, :any, required: true
  attr :modal, :any, required: true

  defp role_modal(assigns) do
    assigns =
      assigns
      |> assign(:new?, assigns.modal == :new)
      |> assign(:selected, current_permissions(assigns.form))

    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:640px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            {if @new?, do: "New role", else: "Edit role"}
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

        <.form for={@form} id="role-form" phx-change="validate" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <.input field={@form[:name]} type="text" label="Role name" placeholder="Operations" />
            <.input
              :if={@new?}
              field={@form[:slug]}
              type="text"
              label="Slug"
              placeholder="operations"
            />
            <.input
              field={@form[:description]}
              type="text"
              label="Description"
              placeholder="What this role is for"
            />

            <div class="pt-2">
              <div class="mb-1 text-sm font-semibold" style="color:var(--mc-text)">Permissions</div>
              <%!-- Always-present empty value so unchecking every box still submits the
                    field (the LiveView filters the blank out before casting). --%>
              <input type="hidden" name="admin_role[permissions][]" value="" />
              <div class="space-y-4">
                <fieldset :for={group <- AdminPermissions.catalog()}>
                  <legend
                    class="text-xs font-bold uppercase tracking-wide"
                    style="color:var(--mc-text-3)"
                  >
                    {group.group}
                  </legend>
                  <div class="mt-1 grid grid-cols-1 gap-x-4 gap-y-1 sm:grid-cols-2">
                    <label
                      :for={perm <- group.permissions}
                      class="flex items-center gap-2 text-sm"
                      style="color:var(--mc-text-2)"
                    >
                      <input
                        type="checkbox"
                        name="admin_role[permissions][]"
                        value={perm.key}
                        checked={perm.key in @selected}
                      />
                      {perm.label}
                    </label>
                  </div>
                </fieldset>
              </div>
            </div>
          </div>

          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
              {if @new?, do: "Create role", else: "Save changes"}
            </.button>
          </div>
        </.form>
      </div>
    </div>
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
            role. It can only be removed while no administrator is assigned to it.
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
  def handle_event("new", _params, socket) do
    if can?(socket.assigns.current_admin, "admin_role:create") do
      {:noreply, assign(socket, modal: :new, form: to_form(Accounts.change_admin_role()))}
    else
      {:noreply, denied(socket)}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin_role:update"),
         %{} = role <- Accounts.get_admin_role(id) do
      {:noreply,
       assign(socket, modal: {:edit, role}, form: to_form(Accounts.change_admin_role(role)))}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
    end
  end

  def handle_event("validate", %{"admin_role" => params}, socket) do
    params = clean_permissions(params)

    changeset =
      case socket.assigns.modal do
        :new -> Accounts.change_admin_role(%Accounts.AdminRole{}, params)
        {:edit, role} -> Accounts.change_admin_role(role, params)
      end

    {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save", %{"admin_role" => params}, socket) do
    params = clean_permissions(params)

    case socket.assigns.modal do
      :new -> create_role(socket, params)
      {:edit, role} -> update_role(socket, role, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin_role:delete"),
         %{} = role <- Accounts.get_admin_role(id) do
      {:noreply, assign(socket, modal: {:delete, role})}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
    end
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin_role:delete"),
         %{} = role <- Accounts.get_admin_role(id) do
      case Accounts.soft_delete_admin_role(socket.assigns.current_admin, role) do
        {:ok, _deleted} ->
          {:noreply,
           socket
           |> put_flash(:info, "#{role.name} removed.")
           |> assign(modal: nil)
           |> load_roles()}

        {:error, :builtin} ->
          {:noreply, close_with_error(socket, "Built-in roles can't be removed.")}

        {:error, :role_in_use} ->
          {:noreply,
           close_with_error(
             socket,
             "That role is still assigned to an admin — reassign them first."
           )}
      end
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  defp create_role(socket, params) do
    case Accounts.create_admin_role(socket.assigns.current_admin, params) do
      {:ok, role} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{role.name} created.")
         |> assign(modal: nil, form: nil)
         |> load_roles()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp update_role(socket, role, params) do
    case Accounts.update_admin_role(socket.assigns.current_admin, role, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{updated.name} updated.")
         |> assign(modal: nil, form: nil)
         |> load_roles()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp denied(socket) do
    socket
    |> put_flash(:error, "You don't have permission to do that.")
    |> assign(modal: nil, form: nil)
  end

  defp missing(socket) do
    socket
    |> put_flash(:error, "That role no longer exists.")
    |> assign(modal: nil, form: nil)
    |> load_roles()
  end

  defp close_with_error(socket, message) do
    socket
    |> put_flash(:error, message)
    |> assign(modal: nil)
    |> load_roles()
  end

  # Strips the always-present blank value so it never reaches the catalog validation.
  defp clean_permissions(%{"permissions" => perms} = params) when is_list(perms) do
    Map.put(params, "permissions", Enum.reject(perms, &(&1 == "")))
  end

  defp clean_permissions(params), do: params

  defp current_permissions(form) do
    case form[:permissions].value do
      perms when is_list(perms) -> perms
      _ -> []
    end
  end
end
