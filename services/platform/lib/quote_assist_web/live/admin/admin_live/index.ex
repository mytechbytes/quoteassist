defmodule QuoteAssistWeb.Admin.AdminLive.Index do
  @moduledoc """
  Site administrators (`/admin/admins`): list and manage admins. Gated by the
  `admin:*` permissions. The `super_admin` protected type is enforced at the **query
  layer** — a normal admin's list excludes super_admins entirely
  (`Accounts.list_admins_visible_to/1`), so they can't see, edit, or act on one by any
  path. Super_admins are created from the CLI (`mix qa.create_admin`); this console
  creates scoped, normal admins, reassigns roles, and activates/deactivates/removes —
  all guarded by the last-active-super_admin invariant and audited.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Accounts

  @impl true
  def mount(_params, _session, socket) do
    case QuoteAssistWeb.AdminAuth.authorize(socket, "admin:list") do
      {:cont, socket} ->
        {:ok,
         socket
         |> assign(
           page_title: "Admins",
           roles: Accounts.list_admin_roles(),
           modal: nil,
           form: nil
         )
         |> load_admins()}

      {:halt, socket} ->
        {:ok, socket}
    end
  end

  defp load_admins(socket) do
    assign(socket, :admins, Accounts.list_admins_visible_to(socket.assigns.current_admin))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_admin={@current_admin} active="admins" breadcrumb="Admins">
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Platform
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Administrators
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Staff with platform access. Super admins hold every permission and are created from
            the command line (<span class="font-mono">mix qa.create_admin</span>); scoped admins
            are created here with a role.
          </p>
        </div>
        <button
          :if={can?(@current_admin, "admin:create")}
          id="new-admin"
          phx-click="new"
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
        >
          <.icon name="hero-plus" class="size-4" /> New admin
        </button>
      </div>

      <div class="mtb-card overflow-hidden">
        <table class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Administrator
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Type
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Role
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Status
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Last sign-in
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold" style="color:var(--mc-text-3)">
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={admin <- @admins}
              id={"admin-#{admin.id}"}
              style="border-top:1px solid var(--mc-border)"
            >
              <td class="px-5 py-3 align-middle">
                <.link
                  navigate={~p"/admin/admins/#{admin.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {admin.email}
                </.link>
              </td>
              <td class="px-4 py-3 align-middle">
                <.admin_type_badge type={admin.type} />
              </td>
              <td class="px-4 py-3 align-middle text-sm" style="color:var(--mc-text-2)">
                {admin_role_label(admin)}
              </td>
              <td class="px-4 py-3 align-middle">
                <.admin_active_badge active={admin.active} />
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {format_datetime(admin.last_sign_in_at)}
              </td>
              <td class="px-4 py-3 align-middle">
                <div class="flex items-center justify-end gap-1.5">
                  <button
                    :if={show_edit_role?(@current_admin, admin)}
                    phx-click="edit"
                    phx-value-id={admin.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Edit role
                  </button>
                  <button
                    :if={show_reactivate?(@current_admin, admin)}
                    phx-click="activate"
                    phx-value-id={admin.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Reactivate
                  </button>
                  <button
                    :if={show_deactivate?(@current_admin, admin)}
                    phx-click="deactivate"
                    phx-value-id={admin.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Deactivate
                  </button>
                  <button
                    :if={show_remove?(@current_admin, admin)}
                    phx-click="delete"
                    phx-value-id={admin.id}
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

      <.new_modal :if={@modal == :new} form={@form} roles={@roles} />
      <.edit_modal
        :if={match?({:edit, _}, @modal)}
        form={@form}
        roles={@roles}
        admin={elem(@modal, 1)}
      />
      <.delete_modal :if={match?({:delete, _}, @modal)} admin={elem(@modal, 1)} />
    </Layouts.admin>
    """
  end

  attr :form, :any, required: true
  attr :roles, :list, required: true

  defp new_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:520px">
        <div class="mtb-modal-head">
          <div>
            <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
              New admin
            </div>
            <div class="mt-0.5 text-xs" style="color:var(--mc-text-3)">
              Create a scoped administrator with a role and an initial password.
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

        <.form for={@form} id="admin-form" phx-change="validate" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <.input field={@form[:email]} type="email" label="Email" placeholder="ops@quoteassist.in" />
            <.input
              field={@form[:password]}
              type="password"
              label="Initial password (min 12 characters)"
            />
            <.input
              field={@form[:role_id]}
              type="select"
              label="Role"
              prompt={if @roles == [], do: "Create a role first", else: "Select a role"}
              options={role_options(@roles)}
            />
          </div>

          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
              Create admin
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :roles, :list, required: true
  attr :admin, :any, required: true

  defp edit_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:480px">
        <div class="mtb-modal-head">
          <div>
            <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
              Edit role
            </div>
            <div class="mt-0.5 text-xs" style="color:var(--mc-text-3)">
              {@admin.email}
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

        <.form for={@form} id="admin-form" phx-change="validate" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <.input
              field={@form[:role_id]}
              type="select"
              label="Role"
              prompt="Select a role"
              options={role_options(@roles)}
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

  attr :admin, :any, required: true

  defp delete_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:460px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            Remove {@admin.email}?
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
            This removes <span class="font-semibold" style="color:var(--mc-text)">{@admin.email}</span>'s
            platform access and revokes their sessions immediately. The record is kept
            (a soft delete) for the audit trail.
          </p>
        </div>
        <div class="mtb-modal-foot">
          <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            Cancel
          </button>
          <button
            phx-click="confirm_delete"
            phx-value-id={@admin.id}
            class="mtb-btn mtb-btn-danger mtb-btn-sm"
          >
            Remove admin
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("new", _params, socket) do
    if can?(socket.assigns.current_admin, "admin:create") do
      {:noreply, assign(socket, modal: :new, form: to_form(Accounts.change_admin_creation()))}
    else
      {:noreply, denied(socket)}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin:update"),
         %{type: :admin} = admin <- fetch(socket, id) do
      {:noreply,
       assign(socket, modal: {:edit, admin}, form: to_form(Accounts.change_admin(admin)))}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, missing(socket)}
    end
  end

  def handle_event("validate", %{"admin" => params}, socket) do
    changeset =
      case socket.assigns.modal do
        :new -> Accounts.change_admin_creation(params)
        {:edit, admin} -> Accounts.change_admin(admin, params)
      end

    {:noreply, assign(socket, form: to_form(Map.put(changeset, :action, :validate)))}
  end

  def handle_event("save", %{"admin" => params}, socket) do
    case socket.assigns.modal do
      :new -> create_admin(socket, params)
      {:edit, admin} -> update_role(socket, admin, params)
    end
  end

  def handle_event("activate", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin:activate"),
         %{} = admin <- fetch(socket, id),
         {:ok, _updated} <- Accounts.activate_admin(socket.assigns.current_admin, admin) do
      {:noreply, socket |> put_flash(:info, "#{admin.email} reactivated.") |> load_admins()}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
      {:error, _changeset} -> {:noreply, flash_reload(socket, "Couldn't reactivate that admin.")}
    end
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin:deactivate"),
         %{} = admin <- fetch(socket, id),
         {:ok, _updated} <- Accounts.deactivate_admin(socket.assigns.current_admin, admin) do
      {:noreply, socket |> put_flash(:info, "#{admin.email} deactivated.") |> load_admins()}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
      {:error, :last_super_admin} -> {:noreply, flash_reload(socket, last_super_admin_msg())}
      {:error, _changeset} -> {:noreply, flash_reload(socket, "Couldn't deactivate that admin.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin:delete"),
         %{} = admin <- fetch(socket, id) do
      {:noreply, assign(socket, modal: {:delete, admin})}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
    end
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_admin, "admin:delete"),
         %{} = admin <- fetch(socket, id),
         {:ok, _deleted} <- Accounts.soft_delete_admin(socket.assigns.current_admin, admin) do
      {:noreply,
       socket
       |> put_flash(:info, "#{admin.email} removed.")
       |> assign(modal: nil)
       |> load_admins()}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
      {:error, :last_super_admin} -> {:noreply, close_with_error(socket, last_super_admin_msg())}
      {:error, _changeset} -> {:noreply, close_with_error(socket, "Couldn't remove that admin.")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  defp create_admin(socket, params) do
    case Accounts.create_admin(socket.assigns.current_admin, params) do
      {:ok, admin} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{admin.email} created.")
         |> assign(modal: nil, form: nil)
         |> load_admins()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp update_role(socket, admin, params) do
    case Accounts.update_admin_role_assignment(socket.assigns.current_admin, admin, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{updated.email} updated.")
         |> assign(modal: nil, form: nil)
         |> load_admins()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, :super_admin_has_no_role} ->
        {:noreply,
         close_with_error(socket, "Super admins hold every permission and carry no role.")}
    end
  end

  # Fetches a target admin the actor is allowed to see (super_admins are invisible to
  # normal admins at the query layer), or nil.
  defp fetch(socket, id), do: Accounts.get_admin_visible_to(socket.assigns.current_admin, id)

  defp denied(socket) do
    socket
    |> put_flash(:error, "You don't have permission to do that.")
    |> assign(modal: nil, form: nil)
  end

  defp missing(socket) do
    socket
    |> put_flash(:error, "That administrator no longer exists.")
    |> assign(modal: nil, form: nil)
    |> load_admins()
  end

  defp close_with_error(socket, message) do
    socket
    |> put_flash(:error, message)
    |> assign(modal: nil, form: nil)
    |> load_admins()
  end

  defp flash_reload(socket, message) do
    socket |> put_flash(:error, message) |> load_admins()
  end

  defp last_super_admin_msg, do: "The last active super admin can't be changed."

  defp role_options(roles), do: Enum.map(roles, fn role -> {role.name, role.id} end)

  # ── Per-row action visibility (permission + protected-type aware) ──────────────────

  defp show_edit_role?(actor, admin), do: admin.type == :admin and can?(actor, "admin:update")

  defp show_reactivate?(actor, admin), do: not admin.active and can?(actor, "admin:activate")

  defp show_deactivate?(actor, admin) do
    admin.active and admin.id != actor.id and can?(actor, "admin:deactivate")
  end

  defp show_remove?(actor, admin) do
    admin.id != actor.id and can?(actor, "admin:delete")
  end
end
