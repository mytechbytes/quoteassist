defmodule QuoteAssistWeb.AppHomeLive do
  @moduledoc """
  Tenant workspace landing (`/app`). Guarded by `on_mount :require_tenant_member`:
  reaching it requires a logged-in user with a live membership for the tenant
  resolved from the host, so `current_scope` always carries a tenant and membership.
  R2 ships the empty shell; team/roles (R7-rbac), the dashboard (R8-dashboard), quote
  requests (R11-quotes), and the AI reply hook (R12-quote-reply) render into it later.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Tenants.Membership

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Workspace")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} active="overview">
      <div
        :if={is_nil(@current_scope.user.hashed_password)}
        class="mtb-card mb-6 flex items-start gap-3 px-5 py-4"
        style="border-color:color-mix(in oklch,var(--mc-warning) 40%,transparent);background:color-mix(in oklch,var(--mc-warning) 10%,var(--mc-surface))"
      >
        <.icon name="hero-sparkles" class="mt-0.5 size-5 shrink-0" style="color:var(--mc-warning)" />
        <div class="min-w-0 flex-1">
          <p class="text-sm font-semibold" style="color:var(--mc-text)">
            Finish setting up your account
          </p>
          <p class="mt-0.5 text-sm" style="color:var(--mc-text-2)">
            Set your name and a password so you can sign in without a magic link.
          </p>
          <.link navigate={~p"/app/welcome"} class="mtb-btn mtb-btn-primary mtb-btn-sm mt-3">
            Set up account <span aria-hidden="true">→</span>
          </.link>
        </div>
      </div>

      <div class="mb-7">
        <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
          Workspace · Overview
        </div>
        <h1
          class="mt-1.5 text-2xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          {@current_scope.tenant.name}
        </h1>
        <p class="mt-1.5 flex flex-wrap items-center gap-2 text-sm" style="color:var(--mc-text-2)">
          Signed in as
          <span class="font-medium" style="color:var(--mc-text)">{@current_scope.user.email}</span>
          <span class="mtb-badge mtb-badge-brand">{Membership.role_label(@current_scope.membership)}</span>
        </p>
      </div>

      <div class="mtb-card px-6 py-8">
        <p class="text-sm" style="color:var(--mc-text-2)">
          Your workspace is ready and scoped to <span class="font-medium" style="color:var(--mc-text)">{@current_scope.tenant.name}</span>.
          Team and roles arrive in R7-rbac; quote requests and the AI reply hook follow in R11–R12.
        </p>
      </div>
    </Layouts.workspace>
    """
  end
end
