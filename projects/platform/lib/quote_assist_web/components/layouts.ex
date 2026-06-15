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
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://phoenix.hexdocs.pm/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Split-screen shell for the public auth screens (login / register / confirm).

  The left aside carries the brand; the right side renders the form slot with a
  compact theme toggle. Build the form content with `mc-*` / `qa-*` classes.

  ## Examples

      <Layouts.auth flash={@flash}>
        <h1 class="font-display font-bold text-3xl">Sign in</h1>
        ...
      </Layouts.auth>
  """
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  slot :inner_block, required: true

  def auth(assigns) do
    ~H"""
    <div class="qa-auth font-sans">
      <aside class="qa-auth-aside">
        <a href={~p"/"} class="flex items-center gap-2.5 relative no-underline text-inherit">
          <span
            class="mc-logo"
            style="width:36px;height:36px;background:rgb(255 255 255 / 0.18);border:1px solid rgb(255 255 255 / 0.25);"
          >
            QA
          </span>
          <span class="font-display font-bold text-lg">QuoteAssist</span>
        </a>

        <div class="flex-1 flex items-center relative">
          <div>
            <div class="text-sm font-semibold tracking-widest uppercase opacity-80 mb-5">
              Paste · Price · Approve
            </div>
            <h1 class="font-display font-bold tracking-[-0.025em] text-5xl leading-[1.02]">
              Turn inbound enquiries<br />into polished, policy-checked<br />quotations.
            </h1>
            <p class="mt-6 text-lg opacity-85 max-w-md leading-relaxed">
              Human-in-the-loop from capture to send — pricing, discount approvals and
              audit, without leaving your browser.
            </p>
          </div>
        </div>

        <figure class="border-l-2 pl-5 max-w-md relative" style="border-color:rgb(255 255 255 / 0.4);">
          <blockquote class="font-display text-xl leading-snug">
            "What took twenty minutes per enquiry now takes one. The drafts come out cleaner than mine did."
          </blockquote>
          <figcaption class="mt-4 text-sm flex items-center gap-3 opacity-90">
            <span
              class="w-9 h-9 rounded-full grid place-items-center text-xs font-bold"
              style="background:rgb(255 255 255 / 0.2);"
            >
              RA
            </span>
            <span><b>Rana Aziz</b> · Senior agent, Skyline Travel</span>
          </figcaption>
        </figure>
      </aside>

      <main class="qa-auth-form">
        <div class="absolute top-6 right-6 flex items-center gap-1">
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
        </div>

        <div class="qa-auth-card">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Persona workspace shell (Admin / Agency / App) — a top bar with the active
  persona + tenant, workspace switcher, settings and log out, plus a content slot.

  Full per-workspace navigation arrives in later releases; R2 ships the chrome.
  """
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :current_scope, :map, required: true, doc: "the active scope (persona + tenant)"
  attr :title, :string, required: true, doc: "the workspace label, e.g. \"Site Admin\""
  slot :inner_block, required: true

  def workspace(assigns) do
    ~H"""
    <div class="min-h-screen font-sans" style="background:var(--mc-bg);">
      <header
        class="flex flex-wrap items-center gap-3 px-4 sm:px-6 lg:px-8 py-3 border-b"
        style="border-color:var(--mc-border);background:var(--mc-surface);"
      >
        <a href={~p"/launcher"} class="flex items-center gap-2 no-underline text-inherit">
          <span class="mc-logo" style="width:30px;height:30px;font-size:13px;">QA</span>
          <span class="font-display font-bold">QuoteAssist</span>
        </a>
        <span class="mc-badge mc-badge-brand">{@title}</span>
        <span :if={@current_scope.tenant} class="text-sm" style="color:var(--mc-text-3);">
          {@current_scope.tenant.name}
        </span>

        <div class="ml-auto flex items-center gap-2">
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
          <span class="text-sm hidden md:inline" style="color:var(--mc-text-2);">
            {@current_scope.user.email}
          </span>
          <.link navigate={~p"/launcher"} class="mc-btn mc-btn-sm mc-btn-ghost">Switch</.link>
          <.link href={~p"/users/settings"} class="mc-btn mc-btn-sm mc-btn-ghost">Settings</.link>
          <.link href={~p"/users/log-out"} method="delete" class="mc-btn mc-btn-sm mc-btn-secondary">
            Log out
          </.link>
        </div>
      </header>

      <main class="px-4 sm:px-6 lg:px-8 py-8">
        <div class="mx-auto" style="max-width:1100px;">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

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
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
