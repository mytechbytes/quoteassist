defmodule QuoteAssistWeb.OnboardingSetupLive do
  @moduledoc """
  Self-service owner onboarding (`/onboarding/:token`, platform host only — gated by
  `RequirePlatform`). Reached from the email link sent by
  `Tenants.register_self_service/1`. The owner sets an initial password, which also
  confirms their email (one transaction); they're then sent to their tenant's own-host
  login to sign in (RELEASE_PLAN.md R5-selfreg).

  Distinct from `QuoteAssistWeb.OnboardingLive` (`/app/welcome`), the R3 path where an
  admin-invited owner is already logged in via a magic link and only sets a name +
  password. This flow is token-based, anonymous, and lives on the platform host so it
  also serves invited users later (R7-rbac) regardless of host state.

  Three states:

    * `:setup`   — valid token, owner not yet set up → password form.
    * `:done`    — password set (or a reused owner already set up) → link to sign in.
    * `:invalid` — expired / unknown / used token → resend form (neutral response).
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts
  alias QuoteAssist.Tenants

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket = assign(socket, token: token)

    case Accounts.get_user_by_onboarding_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Setup link", state: :invalid)
         |> assign(:resend_form, to_form(%{"email" => ""}, as: "resend"))}

      user ->
        if onboarded?(user) do
          {:ok,
           assign(socket, page_title: "You're all set", state: :done, login_url: login_url(user))}
        else
          {:ok,
           socket
           |> assign(page_title: "Set your password", state: :setup, user: user)
           |> assign(:form, to_form(Accounts.change_owner_onboarding(user)))}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative grid min-h-screen place-items-center p-6" style="background:var(--mc-bg)">
      <a
        href="/"
        class="absolute left-6 top-6 flex items-center gap-2.5 no-underline"
        style="color:var(--mc-text)"
      >
        <span class="mtb-logo" style="width:28px;height:28px;font-size:12px">QA</span>
        <span style="font-family:var(--font-display);font-weight:700">QuoteAssist</span>
      </a>
      <div class="absolute right-6 top-6">
        <Layouts.theme_toggle />
      </div>

      <div class="mtb-auth-card mtb-card p-8">
        <.setup_state :if={@state == :setup} form={@form} />
        <.done_state :if={@state == :done} login_url={@login_url} />
        <.invalid_state :if={@state == :invalid} resend_form={@resend_form} />
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  attr :form, :any, required: true

  defp setup_state(assigns) do
    ~H"""
    <div
      class="mb-5 grid h-12 w-12 place-items-center rounded-2xl"
      style="background:var(--mc-brand-soft);color:var(--mc-brand)"
    >
      <.icon name="hero-lock-closed" class="size-6" />
    </div>
    <h1
      class="text-2xl font-bold tracking-tight"
      style="font-family:var(--font-display);color:var(--mc-text)"
    >
      Set your password
    </h1>
    <p class="mt-1.5 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      Choose a password to finish setting up your account. This also confirms your email —
      then you can sign in any time.
    </p>

    <.form
      for={@form}
      id="onboarding-setup-form"
      phx-change="validate"
      phx-submit="save"
      class="mt-6 space-y-4"
    >
      <.input
        field={@form[:password]}
        type="password"
        label="Password"
        autocomplete="new-password"
        placeholder="At least 12 characters"
        class="mtb-input mtb-input-lg"
        required
      />
      <.input
        field={@form[:password_confirmation]}
        type="password"
        label="Confirm password"
        autocomplete="new-password"
        placeholder="Re-enter your password"
        class="mtb-input mtb-input-lg"
        required
      />
      <.button class="mtb-btn mtb-btn-lg mtb-btn-primary w-full" phx-disable-with="Saving…">
        Finish setup <span aria-hidden="true">→</span>
      </.button>
    </.form>
    """
  end

  attr :login_url, :string, required: true

  defp done_state(assigns) do
    ~H"""
    <div
      class="mb-5 grid h-12 w-12 place-items-center rounded-2xl"
      style="background:color-mix(in oklch, var(--mc-success) 14%, transparent);color:var(--mc-success)"
    >
      <.icon name="hero-check-circle" class="size-6" />
    </div>
    <h1
      class="text-2xl font-bold tracking-tight"
      style="font-family:var(--font-display);color:var(--mc-text)"
    >
      You're all set
    </h1>
    <p class="mt-1.5 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      Your email is confirmed and your workspace is ready. Sign in to start drafting quotes.
    </p>
    <a href={@login_url} class="mtb-btn mtb-btn-lg mtb-btn-primary mt-6 w-full no-underline">
      Continue to sign in <span aria-hidden="true">→</span>
    </a>
    """
  end

  attr :resend_form, :any, required: true

  defp invalid_state(assigns) do
    ~H"""
    <div
      class="mb-5 grid h-12 w-12 place-items-center rounded-2xl"
      style="background:color-mix(in oklch, var(--mc-warning) 16%, transparent);color:var(--mc-warning)"
    >
      <.icon name="hero-shield-exclamation" class="size-6" />
    </div>
    <h1
      class="text-2xl font-bold tracking-tight"
      style="font-family:var(--font-display);color:var(--mc-text)"
    >
      This link has expired
    </h1>
    <p class="mt-1.5 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      Setup links expire after a while, or can only be used once. Enter your email and we'll
      send a fresh one.
    </p>

    <.form for={@resend_form} id="resend-form" phx-submit="resend" class="mt-6 space-y-4">
      <.input
        field={@resend_form[:email]}
        type="email"
        label="Work email"
        autocomplete="username"
        spellcheck="false"
        placeholder="rana@skylinetravel.com"
        class="mtb-input mtb-input-lg"
        required
      />
      <.button class="mtb-btn mtb-btn-lg mtb-btn-primary w-full" phx-disable-with="Sending…">
        Send a new link <span aria-hidden="true">→</span>
      </.button>
    </.form>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_owner_onboarding(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.complete_onboarding(socket.assigns.user, params) do
      {:ok, user} ->
        {:noreply, assign(socket, state: :done, login_url: login_url(user))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("resend", %{"resend" => %{"email" => email}}, socket) do
    # Neutral, non-enumerating response — Tenants.resend_onboarding/1 only sends when
    # the email is a not-yet-onboarded owner, but always returns :ok.
    Tenants.resend_onboarding(String.trim(email))

    {:noreply,
     put_flash(
       socket,
       :info,
       "If that email has a workspace awaiting setup, a fresh link is on its way."
     )}
  end

  # Where to send the owner to sign in: their newest owner tenant's own-host login.
  # Falls back to the platform home if (somehow) no owner tenant is found.
  defp login_url(user) do
    case Tenants.newest_owner_tenant(user) do
      nil -> "/"
      tenant -> Tenants.tenant_login_url(tenant)
    end
  end

  defp onboarded?(user) do
    not is_nil(user.hashed_password) and not is_nil(user.confirmed_at)
  end
end
