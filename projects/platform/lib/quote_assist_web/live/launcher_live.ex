defmodule QuoteAssistWeb.LauncherLive do
  @moduledoc """
  Persona launcher (CC-01). Shows a card for each persona the signed-in user
  holds and routes into that workspace. Only personas backed by a membership are
  shown — the persona guards re-check on entry.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts

  @impl true
  def mount(_params, _session, socket) do
    memberships = Accounts.list_memberships(socket.assigns.current_scope.user)

    {:ok,
     socket
     |> assign(:page_title, "Choose your workspace")
     |> assign(:memberships, memberships)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ql-stage font-sans">
      <div class="mc-glow"></div>

      <div class="absolute top-5 right-5 z-20 flex items-center gap-1">
        <button
          type="button"
          class="mc-btn mc-btn-sm mc-btn-ghost mc-btn-icon"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="light"
          aria-label="Light theme"
        >
          <.icon name="hero-sun-micro" class="size-4" />
        </button>
        <button
          type="button"
          class="mc-btn mc-btn-sm mc-btn-ghost mc-btn-icon"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme="dark"
          aria-label="Dark theme"
        >
          <.icon name="hero-moon-micro" class="size-4" />
        </button>
        <.link href={~p"/users/log-out"} method="delete" class="mc-btn mc-btn-sm mc-btn-ghost">
          Log out
        </.link>
      </div>

      <div class="relative z-10 w-full" style="max-width:1040px;">
        <div class="flex flex-col items-center text-center mb-10">
          <div class="flex items-center gap-3 mb-6">
            <span class="mc-logo" style="width:42px;height:42px;font-size:18px;">QA</span>
            <span class="font-display font-bold text-2xl tracking-tight">QuoteAssist</span>
          </div>
          <h1 class="font-display font-bold text-4xl tracking-[-0.03em]" style="max-width:18ch;">
            Choose your workspace.
          </h1>
          <p class="mt-3 text-base" style="color:var(--mc-text-2); max-width:56ch;">
            Signed in as <span class="font-semibold">{@current_scope.user.email}</span>.
          </p>
        </div>

        <div :if={@memberships == []} class="mc-card text-center" style="padding:32px;">
          <h2 class="font-display font-bold text-lg">No workspaces yet</h2>
          <p class="mt-2 text-sm" style="color:var(--mc-text-2);">
            Your account isn't assigned to a workspace. Ask an administrator to invite you.
          </p>
        </div>

        <div :if={@memberships != []} class="ql-grid">
          <.link :for={m <- @memberships} navigate={path_for(m.persona)} class="ql-card">
            <span class="ql-card-arrow">
              <.icon name="hero-arrow-up-right" class="size-4" />
            </span>
            <span class="ql-card-ico">
              <.icon name={icon_for(m.persona)} class="size-6" />
            </span>
            <div class="font-display font-bold text-xl">{title_for(m.persona)}</div>
            <div class="text-sm mt-1" style="color:var(--mc-text-3);">{subtitle_for(m)}</div>
            <p class="text-sm mt-3 leading-relaxed" style="color:var(--mc-text-2);">
              {blurb_for(m.persona)}
            </p>
            <div
              class="mt-4 pt-4 flex flex-wrap gap-1.5"
              style="border-top:1px solid var(--mc-border);"
            >
              <span :for={tag <- tags_for(m.persona)} class="mc-badge mc-badge-neutral">{tag}</span>
            </div>
          </.link>
        </div>
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  defp path_for(:site_admin), do: ~p"/admin"
  defp path_for(:agency_admin), do: ~p"/agency"
  defp path_for(:salesperson), do: ~p"/app"

  defp title_for(:site_admin), do: "Site Administrator"
  defp title_for(:agency_admin), do: "Agency Admin"
  defp title_for(:salesperson), do: "Sales Person"

  defp icon_for(:site_admin), do: "hero-building-office-2"
  defp icon_for(:agency_admin), do: "hero-users"
  defp icon_for(:salesperson), do: "hero-receipt-percent"

  defp subtitle_for(%{persona: :site_admin}), do: "Platform operator"
  defp subtitle_for(%{persona: :agency_admin, tenant: tenant}), do: tenant_name(tenant)

  defp subtitle_for(%{persona: :salesperson, tenant: tenant, seller_level: level}) do
    [level, tenant_name(tenant)] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")
  end

  defp tenant_name(%{name: name}), do: name
  defp tenant_name(_), do: nil

  defp blurb_for(:site_admin),
    do: "Onboard agencies, define verticals and fields, set global guardrails and watch usage."

  defp blurb_for(:agency_admin),
    do:
      "Set discount quotas per seller level and category, manage salespeople, and clear approvals."

  defp blurb_for(:salesperson),
    do: "Apply a discount to a deal, see your live quota, and request approval when you go over."

  defp tags_for(:site_admin), do: ["Agencies", "Verticals", "Guardrails"]
  defp tags_for(:agency_admin), do: ["Quotas", "Approvals", "Salespeople"]
  defp tags_for(:salesperson), do: ["Apply discount", "Quota check", "My requests"]
end
