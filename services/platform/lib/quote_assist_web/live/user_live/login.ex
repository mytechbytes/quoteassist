defmodule QuoteAssistWeb.UserLive.Login do
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts
  alias QuoteAssist.Tenants
  alias QuoteAssistWeb.Plugs.LoginThrottle

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid min-h-screen lg:grid-cols-2">
      <%!-- Brand panel (hidden below lg, per the design) --%>
      <aside class="mtb-auth-aside hidden flex-col p-14 lg:flex">
        <a href="/" class="relative flex items-center gap-2.5 no-underline" style="color:inherit">
          <span class="mtb-logo" style="width:36px;height:36px;font-size:15px">QA</span>
          <span style="font-family:var(--font-display);font-weight:700;font-size:1.125rem">
            QuoteAssist
          </span>
        </a>

        <div class="relative flex flex-1 items-center">
          <div>
            <div class="mb-5 text-sm font-semibold uppercase tracking-widest opacity-80">
              Paste · Price · Approve
            </div>
            <h1
              class="font-bold tracking-tight"
              style="font-family:var(--font-display);font-size:3rem;line-height:1.03"
            >
              Welcome back.<br />There's a quote<br />waiting to be sent.
            </h1>
            <p class="mt-6 max-w-md text-lg opacity-90" style="line-height:1.55">
              Sign in to turn inbound enquiries into polished, policy-checked quotations —
              without leaving your browser.
            </p>
          </div>
        </div>

        <figure class="relative max-w-md border-l-2 pl-5" style="border-color:rgb(255 255 255 / 0.4)">
          <blockquote style="font-family:var(--font-display);font-size:1.25rem;line-height:1.4">
            "What took twenty minutes per enquiry now takes one. The drafts come out cleaner than mine did."
          </blockquote>
          <figcaption class="mt-4 flex items-center gap-3 text-sm opacity-90">
            <span
              class="grid h-9 w-9 place-items-center rounded-full text-xs font-bold"
              style="background:rgb(255 255 255 / 0.2)"
            >
              RA
            </span>
            <span><b>Rana Aziz</b> · Senior agent, Skyline Travel</span>
          </figcaption>
        </figure>
      </aside>

      <%!-- Form panel --%>
      <main
        class="relative flex items-center justify-center p-6 sm:p-10"
        style="background:var(--mc-bg)"
      >
        <div class="absolute right-6 top-6">
          <Layouts.theme_toggle />
        </div>

        <div class="mtb-auth-card">
          <a
            href="/"
            class="mb-8 flex items-center gap-2 no-underline lg:hidden"
            style="color:var(--mc-text)"
          >
            <span class="mtb-logo" style="width:28px;height:28px;font-size:12px">QA</span>
            <span style="font-family:var(--font-display);font-weight:700">QuoteAssist</span>
          </a>

          <h1
            class="text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Sign in
          </h1>
          <p :if={!@current_scope} class="mt-2 text-sm" style="color:var(--mc-text-2)">
            Use your agency account. Invited agents should sign in with their work email.
          </p>
          <p :if={@current_scope} class="mt-2 text-sm" style="color:var(--mc-text-2)">
            You need to reauthenticate to perform sensitive actions on your account.
          </p>

          <%!-- Dev-only: emails are captured locally rather than sent --%>
          <div
            :if={local_mail_adapter?()}
            class="mtb-card mt-6 flex items-start gap-3 p-3 text-xs"
            style="background:var(--mc-surface-2)"
          >
            <.icon
              name="hero-information-circle"
              class="mt-0.5 size-4 shrink-0"
              style="color:var(--mc-text-3)"
            />
            <div style="color:var(--mc-text-2);line-height:1.5">
              Local mail adapter is on — sent emails show up at <.link
                href="/dev/mailbox"
                class="font-semibold"
                style="color:var(--mc-brand)"
              >
                /dev/mailbox
              </.link>.
            </div>
          </div>

          <%!-- Password sign-in --%>
          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/login"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="mt-7 space-y-4"
          >
            <.input
              field={f[:email]}
              type="email"
              label="Work email"
              autocomplete="username"
              spellcheck="false"
              readonly={!!@current_scope}
              placeholder="rana@skylinetravel.com"
              class="mtb-input mtb-input-lg"
              required
            />

            <div>
              <div class="mb-1.5 flex items-center justify-between">
                <label for={f[:password].id} class="mtb-label" style="margin:0">Password</label>
                <%!-- /forgot lands in R6 (account flows) --%>
                <a href="/forgot" class="text-xs font-semibold" style="color:var(--mc-brand)">
                  Forgot?
                </a>
              </div>
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

            <label class="flex items-center gap-2 text-sm" style="color:var(--mc-text-2)">
              <input
                type="checkbox"
                name={f[:remember_me].name}
                value="true"
                class="size-4 rounded"
                style="accent-color:var(--mc-brand)"
              /> Keep me signed in for 14 days
            </label>

            <.button
              class="mtb-btn mtb-btn-lg mtb-btn-primary w-full"
              phx-disable-with="Signing in…"
            >
              Sign in <span aria-hidden="true">→</span>
            </.button>
          </.form>

          <div class="my-6 flex items-center gap-3">
            <div class="mtb-divider flex-1"></div>
            <span class="text-xs font-medium" style="color:var(--mc-text-3)">or with a magic link</span>
            <div class="mtb-divider flex-1"></div>
          </div>

          <%!-- Magic-link sign-in (emails a one-time login link) --%>
          <.form
            :let={fm}
            for={@form}
            id="login_form_magic"
            action={~p"/login"}
            phx-submit="submit_magic"
            class="space-y-4"
          >
            <.input
              field={fm[:email]}
              type="email"
              label="Work email"
              autocomplete="username"
              spellcheck="false"
              readonly={!!@current_scope}
              placeholder="rana@skylinetravel.com"
              class="mtb-input mtb-input-lg"
              required
            />
            <.button class="mtb-btn mtb-btn-lg mtb-btn-secondary w-full">
              Email me a login link <span aria-hidden="true">→</span>
            </.button>
          </.form>

          <%!-- Unconfirmed-owner safety net (R5-selfreg): a self-registered owner who
                hasn't finished onboarding isn't stranded at a dead password form —
                the setup link (or a magic link above, which confirms + signs them in)
                always gets them in. --%>
          <p :if={!@current_scope} class="mt-7 text-center text-sm" style="color:var(--mc-text-3)">
            Just created your workspace? Open the setup link we emailed to finish — or request a
            magic link above to continue.
          </p>

          <p :if={!@current_scope} class="mt-3 text-center text-sm" style="color:var(--mc-text-3)">
            New here?
            <a href="/register" class="font-semibold" style="color:var(--mc-brand)">Create account →</a>
          </p>
        </div>
      </main>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  @impl true
  def mount(_params, session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    socket =
      assign(socket,
        form: form,
        trigger_submit: false,
        request_uri: nil,
        tenant: Tenants.fetch_live_tenant(session["tenant_id"])
      )

    {:ok, socket}
  end

  @impl true
  # Capture the request URL so the magic link is built on the *same* host the user
  # is on (their tenant subdomain / custom domain). Cookies are host-scoped, so the
  # whole magic-link flow must stay on that host for the session to be valid at /app.
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :request_uri, uri)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if LoginThrottle.magic_link_throttled?(email) do
      {:noreply,
       put_flash(socket, :error, "Too many attempts. Please wait a minute and try again.")}
    else
      # Only send to a member of the resolved tenant — a user of another tenant gets
      # the same neutral response (no cross-tenant enumeration), and no link.
      tenant = socket.assigns.tenant
      user = Accounts.get_user_by_email(email)

      if tenant && user && Tenants.member?(tenant, user) do
        Accounts.deliver_login_instructions(user, &magic_link_url(socket.assigns.request_uri, &1))
      end

      info =
        "If your email is in our system, you will receive instructions for logging in shortly."

      {:noreply,
       socket
       |> put_flash(:info, info)
       |> push_navigate(to: ~p"/login")}
    end
  end

  @doc """
  Builds the magic-link URL for `token` on the host of `request_uri` (the tenant
  subdomain or custom domain the user is on), so the emailed link returns them to
  the same host. Falls back to the endpoint-configured host when no request URI is
  available. Public so it can be unit-tested without sending an email.
  """
  def magic_link_url(request_uri, token) when is_binary(request_uri) do
    %URI{URI.parse(request_uri) | path: ~p"/login/#{token}", query: nil, fragment: nil}
    |> URI.to_string()
  end

  def magic_link_url(_request_uri, token), do: url(~p"/login/#{token}")

  defp local_mail_adapter? do
    Application.get_env(:quote_assist, QuoteAssist.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
