defmodule QuoteAssistWeb.ResetPasswordLive do
  @moduledoc """
  Set a new password from a reset link (`/reset/:token`, platform host only — gated by
  `RequirePlatform`). Reached from the email sent by `ForgotPasswordLive` (R9-recovery).
  The token is short-lived and single-use; completing the reset revokes every active
  session (all tokens are deleted), so the user signs in fresh.

  After a reset there's no tenant in scope (this is the platform host), so we send the
  user to their newest tenant's own-host login, falling back to the public directory.

  Three states:

    * `:reset`   — valid token → new-password form.
    * `:done`    — password updated → link to sign in.
    * `:invalid` — expired / unknown / used token → link back to /forgot.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts
  alias QuoteAssist.Tenants

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        {:ok, assign(socket, page_title: "Reset link", state: :invalid)}

      user ->
        {:ok,
         socket
         |> assign(page_title: "Set a new password", state: :reset, user: user)
         |> assign(:form, to_form(Accounts.change_user_password(user), as: "user"))}
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
        <.reset_state :if={@state == :reset} form={@form} user={@user} />
        <.done_state :if={@state == :done} login_url={@login_url} />
        <.invalid_state :if={@state == :invalid} />
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  attr :form, :any, required: true
  attr :user, :any, required: true

  defp reset_state(assigns) do
    ~H"""
    <div
      class="mb-5 grid h-12 w-12 place-items-center rounded-2xl"
      style="background:var(--mc-brand-soft);color:var(--mc-brand)"
    >
      <.icon name="hero-shield-check" class="size-6" />
    </div>
    <h1
      class="text-2xl font-bold tracking-tight"
      style="font-family:var(--font-display);color:var(--mc-text)"
    >
      Set a new password
    </h1>
    <p class="mt-1.5 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      For <b style="color:var(--mc-text)">{@user.email}</b>. Choose something you haven't used before.
    </p>

    <.form
      for={@form}
      id="reset-form"
      phx-change="validate"
      phx-submit="save"
      class="mt-6 space-y-4"
    >
      <.input
        field={@form[:password]}
        type="password"
        label="New password"
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
      <.button class="mtb-btn mtb-btn-lg mtb-btn-primary w-full" phx-disable-with="Updating…">
        Update password <span aria-hidden="true">→</span>
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
      Password updated
    </h1>
    <p class="mt-1.5 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      You're all set. Sign in with your new password to get back to quoting.
    </p>
    <a href={@login_url} class="mtb-btn mtb-btn-lg mtb-btn-primary mt-6 w-full no-underline">
      Continue to sign in <span aria-hidden="true">→</span>
    </a>
    """
  end

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
      Reset links expire after 60 minutes, or can only be used once. Request a fresh one to
      try again.
    </p>
    <a href="/forgot" class="mtb-btn mtb-btn-lg mtb-btn-primary mt-6 w-full no-underline">
      Request a new link <span aria-hidden="true">→</span>
    </a>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_password(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
  end

  def handle_event("save", %{"user" => params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, params) do
      {:ok, user} ->
        {:noreply, assign(socket, state: :done, login_url: login_url(user))}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end

  # Where to sign in after a reset: the user's newest tenant's own-host login. Falls back
  # to the public directory if they (somehow) have no live membership.
  defp login_url(user) do
    case Tenants.newest_tenant_for_user(user) do
      nil -> ~p"/tenants"
      tenant -> Tenants.tenant_login_url(tenant)
    end
  end
end
