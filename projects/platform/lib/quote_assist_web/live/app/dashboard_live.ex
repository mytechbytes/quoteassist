defmodule QuoteAssistWeb.App.DashboardLive do
  @moduledoc "Salesperson workspace shell (guarded by `:require_salesperson`)."
  use QuoteAssistWeb, :live_view

  @cards [
    {"Quotes", "R12", "Create, edit and clone quotes for your customers."},
    {"Pricing", "R13", "Price a quote against your tenant's active method."},
    {"Discounts & approvals", "R14",
     "Apply discounts within quota; route the rest for approval."},
    {"My dashboard", "R16", "Your day-at-a-glance over real quote data."}
  ]

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Workspace")}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :cards, @cards)

    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} title="Sales">
      <h1 class="font-display font-bold text-2xl tracking-[-0.02em]">Your workspace</h1>
      <p class="mt-1 text-sm" style="color:var(--mc-text-2);">
        {workspace_intro(@current_scope)}
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

  defp workspace_intro(%{tenant: %{name: name}, membership: %{seller_level: level}})
       when is_binary(level) do
    "#{level} seller at #{name}."
  end

  defp workspace_intro(%{tenant: %{name: name}}), do: "Selling at #{name}."
  defp workspace_intro(_), do: "Quote, discount and request approvals."
end
