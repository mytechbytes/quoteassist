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

      <div class="ml-auto flex items-center gap-3">
        <.theme_toggle />
      </div>
    </header>

    <main class="px-6 py-8">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
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
    <div
      class="relative flex flex-row items-center rounded-full"
      style="background:var(--mc-surface-2);border:1px solid var(--mc-border);padding:3px;gap:2px"
    >
      <%# Sliding indicator — positioned by JS-set data-theme on <html> %>
      <div
        class="absolute h-[calc(100%-6px)] rounded-full transition-[left]"
        style="width:calc(33.33% - 2px);top:3px;left:3px;background:var(--mc-surface);box-shadow:0 1px 3px rgb(0 0 0 / 0.10);
               [[data-theme=light]_&]:left-[calc(33.33%+1px)];[[data-theme=dark]_&]:left-[calc(66.66%-1px)]"
      />

      <button
        class="flex p-1.5 cursor-pointer rounded-full relative z-10"
        style="color:var(--mc-text-3)"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        class="flex p-1.5 cursor-pointer rounded-full relative z-10"
        style="color:var(--mc-text-3)"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        class="flex p-1.5 cursor-pointer rounded-full relative z-10"
        style="color:var(--mc-text-3)"
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
