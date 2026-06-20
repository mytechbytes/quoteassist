defmodule QuoteAssistWeb.App.RoleLive.Show do
  @moduledoc """
  Tenant role detail (`/app/roles/:id`): the permissions a role grants, the members who
  hold it, and the role's activity feed. Gated by `role:read`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Authz.Permissions
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Role
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "role:read")
    {:ok, load(socket, id)}
  end

  defp load(socket, id) do
    case Tenants.get_role(socket.assigns.current_scope.tenant, id) do
      %Role{} = role ->
        assign(socket,
          page_title: role.name,
          role: role,
          members: Tenants.list_members_for_role(role),
          logs: Audit.list_for_target("role", role.id)
        )

      nil ->
        socket
        |> put_flash(:error, "That role no longer exists.")
        |> push_navigate(to: ~p"/app/roles")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="roles"
      breadcrumb={@role.name}
    >
      <div class="mb-6">
        <.link navigate={~p"/app/roles"} class="text-xs font-semibold" style="color:var(--mc-text-3)">
          ← Roles
        </.link>
        <div class="mt-1.5 flex items-center justify-between gap-3">
          <div>
            <h1
              class="text-2xl font-bold tracking-tight"
              style="font-family:var(--font-display);color:var(--mc-text)"
            >
              {@role.name}
            </h1>
            <p :if={@role.description} class="mt-1 text-sm" style="color:var(--mc-text-2)">
              {@role.description}
            </p>
          </div>
          <.link
            :if={not @role.builtin and can?(@current_scope, "role:update")}
            navigate={~p"/app/roles/#{@role.id}/edit"}
            class="mtb-btn mtb-btn-secondary mtb-btn-sm"
          >
            Edit role
          </.link>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
        <div class="space-y-6">
          <div class="mtb-card p-6">
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Permissions</div>
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
            <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Members</div>
            <p :if={@members == []} class="text-sm" style="color:var(--mc-text-3)">
              No members hold this role.
            </p>
            <ul :if={@members != []} class="space-y-2">
              <li :for={member <- @members} class="flex items-center justify-between gap-3">
                <span class="text-sm font-medium" style="color:var(--mc-text)">
                  {member_name(member)}
                  <span class="ml-1 font-mono text-xs" style="color:var(--mc-text-3)">{member.user.email}</span>
                </span>
                <.member_active_badge active={member.active} />
              </li>
            </ul>
          </div>
        </div>

        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
          <.audit_timeline logs={@logs} empty="No activity for this role yet." />
        </div>
      </div>
    </Layouts.workspace>
    """
  end

  # Catalog groups reduced to just the labels this role grants; empty groups dropped.
  defp granted_groups(role) do
    granted = MapSet.new(role.permissions)

    Permissions.catalog()
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
