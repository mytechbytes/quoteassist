defmodule QuoteAssistWeb.ForgotPasswordLive do
  @moduledoc """
  Forgot password (`/forgot`, platform host only — gated by `RequirePlatform`). A
  logged-out user enters their email and we send a reset link (R9-recovery). The flow
  lives on the platform host so it works even when the user's tenant is suspended; the
  emailed link points at the platform-host `/reset/:token`.

  The response is always neutral ("check your inbox"), whether or not the email matched,
  so this can't be used to enumerate accounts. The send is throttled per email.

  Two states:

    * `:request` — the email form.
    * `:sent`    — neutral confirmation.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts
  alias QuoteAssistWeb.Plugs.LoginThrottle

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Forgot password", state: :request, request_uri: nil)
     |> assign(:form, to_form(%{"email" => ""}, as: "forgot"))}
  end

  @impl true
  # Capture the request URL so the reset link is built on the same (platform) host the
  # user is on — robust across dev / staging / prod without hardcoding a host.
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :request_uri, uri)}
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
        <.request_state :if={@state == :request} form={@form} />
        <.sent_state :if={@state == :sent} />
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  attr :form, :any, required: true

  defp request_state(assigns) do
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
      Forgot your password?
    </h1>
    <p class="mt-1.5 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      Enter the email on your account and we'll send a link to reset it.
    </p>

    <.form for={@form} id="forgot-form" phx-submit="send" class="mt-6 space-y-4">
      <.input
        field={@form[:email]}
        type="email"
        label="Work email"
        autocomplete="username"
        spellcheck="false"
        placeholder="rana@skylinetravel.com"
        class="mtb-input mtb-input-lg"
        required
      />
      <.button class="mtb-btn mtb-btn-lg mtb-btn-primary w-full" phx-disable-with="Sending…">
        Send reset link <span aria-hidden="true">→</span>
      </.button>
    </.form>
    """
  end

  defp sent_state(assigns) do
    ~H"""
    <div
      class="mb-5 grid h-12 w-12 place-items-center rounded-2xl"
      style="background:color-mix(in oklch, var(--mc-success) 14%, transparent);color:var(--mc-success)"
    >
      <.icon name="hero-envelope" class="size-6" />
    </div>
    <h1
      class="text-2xl font-bold tracking-tight"
      style="font-family:var(--font-display);color:var(--mc-text)"
    >
      Check your inbox
    </h1>
    <p class="mt-1.5 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      If an account exists for that email, a reset link is on its way. The link expires in
      60 minutes.
    </p>
    <a href="/" class="mtb-btn mtb-btn-lg mtb-btn-secondary mt-6 w-full no-underline">
      Back to home
    </a>
    """
  end

  @impl true
  def handle_event("send", %{"forgot" => %{"email" => email}}, socket) do
    email = String.trim(email)

    # Neutral, non-enumerating: we always show :sent. Only actually send when the email
    # matches a user and the per-email throttle isn't tripped.
    if email != "" and not LoginThrottle.reset_password_throttled?(email) do
      if user = Accounts.get_user_by_email(email) do
        Accounts.deliver_user_reset_password_instructions(user, &reset_url(socket, &1))
      end
    end

    {:noreply, assign(socket, :state, :sent)}
  end

  # Builds the reset URL for `token` on the host of the current request (the platform
  # host, since /forgot is RequirePlatform-gated). Falls back to the endpoint host.
  defp reset_url(%{assigns: %{request_uri: uri}}, token) when is_binary(uri) do
    %URI{URI.parse(uri) | path: ~p"/reset/#{token}", query: nil, fragment: nil}
    |> URI.to_string()
  end

  defp reset_url(_socket, token), do: url(~p"/reset/#{token}")
end
