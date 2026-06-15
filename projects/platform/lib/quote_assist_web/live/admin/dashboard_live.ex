defmodule QuoteAssistWeb.Admin.DashboardLive do
  @moduledoc "Site-administrator workspace shell (guarded by `:require_site_admin`)."
  use QuoteAssistWeb, :live_view

  @cards [
    {"Verticals", "R3", "Tenant types, categories and the platform discount ceiling."},
    {"Plans", "R4", "Subscription plans — seats, price and feature flags."},
    {"Tenants", "R5", "Create, configure, suspend and remove agencies."},
    {"Tenant config", "R6", "Per-tenant versioned configuration."}
  ]

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Site Admin")}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :cards, @cards)

    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} title="Site Admin">
      <h1 class="font-display font-bold text-2xl tracking-[-0.02em]">Platform overview</h1>
      <p class="mt-1 text-sm" style="color:var(--mc-text-2);">
        Welcome back, {@current_scope.user.email} — you operate the platform across every tenant.
      </p>

      <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 mt-7">
        <div :for={{title, release, desc} <- @cards} class="mc-card" style="padding:18px;">
          <div class="flex items-center justify-between">
            <span class="font-display font-bold">{title}</span>
            <span class="mc-badge mc-badge-neutral">{release}</span>
          </div>
          <p class="mt-2 text-sm" style="color:var(--mc-text-2); line-height:1.5;">{desc}</p>
        </div>
      </div>
    </Layouts.workspace>
    """
  end
end
