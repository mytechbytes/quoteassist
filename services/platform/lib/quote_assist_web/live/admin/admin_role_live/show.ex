defmodule QuoteAssistWeb.Admin.AdminRoleLive.Show do
  @moduledoc """
  Admin role detail (`/admin/roles/:id`): the permissions a role grants and the
  administrators assigned to it. Gated by `admin_role:read`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Accounts
  alias QuoteAssist.Authz.AdminPermissions

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case QuoteAssistWeb.AdminAuth.authorize(socket, "admin_role:read") do
      {:cont, socket} -> {:ok, load(socket, id)}
      {:halt, socket} -> {:ok, socket}
    end
  end

  defp load(socket, id) do
    case Accounts.get_admin_role(id) do
      nil ->
        socket
        |> put_flash(:error, "That role no longer exists.")
        |> push_navigate(to: ~p"/admin/roles")

      role ->
        assign(socket,
          page_title: role.name,
          role: role,
          admins: Accounts.list_admins_for_role(role)
        )
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="roles"
      breadcrumb={@role.name}
    >
      <div class="mb-6">
        <.link
          navigate={~p"/admin/roles"}
          class="text-xs font-semibold"
          style="color:var(--mc-text-3)"
        >
          ← Admin roles
        </.link>
        <h1
          class="mt-1.5 text-2xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          {@role.name}
        </h1>
        <p :if={@role.description} class="mt-1 text-sm" style="color:var(--mc-text-2)">
          {@role.description}
        </p>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">
            Permissions
          </div>
          <div class="space-y-4">
            <div :for={group <- granted_groups(@role)}>
              <div class="text-xs font-bold uppercase tracking-wide" style="color:var(--mc-text-3)">
                {group.group}
              </div>
              <ul class="mt-1 space-y-0.5">
                <li :for={label <- group.labels} class="text-sm" style="color:var(--mc-text-2)">
                  {label}
                </li>
              </ul>
            </div>
            <p :if={@role.permissions == []} class="text-sm" style="color:var(--mc-text-3)">
              This role grants no permissions yet.
            </p>
          </div>
        </div>

        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">
            Administrators
          </div>
          <p :if={@admins == []} class="text-sm" style="color:var(--mc-text-3)">
            No administrators have this role.
          </p>
          <ul :if={@admins != []} class="space-y-2">
            <li :for={admin <- @admins} class="flex items-center justify-between gap-3">
              <.link
                navigate={~p"/admin/admins/#{admin.id}"}
                class="text-sm font-medium no-underline hover:underline"
                style="color:var(--mc-text)"
              >
                {admin.email}
              </.link>
              <.admin_active_badge active={admin.active} />
            </li>
          </ul>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  # Catalog groups reduced to just the labels this role grants; empty groups dropped.
  defp granted_groups(role) do
    granted = MapSet.new(role.permissions)

    AdminPermissions.catalog()
    |> Enum.map(fn group ->
      labels =
        group.permissions
        |> Enum.filter(&MapSet.member?(granted, &1.key))
        |> Enum.map(& &1.label)

      %{group: group.group, labels: labels}
    end)
    |> Enum.reject(&(&1.labels == []))
  end
end
