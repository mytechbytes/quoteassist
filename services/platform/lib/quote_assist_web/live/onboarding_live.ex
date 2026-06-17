defmodule QuoteAssistWeb.OnboardingLive do
  @moduledoc """
  Owner onboarding (`/app/welcome`). After accepting their invite (magic link), an
  owner lands here to set a display name and an initial password. Reuses
  `Accounts.onboard_user/2` and keeps the current session. Once a password is set the
  page redirects to the workspace, so it is a one-time setup step (the full profile +
  password-reset flows arrive in R6). Guarded by `on_mount :require_tenant_member`.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.hashed_password do
      # Already set up — onboarding is a one-time step, not a settings page (R6).
      {:ok, push_navigate(socket, to: ~p"/app")}
    else
      {:ok,
       assign(socket,
         page_title: "Welcome",
         form: to_form(Accounts.change_user_onboarding(user))
       )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative grid min-h-screen place-items-center p-6" style="background:var(--mc-bg)">
      <div class="absolute right-6 top-6">
        <Layouts.theme_toggle />
      </div>

      <div class="mtb-auth-card mtb-card p-8">
        <span class="mtb-badge mtb-badge-brand">{@current_scope.tenant.name}</span>
        <h1
          class="mt-3 text-2xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          Welcome to QuoteAssist
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          Set your name and a password to finish setting up your account. You can then
          sign in any time with your email and password.
        </p>

        <.form
          for={@form}
          id="onboarding-form"
          phx-change="validate"
          phx-submit="save"
          class="mt-6 space-y-4"
        >
          <.input
            field={@form[:display_name]}
            type="text"
            label="Your name"
            placeholder="Rana Aziz"
            required
          />
          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            autocomplete="new-password"
            placeholder="At least 12 characters"
            required
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm password"
            autocomplete="new-password"
            placeholder="Re-enter your password"
            required
          />
          <.button class="mtb-btn mtb-btn-lg mtb-btn-primary w-full" phx-disable-with="Saving…">
            Finish setup <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.current_scope.user
      |> Accounts.change_user_onboarding(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.onboard_user(socket.assigns.current_scope.user, params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "You're all set — welcome aboard.")
         |> push_navigate(to: ~p"/app")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
