defmodule QuoteAssistWeb.TenantListLive do
  @moduledoc """
  Public tenant directory (`/tenants`) — lists live tenants, each linking out to
  its own subdomain login. No auth; served on the platform host only.

  R0a ships this page with an empty directory: the `Tenant` schema and `tenants`
  table land in R2. When they do, replace the empty `tenants` assign in `mount/3`
  with the live-tenants query (`deleted_at IS NULL`, ordered by name). The
  `directory/1` component below already renders rows, so no template change is
  needed then.
  """
  use QuoteAssistWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # R2: tenants = QuoteAssist.Tenants.list_live_tenants() — name, slug, status.
    {:ok, assign(socket, page_title: "Tenants", tenants: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.directory tenants={@tenants} />
    </Layouts.app>
    """
  end

  @doc """
  Renders the directory body: a table of tenants, or an empty state.

  Public (not private) so the populated path is unit-testable without standing up
  the full LiveView — see `TenantListLiveTest`.
  """
  attr :tenants, :list, required: true

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

      <div :if={@tenants == []} class="mtb-card px-6 py-14 text-center">
        <p class="text-sm font-semibold" style="color:var(--mc-text)">No tenants yet</p>
        <p class="mx-auto mt-1 max-w-sm text-sm" style="color:var(--mc-text-3)">
          The directory populates once organisations are onboarded. Tenant
          management ships in R3.
        </p>
      </div>

      <div :if={@tenants != []} class="mtb-card overflow-hidden">
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
              <td
                class="px-4 py-3 align-middle text-sm font-semibold"
                style="color:var(--mc-text)"
              >
                {tenant.name}
              </td>
              <td class="px-4 py-3 align-middle">
                <span class="mtb-badge mtb-badge-neutral">{tenant.status}</span>
              </td>
              <td class="px-4 py-3 align-middle text-right">
                <a
                  href={tenant_login_url(tenant.slug)}
                  class="mtb-btn mtb-btn-secondary mtb-btn-sm"
                >
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
  # `https://acme.quoteassist.mytechbytes.in/login` (dev: `http://acme.lvh.me:4000/login`).
  # Scheme + base host come from config (config/config.exs, overridden in config/dev.exs).
  defp tenant_login_url(slug) do
    scheme = Application.get_env(:quote_assist, :tenant_url_scheme, "https")
    base = Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.mytechbytes.in")
    "#{scheme}://#{slug}.#{base}/login"
  end
end
