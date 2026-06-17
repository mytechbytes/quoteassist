defmodule QuoteAssistWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use QuoteAssistWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <header class="mtb-topbar px-6">
        <a href="/" class="flex items-center gap-3 no-underline" style="color:var(--mc-text)">
          <span
            class="mtb-logo"
            style="width:32px;height:32px;font-size:13px;letter-spacing:-0.04em;color:white"
          >
            QA
          </span>
          <span style="font-family:var(--font-display);font-weight:700;font-size:1rem;letter-spacing:-0.02em">
            QuoteAssist
          </span>
        </a>

        <nav class="ml-auto flex items-center gap-2 sm:gap-3">
          <.link navigate={~p"/tenants"} class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            Tenants
          </.link>
          <%!-- /admin/login lands in R3 — plain href avoids a verified-route warning until then. --%>
          <a href="/admin/login" class="mtb-btn mtb-btn-secondary mtb-btn-sm">Admin login</a>
          <.theme_toggle />
        </nav>
      </header>

      <main class="w-full flex-1 px-4 py-10 sm:px-6">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t" style="border-color:var(--mc-border)">
        <div
          class="mx-auto flex w-full max-w-3xl items-center justify-between px-4 py-5 text-xs sm:px-6"
          style="color:var(--mc-text-3)"
        >
          <span>QuoteAssist · multi-tenant quote assistant</span>
          <span class="font-mono">v{app_version()} · {deploy_env()}</span>
        </div>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Application version string for the footer, e.g. `"0.1.0"`.

  Falls back to `"dev"` when the app spec has no version (e.g. not yet loaded).
  """
  def app_version do
    case Application.spec(:quote_assist, :vsn) do
      nil -> "dev"
      vsn -> to_string(vsn)
    end
  end

  @doc """
  Deployment environment tag for the footer: `dev | staging | prod`.

  Set from `DEPLOY_ENV` at runtime (see `config/runtime.exs`); defaults to `dev`.
  """
  def deploy_env do
    Application.get_env(:quote_assist, :deploy_env, "dev")
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="mtb-theme-toggle">
      <%!-- Sliding indicator — positioned via mtb.css from data-theme/-source on <html> --%>
      <div class="mtb-theme-slider" aria-hidden="true"></div>

      <button
        class="mtb-theme-btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        class="mtb-theme-btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        class="mtb-theme-btn"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
