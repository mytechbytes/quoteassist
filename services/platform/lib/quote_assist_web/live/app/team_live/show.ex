defmodule QuoteAssistWeb.App.TeamLive.Show do
  @moduledoc """
  Member detail (`/app/team/:id`): a member's identity, type/role/status, and their
  activity feed. Gated by `user:read`, and owner-protected at the query layer — a member
  can never open an owner's page (`Tenants.get_member_visible_to/2` returns nil, so we
  bounce to the team list).
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Membership
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "user:read")
    {:ok, load(socket, id)}
  end

  defp load(socket, id) do
    case Tenants.get_member_visible_to(socket.assigns.current_scope, id) do
      %Membership{} = member ->
        assign(socket,
          page_title: member_name(member),
          member: member,
          logs: Audit.list_for_target("user", member.id)
        )

      nil ->
        socket
        |> put_flash(:error, "That member no longer exists.")
        |> push_navigate(to: ~p"/app/team")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="team"
      breadcrumb={member_name(@member)}
    >
      <div class="mb-6">
        <.link navigate={~p"/app/team"} class="text-xs font-semibold" style="color:var(--mc-text-3)">
          ← Team
        </.link>
        <h1
          class="mt-1.5 text-2xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          {member_name(@member)}
        </h1>
        <div class="mt-1 font-mono text-sm" style="color:var(--mc-text-3)">{@member.user.email}</div>
        <div class="mt-2 flex items-center gap-2">
          <.member_type_badge type={@member.type} />
          <.member_active_badge active={@member.active} />
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1fr_1.2fr]">
        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Details</div>
          <dl class="space-y-3">
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Role
              </dt>
              <dd class="mt-0.5 text-sm" style="color:var(--mc-text)">
                {member_role_label(@member)}
              </dd>
            </div>
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Timezone
              </dt>
              <dd class="mt-0.5 text-sm" style="color:var(--mc-text)">
                {@member.user.timezone || "—"}
              </dd>
            </div>
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Joined
              </dt>
              <dd class="mt-0.5 font-mono text-sm" style="color:var(--mc-text)">
                {format_datetime(@member.inserted_at)}
              </dd>
            </div>
          </dl>
        </div>

        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
          <.audit_timeline logs={@logs} empty="No activity for this member yet." />
        </div>
      </div>
    </Layouts.workspace>
    """
  end
end
