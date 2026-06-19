defmodule QuoteAssistWeb.TenantListLive do
  @moduledoc """
  Public tenant directory (`/tenants`) — lists live tenants, each linking out to its
  own subdomain login. No auth; served on the platform host.

  In the **dev environment only** it expands each tenant to show its seeded members
  (email, role, and the shared dev password) as a local testing aid. This panel is
  gated on `deploy_env == "dev"` and never renders in staging or production.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Membership

  @impl true
  def mount(_params, _session, socket) do
    dev? = Application.get_env(:quote_assist, :deploy_env) == "dev"

    tenants =
      if dev?, do: Tenants.list_live_tenants_with_members(), else: Tenants.list_live_tenants()

    {:ok, assign(socket, page_title: "Tenants", tenants: tenants, dev: dev?)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.directory tenants={@tenants} dev={@dev} />
    </Layouts.app>
    """
  end

  @doc """
  Renders the directory body. With `dev: true` it shows per-tenant member credentials;
  otherwise the compact public table. Public (not private) so both paths are
  unit-testable without standing up the full LiveView — see `TenantListLiveTest`.
  """
  attr :tenants, :list, required: true
  attr :dev, :boolean, default: false

  def directory(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl">
      <div class="mb-7">
        <span class="mtb-badge mtb-badge-brand">Directory</span>
        <h1
          class="mt-3 text-2xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          Tenants
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          Organisations using QuoteAssist. Each entry links to its own workspace login.
        </p>
      </div>

      <div
        :if={@dev}
        class="mtb-card mb-5 flex items-start gap-3 px-4 py-3"
        style="border-color:color-mix(in oklch,var(--mc-warning) 40%,transparent);background:color-mix(in oklch,var(--mc-warning) 10%,var(--mc-surface))"
      >
        <.icon
          name="hero-exclamation-triangle"
          class="mt-0.5 size-4 shrink-0"
          style="color:var(--mc-warning)"
        />
        <p class="text-xs" style="color:var(--mc-text-2);line-height:1.5">
          <span class="font-semibold" style="color:var(--mc-text)">Development only.</span>
          Seeded accounts and passwords are listed for local testing. This panel never
          renders outside the dev environment.
        </p>
      </div>

      <div :if={@tenants == []} class="mtb-card px-6 py-14 text-center">
        <p class="text-sm font-semibold" style="color:var(--mc-text)">No tenants yet</p>
        <p class="mx-auto mt-1 max-w-sm text-sm" style="color:var(--mc-text-3)">
          The directory populates once organisations are onboarded. Tenant
          management ships in R3.
        </p>
      </div>

      <%!-- Dev: each tenant as a card with its members + credentials. --%>
      <div :if={@dev and @tenants != []} class="space-y-4">
        <div :for={tenant <- @tenants} class="mtb-card overflow-hidden">
          <div
            class="flex items-center justify-between gap-3 px-5 py-4"
            style="border-bottom:1px solid var(--mc-border)"
          >
            <div class="min-w-0">
              <div class="text-sm font-semibold" style="color:var(--mc-text)">{tenant.name}</div>
              <div class="font-mono text-xs" style="color:var(--mc-text-3)">{tenant.slug}</div>
            </div>
            <div class="flex items-center gap-2">
              <span class="mtb-badge mtb-badge-neutral">{tenant.status}</span>
              <a href={tenant_login_url(tenant.slug)} class="mtb-btn mtb-btn-secondary mtb-btn-sm">
                Login →
              </a>
            </div>
          </div>

          <p
            :if={tenant.memberships == []}
            class="px-5 py-4 text-sm"
            style="color:var(--mc-text-3)"
          >
            No members yet.
          </p>

          <table :if={tenant.memberships != []} class="mtb-table">
            <thead>
              <tr style="border-bottom:1px solid var(--mc-border)">
                <th class="px-5 py-2.5 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                  User
                </th>
                <th
                  class="px-4 py-2.5 text-left text-xs font-semibold"
                  style="color:var(--mc-text-3);width:8rem"
                >
                  Role
                </th>
                <th
                  class="px-4 py-2.5 text-left text-xs font-semibold"
                  style="color:var(--mc-text-3);width:12rem"
                >
                  Password
                </th>
              </tr>
            </thead>
            <tbody>
              <tr :for={m <- tenant.memberships} style="border-top:1px solid var(--mc-border)">
                <td class="px-5 py-2.5 align-middle text-sm" style="color:var(--mc-text)">
                  {m.user.email}
                </td>
                <td class="px-4 py-2.5 align-middle">
                  <span class="mtb-badge mtb-badge-neutral">{Membership.role_label(m)}</span>
                </td>
                <td class="px-4 py-2.5 align-middle text-sm">
                  <span
                    :if={m.user.hashed_password}
                    class="font-mono"
                    style="user-select:all;color:var(--mc-text)"
                  >
                    {dev_password()}
                  </span>
                  <span :if={!m.user.hashed_password} style="color:var(--mc-text-3)">
                    magic link only
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Public (non-dev): compact directory table. --%>
      <div :if={not @dev and @tenants != []} class="mtb-card overflow-hidden">
        <table class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Tenant
              </th>
              <th
                class="px-4 py-3 text-left text-xs font-semibold"
                style="color:var(--mc-text-3);width:9rem"
              >
                Status
              </th>
              <th class="px-4 py-3 text-right" style="width:9rem">
                <span class="sr-only">Login</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={tenant <- @tenants} style="border-top:1px solid var(--mc-border)">
              <td class="px-4 py-3 align-middle text-sm font-semibold" style="color:var(--mc-text)">
                {tenant.name}
              </td>
              <td class="px-4 py-3 align-middle">
                <span class="mtb-badge mtb-badge-neutral">{tenant.status}</span>
              </td>
              <td class="px-4 py-3 align-middle text-right">
                <a href={tenant_login_url(tenant.slug)} class="mtb-btn mtb-btn-secondary mtb-btn-sm">
                  Login →
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Per-tenant subdomain login URL, e.g.
  # `https://acme.quoteassist.mytechbytes.in/login` (dev: `http://acme.quoteassist.localhost:4000/login`).
  # Scheme + base host come from config (config/config.exs, overridden in config/dev.exs).
  defp tenant_login_url(slug) do
    scheme = Application.get_env(:quote_assist, :tenant_url_scheme, "https")
    base = Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.mytechbytes.in")
    "#{scheme}://#{slug}.#{base}/login"
  end

  # The shared password the dev seed sets for confirmed accounts. Mirrors the default
  # in priv/repo/seeds.exs; override both via DEV_USER_PASSWORD. Dev-only — this is
  # only ever rendered when deploy_env == "dev".
  defp dev_password, do: System.get_env("DEV_USER_PASSWORD", "panther@2010")
end
