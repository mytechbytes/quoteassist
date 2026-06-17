defmodule QuoteAssistWeb.Admin.LoginLive do
  @moduledoc """
  Site-admin sign in (`/admin/login`) — password only (no magic link, no remember-me,
  no self-registration). Platform host only. Submits to `AdminSessionController` via a
  trigger-action form, throttled by the shared `LoginThrottle` plug.
  """
  use QuoteAssistWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid min-h-screen lg:grid-cols-2">
      <aside class="mtb-auth-aside hidden flex-col p-14 lg:flex">
        <div class="relative flex items-center gap-2.5">
          <span class="mtb-logo" style="width:36px;height:36px;font-size:15px">QA</span>
          <span style="font-family:var(--font-display);font-weight:700;font-size:1.125rem">
            QuoteAssist
          </span>
          <span class="mtb-app-tag" style="background:rgb(255 255 255 / 0.18);color:#fff">Admin</span>
        </div>

        <div class="relative flex flex-1 items-center">
          <div>
            <div class="mb-5 text-sm font-semibold uppercase tracking-widest opacity-80">
              Platform console
            </div>
            <h1
              class="font-bold tracking-tight"
              style="font-family:var(--font-display);font-size:3rem;line-height:1.03"
            >
              Run the platform.<br />Onboard agencies,<br />manage their trials.
            </h1>
            <p class="mt-6 max-w-md text-lg opacity-90" style="line-height:1.55">
              Create and manage tenants, plans and trials. Staff access only — separate
              from any agency account.
            </p>
          </div>
        </div>
      </aside>

      <main
        class="relative flex items-center justify-center p-6 sm:p-10"
        style="background:var(--mc-bg)"
      >
        <div class="absolute right-6 top-6">
          <Layouts.theme_toggle />
        </div>

        <div class="mtb-auth-card">
          <span class="mtb-app-tag">Admin</span>
          <h1
            class="mt-3 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Administrator sign in
          </h1>
          <p class="mt-2 text-sm" style="color:var(--mc-text-2)">
            Staff access to the QuoteAssist platform console.
          </p>

          <.form
            :let={f}
            for={@form}
            id="admin_login_form"
            action={~p"/admin/login"}
            phx-submit="submit"
            phx-trigger-action={@trigger_submit}
            class="mt-7 space-y-4"
          >
            <.input
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              placeholder="admin@quoteassist.app"
              class="mtb-input mtb-input-lg"
              required
            />

            <div>
              <label for={f[:password].id} class="mtb-label">Password</label>
              <div class="relative">
                <input
                  id={f[:password].id}
                  name={f[:password].name}
                  type="password"
                  autocomplete="current-password"
                  spellcheck="false"
                  placeholder="••••••••"
                  class="mtb-input mtb-input-lg pr-11"
                />
                <button
                  type="button"
                  phx-click={
                    JS.toggle_attribute({"type", "text", "password"}, to: "##{f[:password].id}")
                  }
                  class="mtb-btn mtb-btn-sm mtb-btn-icon mtb-btn-ghost absolute right-2 top-1/2 -translate-y-1/2"
                  aria-label="Show password"
                >
                  <.icon name="hero-eye" class="size-4" />
                </button>
              </div>
            </div>

            <.button
              class="mtb-btn mtb-btn-lg mtb-btn-primary w-full"
              phx-disable-with="Signing in…"
            >
              Sign in <span aria-hidden="true">→</span>
            </.button>
          </.form>
        </div>
      </main>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_admin] do
      {:ok, push_navigate(socket, to: ~p"/admin")}
    else
      email = Phoenix.Flash.get(socket.assigns.flash, :email)

      {:ok,
       assign(socket, form: to_form(%{"email" => email}, as: "admin"), trigger_submit: false)}
    end
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
