defmodule QuoteAssistWeb.Admin.AdminLive.Show do
  @moduledoc """
  Administrator detail (`/admin/admins/:id`) — read-only: identity, last sign-in, and
  the audit trail of actions this admin has taken.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Accounts
  alias QuoteAssist.Audit

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_admin(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That administrator no longer exists.")
         |> push_navigate(to: ~p"/admin/admins")}

      admin ->
        {:ok,
         assign(socket,
           page_title: admin.email,
           admin: admin,
           logs: Audit.list_for_admin(admin.id)
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_admin={@current_admin}
      active="admins"
      breadcrumb={@admin.email}
    >
      <div class="mb-6">
        <.link
          navigate={~p"/admin/admins"}
          class="text-xs font-semibold"
          style="color:var(--mc-text-3)"
        >
          ← Administrators
        </.link>
        <h1
          class="mt-1.5 text-2xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          {@admin.email}
        </h1>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1fr_1.2fr]">
        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Details</div>
          <dl class="space-y-3">
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Last sign-in
              </dt>
              <dd class="mt-0.5 font-mono text-sm" style="color:var(--mc-text)">
                {format_datetime(@admin.last_sign_in_at)}
              </dd>
            </div>
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Added
              </dt>
              <dd class="mt-0.5 font-mono text-sm" style="color:var(--mc-text)">
                {format_datetime(@admin.inserted_at)}
              </dd>
            </div>
          </dl>
        </div>

        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
          <.audit_timeline logs={@logs} empty="This administrator hasn't taken any actions yet." />
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
