defmodule QuoteAssistWeb.App.RoleLive.Form do
  @moduledoc """
  Create / edit a tenant role on a dedicated page (`/app/roles/new`,
  `/app/roles/:id/edit`). Permissions are composed in a **matrix** of resources (rows)
  × actions (columns) drawn from the code-owned catalog (`QuoteAssist.Authz.Permissions`).
  Bulk controls toggle the whole grid ("select all"), an entire action down a column, or
  every action of one resource across a row — the selection lives server-side in
  `@selected` (a `MapSet`), so the catalog is never invented in the UI. Gated by
  `role:create` / `role:update`; every save is audited by the context.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Authz.Permissions
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Role
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(params, _session, socket) do
    socket =
      assign(socket,
        columns: Permissions.base_action_columns(),
        resources: Permissions.catalog()
      )

    {:ok, prepare(socket, params)}
  end

  defp prepare(socket, %{"id" => id}) do
    UserAuth.permit!(socket.assigns.current_scope, "role:update")
    tenant = socket.assigns.current_scope.tenant

    case Tenants.get_role(tenant, id) do
      %Role{} = role ->
        socket
        |> assign(action: :edit, role: role, selected: MapSet.new(role.permissions))
        |> assign_form(Tenants.change_tenant_role(tenant, role))

      nil ->
        socket
        |> put_flash(:error, "That role no longer exists.")
        |> redirect(to: ~p"/app/roles")
    end
  end

  defp prepare(socket, _params) do
    UserAuth.permit!(socket.assigns.current_scope, "role:create")
    tenant = socket.assigns.current_scope.tenant

    socket
    |> assign(action: :new, role: %Role{}, selected: MapSet.new())
    |> assign_form(Tenants.change_tenant_role(tenant, %Role{}))
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: :role))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} active="roles" breadcrumb="Roles">
      <.link
        navigate={~p"/app/roles"}
        class="mb-4 inline-flex items-center gap-1.5 text-sm"
        style="color:var(--mc-text-2)"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to roles
      </.link>

      <h1
        class="mb-6 text-3xl font-bold tracking-tight"
        style="font-family:var(--font-display);color:var(--mc-text)"
      >
        {if @action == :new, do: "New role", else: "Edit role"}
      </h1>

      <.form for={@form} id="role-form" phx-submit="save" class="space-y-5">
        <div class="mtb-card space-y-1 p-6">
          <.input field={@form[:name]} type="text" label="Role name" placeholder="Senior agent" />
          <.input
            :if={@action == :new}
            field={@form[:slug]}
            type="text"
            label="Slug"
            placeholder="senior-agent"
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
          <div
            class="flex items-center justify-between gap-3 border-b px-5 py-3"
            style="border-color:var(--mc-border)"
          >
            <div>
              <div class="text-sm font-semibold" style="color:var(--mc-text)">Permissions</div>
              <div class="text-xs" style="color:var(--mc-text-3)">
                Tick a cell, a whole column (action), a whole row (resource), or everything. The
                self-service baseline is always granted and isn't shown.
              </div>
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
                      :if={Permissions.valid?(Permissions.key_for(group.resource, col.action))}
                      type="checkbox"
                      id={"perm-#{group.resource}-#{col.action}"}
                      phx-click="toggle_perm"
                      phx-value-key={Permissions.key_for(group.resource, col.action)}
                      checked={
                        MapSet.member?(@selected, Permissions.key_for(group.resource, col.action))
                      }
                      style="width:16px;height:16px;accent-color:var(--mc-brand)"
                    />
                    <span
                      :if={not Permissions.valid?(Permissions.key_for(group.resource, col.action))}
                      style="color:var(--mc-text-3)"
                    >
                      ·
                    </span>
                  </td>
                  <td class="px-4 py-2.5">
                    <% specials = Permissions.special_permissions(group.resource) %>
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
          <.link navigate={~p"/app/roles"} class="mtb-btn mtb-btn-ghost mtb-btn-sm">Cancel</.link>
          <span class="ml-auto font-mono text-xs" style="color:var(--mc-text-3)">
            {MapSet.size(@selected)} selected
          </span>
        </div>
      </.form>
    </Layouts.workspace>
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
    {:noreply, update(socket, :selected, &toggle_many(&1, Permissions.special_keys()))}
  end

  def handle_event("toggle_all", _params, socket) do
    {:noreply, update(socket, :selected, &toggle_many(&1, Permissions.keys()))}
  end

  def handle_event("save", %{"role" => params}, socket) do
    params = Map.put(params, "permissions", MapSet.to_list(socket.assigns.selected))

    result =
      case socket.assigns.action do
        :new -> Tenants.create_role(socket.assigns.current_scope, params)
        :edit -> Tenants.update_role(socket.assigns.current_scope, socket.assigns.role, params)
      end

    case result do
      {:ok, role} ->
        {:noreply,
         socket |> put_flash(:info, "#{role.name} saved.") |> redirect(to: ~p"/app/roles")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # ── Selection helpers ──────────────────────────────────────────────────────────────

  defp toggle(set, key) do
    if MapSet.member?(set, key), do: MapSet.delete(set, key), else: MapSet.put(set, key)
  end

  # "Select all" semantics: if every key in the group is already selected, clear them;
  # otherwise add them all.
  defp toggle_many(set, keys) do
    if Enum.all?(keys, &MapSet.member?(set, &1)),
      do: Enum.reduce(keys, set, &MapSet.delete(&2, &1)),
      else: Enum.reduce(keys, set, &MapSet.put(&2, &1))
  end

  defp action_keys(action) do
    for group <- Permissions.catalog(),
        key = Permissions.key_for(group.resource, action),
        Permissions.valid?(key),
        do: key
  end

  defp resource_keys(resource) do
    for group <- Permissions.catalog(),
        group.resource == resource,
        perm <- group.permissions,
        do: perm.key
  end

  defp all_selected?(set), do: filled?(set, Permissions.keys())
  defp column_selected?(set, action), do: filled?(set, action_keys(action))
  defp resource_selected?(set, resource), do: filled?(set, resource_keys(resource))
  defp special_selected?(set), do: filled?(set, Permissions.special_keys())

  defp filled?(_set, []), do: false
  defp filled?(set, keys), do: Enum.all?(keys, &MapSet.member?(set, &1))

  # Chip styling for a special permission: a soft, brand-tinted pill with a subtle
  # shadow when granted, a neutral surface pill otherwise — so a ticked chip reads as
  # "[✓] label" at a glance.
  defp chip_style(true) do
    "border-color:var(--mc-brand);background:color-mix(in oklch,var(--mc-brand) 12%,var(--mc-surface));" <>
      "color:var(--mc-brand);box-shadow:0 1px 3px rgb(0 0 0 / 0.12)"
  end

  defp chip_style(false) do
    "border-color:var(--mc-border);background:var(--mc-surface);color:var(--mc-text-2);" <>
      "box-shadow:0 1px 2px rgb(0 0 0 / 0.05)"
  end
end
