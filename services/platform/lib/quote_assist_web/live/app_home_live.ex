defmodule QuoteAssistWeb.AppHomeLive do
  @moduledoc """
  Minimal authenticated landing for signed-in users (`/app`).

  R1 ships this as a placeholder that proves authentication works end to end: the
  route is guarded by `on_mount {QuoteAssistWeb.UserAuth, :require_authenticated}`,
  so reaching it requires a logged-in user and everyone else is redirected to
  `/login`. Tenant scoping (`:require_tenant_member`) and the real workspace shell
  arrive in R2.
  """
  use QuoteAssistWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Workspace")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl">
        <span class="mtb-badge mtb-badge-success">Signed in</span>
        <h1
          class="mt-3 text-2xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          Welcome back
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          You're signed in as <span class="font-medium" style="color:var(--mc-text)">{@current_scope.user.email}</span>.
          This is a placeholder workspace — your tenant dashboard lands in R2.
        </p>

        <div class="mtb-card mt-6 px-6 py-8">
          <p class="text-sm" style="color:var(--mc-text-2)">
            Nothing here yet. Tenant resolution and role-scoped access arrive in R2;
            quote requests and the AI reply hook follow in R7–R8.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
