defmodule QuoteAssistWeb.Agency.DashboardLive do
  @moduledoc "Tenant-admin (agency owner) workspace shell (guarded by `:require_agency_admin`)."
  use QuoteAssistWeb, :live_view

  @cards [
    {"Settings & branding", "R8", "Org profile, currency, signature and email templates."},
    {"Users & roles", "R9", "Invite users and compose roles from the permission catalog."},
    {"Approvals & quotas", "R10", "The discount approval chain and per-level quotas."},
    {"Pricing method", "R11", "API or managed price-book pricing for the tenant."}
  ]

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Agency")}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :cards, @cards)

    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} title="Agency Admin">
      <h1 class="font-display font-bold text-2xl tracking-[-0.02em]">
        {@current_scope.tenant.name}
      </h1>
      <p class="mt-1 text-sm" style="color:var(--mc-text-2);">
        Configure your organisation — people, roles, approvals and pricing.
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
