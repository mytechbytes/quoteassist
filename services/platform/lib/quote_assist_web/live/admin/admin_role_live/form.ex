defmodule QuoteAssistWeb.Admin.AdminRoleLive.Form do
  @moduledoc """
  Create / edit an admin role on a dedicated page (`/admin/roles/new`,
  `/admin/roles/:id/edit`) — the platform mirror of `QuoteAssistWeb.App.RoleLive.Form`.
  Permissions are composed in a matrix of resources (rows) × CRUD actions (columns) over
  the code-owned admin catalog (`QuoteAssist.Authz.AdminPermissions`), with the non-CRUD
  ("special") permissions shown as chips in a Special column. Bulk controls toggle the
  whole grid, a column (action), a row (resource), or every special; the selection lives
  server-side in `@selected` (a `MapSet`). Gated by `admin_role:create`/`admin_role:update`;
  every save is audited.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.AdminRole
  alias QuoteAssist.Authz.AdminPermissions
  alias QuoteAssistWeb.AdminAuth

  @impl true
  def mount(params, _session, socket) do
    socket =
      assign(socket,
        columns: AdminPermissions.base_action_columns(),
        resources: AdminPermissions.catalog()
      )

    permission = if Map.has_key?(params, "id"), do: "admin_role:update", else: "admin_role:create"

    case AdminAuth.authorize(socket, permission) do
      {:cont, socket} -> {:ok, prepare(socket, params)}
      {:halt, socket} -> {:ok, socket}
    end
  end

  defp prepare(socket, %{"id" => id}) do
    case Accounts.get_admin_role(id) do
      %AdminRole{} = role ->
        socket
        |> assign(action: :edit, role: role, selected: MapSet.new(role.permissions))
        |> assign_form(Accounts.change_admin_role(role))

      nil ->
        socket
        |> put_flash(:error, "That role no longer exists.")
        |> redirect(to: ~p"/admin/roles")
    end
  end

  defp prepare(socket, _params) do
    socket
    |> assign(action: :new, role: %AdminRole{}, selected: MapSet.new())
    |> assign_form(Accounts.change_admin_role())
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :admin_role))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_admin={@current_admin} active="roles" breadcrumb="Roles">
      <.link
        navigate={~p"/admin/roles"}
        class="mb-4 inline-flex items-center gap-1.5 text-sm"
        style="color:var(--mc-text-2)"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to roles
      </.link>

      <h1
        class="mb-6 text-3xl font-bold tracking-tight"
        style="font-family:var(--font-display);color:var(--mc-text)"
      >
        {if @action == :new, do: "New admin role", else: "Edit admin role"}
      </h1>

      <.form for={@form} id="role-form" phx-submit="save" class="space-y-5">
        <div class="mtb-card space-y-1 p-6">
          <.input field={@form[:name]} type="text" label="Role name" placeholder="Operations" />
          <.input
            :if={@action == :new}
            field={@form[:slug]}
            type="text"
            label="Slug"
            placeholder="operations"
          />
          <div :if={@action == :edit}>
            <label class="mtb-label">Slug</label>
            <p class="font-mono text-sm" style="color:var(--mc-text-3)">{@role.slug}</p>
          </div>
          <.input
            field={@form[:description]}
            type="text"
            label="Description"
            placeholder="What this role is for"
          />
        </div>

        <div class="mtb-card overflow-hidden">
          <div class="border-b px-5 py-3" style="border-color:var(--mc-border)">
            <div class="text-sm font-semibold" style="color:var(--mc-text)">Permissions</div>
            <div class="text-xs" style="color:var(--mc-text-3)">
              Tick a cell, a whole column (action), a whole row (resource), or everything. The
              self-service baseline is always granted and isn't shown.
            </div>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-sm" style="border-collapse:collapse">
              <thead>
                <tr style="background:var(--mc-surface-2)">
                  <th
                    class="px-4 py-2.5 text-left text-sm font-semibold"
                    style="color:var(--mc-text-3)"
                  >
                    <div class="mb-2">Resource</div>
                    <label
                      class="flex shrink-0 items-center gap-2 text-sm font-medium"
                      style="color:var(--mc-text-2)"
                    >
                      <input
                        type="checkbox"
                        id="select-all"
                        phx-click="toggle_all"
                        checked={all_selected?(@selected)}
                        style="width:16px;height:16px;accent-color:var(--mc-brand)"
                      /> Select all
                    </label>
                  </th>
                  <th
                    :for={col <- @columns}
                    class="px-3 py-2.5 text-center text-sm font-semibold"
                    style="color:var(--mc-text-3)"
                  >
                    <div class="mb-2">{col.label}</div>
                    <input
                      type="checkbox"
                      id={"col-#{col.action}"}
                      phx-click="toggle_action"
                      phx-value-action={col.action}
                      checked={column_selected?(@selected, col.action)}
                      title={"Toggle every #{col.label} permission"}
                      style="margin-top:4px;width:15px;height:15px;accent-color:var(--mc-brand)"
                    />
                  </th>
                  <th
                    class="px-3 py-2.5 text-left text-sm font-semibold"
                    style="color:var(--mc-text-3)"
                  >
                    <div class="text-center inline-block">
                      <div class="mb-2">Special permissions</div>
                      <input
                        type="checkbox"
                        id="col-special"
                        phx-click="toggle_specials"
                        checked={special_selected?(@selected)}
                        title="Toggle every special permission"
                        style="margin-top:4px;width:15px;height:15px;accent-color:var(--mc-brand)"
                      />
                    </div>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={group <- @resources}
                  id={"row-#{group.resource}"}
                  style="border-top:1px solid var(--mc-border)"
                >
                  <td class="px-4 py-2.5">
                    <label class="flex items-center gap-2 font-medium" style="color:var(--mc-text)">
                      <input
                        type="checkbox"
                        id={"resource-#{group.resource}"}
                        phx-click="toggle_resource"
                        phx-value-resource={group.resource}
                        checked={resource_selected?(@selected, group.resource)}
                        style="width:15px;height:15px;accent-color:var(--mc-brand)"
                      />
                      {group.group}
                    </label>
                  </td>
                  <td :for={col <- @columns} class="px-3 py-2.5 text-center">
                    <input
                      :if={
                        AdminPermissions.valid?(AdminPermissions.key_for(group.resource, col.action))
                      }
                      type="checkbox"
                      id={"perm-#{group.resource}-#{col.action}"}
                      phx-click="toggle_perm"
                      phx-value-key={AdminPermissions.key_for(group.resource, col.action)}
                      checked={
                        MapSet.member?(
                          @selected,
                          AdminPermissions.key_for(group.resource, col.action)
                        )
                      }
                      style="width:16px;height:16px;accent-color:var(--mc-brand)"
                    />
                    <span
                      :if={
                        not AdminPermissions.valid?(
                          AdminPermissions.key_for(group.resource, col.action)
                        )
                      }
                      style="color:var(--mc-text-3)"
                    >
                      ·
                    </span>
                  </td>
                  <td class="px-4 py-2.5">
                    <% specials = AdminPermissions.special_permissions(group.resource) %>
                    <div :if={specials != []} class="flex flex-wrap items-center gap-1">
                      <label
                        :for={perm <- specials}
                        class="inline-flex cursor-pointer items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium"
                        style={chip_style(MapSet.member?(@selected, perm.key))}
                      >
                        <input
                          type="checkbox"
                          id={"perm-#{group.resource}-#{perm.action}"}
                          phx-click="toggle_perm"
                          phx-value-key={perm.key}
                          checked={MapSet.member?(@selected, perm.key)}
                          style="width:13px;height:13px;accent-color:var(--mc-brand)"
                        />
                        {perm.label}
                      </label>
                    </div>
                    <span :if={specials == []} style="color:var(--mc-text-3)">·</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
            {if @action == :new, do: "Create role", else: "Save changes"}
          </.button>
          <.link navigate={~p"/admin/roles"} class="mtb-btn mtb-btn-ghost mtb-btn-sm">Cancel</.link>
          <span class="ml-auto font-mono text-xs" style="color:var(--mc-text-3)">
            {MapSet.size(@selected)} selected
          </span>
        </div>
      </.form>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("toggle_perm", %{"key" => key}, socket) do
    {:noreply, update(socket, :selected, &toggle(&1, key))}
  end

  def handle_event("toggle_action", %{"action" => action}, socket) do
    {:noreply, update(socket, :selected, &toggle_many(&1, action_keys(action)))}
  end

  def handle_event("toggle_resource", %{"resource" => resource}, socket) do
    {:noreply, update(socket, :selected, &toggle_many(&1, resource_keys(resource)))}
  end

  def handle_event("toggle_specials", _params, socket) do
    {:noreply, update(socket, :selected, &toggle_many(&1, AdminPermissions.special_keys()))}
  end

  def handle_event("toggle_all", _params, socket) do
    {:noreply, update(socket, :selected, &toggle_many(&1, AdminPermissions.keys()))}
  end

  def handle_event("save", %{"admin_role" => params}, socket) do
    params = Map.put(params, "permissions", MapSet.to_list(socket.assigns.selected))

    result =
      case socket.assigns.action do
        :new ->
          Accounts.create_admin_role(socket.assigns.current_admin, params)

        :edit ->
          Accounts.update_admin_role(socket.assigns.current_admin, socket.assigns.role, params)
      end

    case result do
      {:ok, role} ->
        {:noreply,
         socket |> put_flash(:info, "#{role.name} saved.") |> redirect(to: ~p"/admin/roles")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # ── Selection helpers (mirror of the tenant role form) ───────────────────────────────

  defp toggle(set, key) do
    if MapSet.member?(set, key), do: MapSet.delete(set, key), else: MapSet.put(set, key)
  end

  defp toggle_many(set, keys) do
    if Enum.all?(keys, &MapSet.member?(set, &1)),
      do: Enum.reduce(keys, set, &MapSet.delete(&2, &1)),
      else: Enum.reduce(keys, set, &MapSet.put(&2, &1))
  end

  defp action_keys(action) do
    for group <- AdminPermissions.catalog(),
        key = AdminPermissions.key_for(group.resource, action),
        AdminPermissions.valid?(key),
        do: key
  end

  defp resource_keys(resource) do
    for group <- AdminPermissions.catalog(),
        group.resource == resource,
        perm <- group.permissions,
        do: perm.key
  end

  defp all_selected?(set), do: filled?(set, AdminPermissions.keys())
  defp column_selected?(set, action), do: filled?(set, action_keys(action))
  defp resource_selected?(set, resource), do: filled?(set, resource_keys(resource))
  defp special_selected?(set), do: filled?(set, AdminPermissions.special_keys())

  defp filled?(_set, []), do: false
  defp filled?(set, keys), do: Enum.all?(keys, &MapSet.member?(set, &1))

  defp chip_style(true) do
    "border-color:var(--mc-brand);background:color-mix(in oklch,var(--mc-brand) 12%,var(--mc-surface));" <>
      "color:var(--mc-brand);box-shadow:0 1px 3px rgb(0 0 0 / 0.12)"
  end

  defp chip_style(false) do
    "border-color:var(--mc-border);background:var(--mc-surface);color:var(--mc-text-2);" <>
      "box-shadow:0 1px 2px rgb(0 0 0 / 0.05)"
  end
end
