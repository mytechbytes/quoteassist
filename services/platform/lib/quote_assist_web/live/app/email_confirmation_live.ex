defmodule QuoteAssistWeb.App.EmailConfirmationLive do
  @moduledoc """
  Confirms an email change from the link sent to the **new** address
  (`/account/confirm-email/:token`, tenant host). This is the second half of the
  `self:email` flow whose initiation lives in `App.AccountLive` (R7-rbac): the actual
  swap only happens here, once the new address is proven (R9-recovery).

  Guarded by `on_mount :require_tenant_member`, so the signed-in user is in scope — the
  token's context is `change:<old-email>`, so the swap is verified against *their* current
  email. If the user clicks the link logged out, `require_authenticated_user` bounces them
  through login first and back here.

  Two states:

    * `:ok`      — the email was changed → we redirect to the account page.
    * `:invalid` — expired / unknown / used token → link back to the account page.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
      {:ok, _user} ->
        {:ok,
         socket
         |> assign(page_title: "Email confirmed", state: :ok)
         |> put_flash(:info, "Your email has been changed.")
         |> redirect(to: ~p"/app/account")}

      {:error, _reason} ->
        {:ok, assign(socket, page_title: "Confirmation link", state: :invalid)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative grid min-h-screen place-items-center p-6" style="background:var(--mc-bg)">
      <a
        href={~p"/app"}
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
        <.invalid_state :if={@state == :invalid} />
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
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
      Email-change links expire after a while, or can only be used once. Start the change
      again from your account settings.
    </p>
    <.link
      navigate={~p"/app/account"}
      class="mtb-btn mtb-btn-lg mtb-btn-primary mt-6 w-full no-underline"
    >
      Back to your account <span aria-hidden="true">→</span>
    </.link>
    """
  end
end
