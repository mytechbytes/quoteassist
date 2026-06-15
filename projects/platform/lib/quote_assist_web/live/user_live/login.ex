defmodule QuoteAssistWeb.UserLive.Login do
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash}>
      <a href={~p"/"} class="flex items-center gap-2 mb-10 lg:hidden no-underline text-inherit">
        <span class="mc-logo" style="width:28px;height:28px;font-size:12px;">QA</span>
        <span class="font-display font-bold">QuoteAssist</span>
      </a>

      <h1 class="font-display font-bold text-3xl tracking-[-0.02em]">Sign in</h1>
      <p class="mt-2 text-sm" style="color:var(--mc-text-2);">
        <%= if @current_scope do %>
          You need to reauthenticate to perform sensitive actions on your account.
        <% else %>
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold" style="color:var(--mc-brand);">
            Sign up
          </.link>
        <% end %>
      </p>

      <div
        :if={local_mail_adapter?()}
        class="mt-5 p-3 rounded-lg flex items-start gap-3 text-xs"
        style="background:var(--mc-surface-2);border:1px solid var(--mc-border);"
      >
        <span class="hero-information-circle size-4 mt-0.5 shrink-0" style="color:var(--mc-text-3);"></span>
        <div style="color:var(--mc-text-2);line-height:1.5;">
          Local mail adapter — sent emails appear in <.link
            href="/dev/mailbox"
            class="font-semibold"
            style="color:var(--mc-brand);"
          >the mailbox</.link>.
        </div>
      </div>

      <%!-- SSO (seams for a later OAuth slice) --%>
      <div class="grid grid-cols-2 gap-2 mt-7">
        <button
          type="button"
          phx-click="sso"
          phx-value-provider="google"
          class="mc-btn mc-btn-secondary justify-center"
        >
          <svg width="16" height="16" viewBox="0 0 24 24"><path
            fill="#4285F4"
            d="M22.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h5.9c-.3 1.4-1 2.6-2.2 3.4v2.8h3.6c2.1-1.9 3.2-4.7 3.2-8.4z"
          /><path
            fill="#34A853"
            d="M12 23c2.9 0 5.4-1 7.2-2.6l-3.6-2.8c-1 .7-2.3 1.1-3.6 1.1-2.8 0-5.2-1.9-6-4.4H2.3v2.8C4.1 20.7 7.8 23 12 23z"
          /><path
            fill="#FBBC04"
            d="M6 14.3c-.2-.7-.3-1.4-.3-2.3s.1-1.6.3-2.3V6.9H2.3C1.5 8.5 1 10.2 1 12s.5 3.5 1.3 5.1L6 14.3z"
          /><path
            fill="#EA4335"
            d="M12 5.4c1.6 0 3 .5 4 1.6l3.1-3.1C17.5 2.3 14.9 1 12 1 7.8 1 4.1 3.3 2.3 6.9L6 9.7c.8-2.5 3.2-4.3 6-4.3z"
          /></svg>
          Google
        </button>
        <button
          type="button"
          phx-click="sso"
          phx-value-provider="microsoft"
          class="mc-btn mc-btn-secondary justify-center"
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="#0078D4"><path d="M11.5 11.5H3V3h8.5v8.5zM21 11.5h-8.5V3H21v8.5zM11.5 21H3v-8.5h8.5V21zM21 21h-8.5v-8.5H21V21z" /></svg>
          Microsoft
        </button>
      </div>

      <div class="flex items-center gap-3 my-6">
        <div class="flex-1 mc-hairline"></div>
        <span class="text-xs font-medium" style="color:var(--mc-text-3);">or with email</span>
        <div class="flex-1 mc-hairline"></div>
      </div>

      <%!-- Password sign-in (primary) --%>
      <.form
        :let={f}
        for={@form}
        id="login_form_password"
        action={~p"/users/log-in"}
        phx-submit="submit_password"
        phx-trigger-action={@trigger_submit}
        class="space-y-4"
      >
        <div>
          <label class="mc-label">Work email</label>
          <input
            type="email"
            name={f[:email].name}
            id={f[:email].id}
            value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
            readonly={!!@current_scope}
            placeholder="rana@skylinetravel.com"
            autocomplete="username"
            spellcheck="false"
            required
            class="mc-input mc-input-lg"
          />
        </div>

        <div>
          <div class="flex items-center justify-between mb-1.5">
            <label class="mc-label" style="margin:0;">Password</label>
            <button
              type="button"
              phx-click={JS.focus(to: "#login_form_magic_email")}
              class="text-xs font-semibold bg-transparent border-0 cursor-pointer p-0"
              style="color:var(--mc-brand);"
            >
              Forgot?
            </button>
          </div>
          <div class="relative">
            <input
              type="password"
              name={f[:password].name}
              id="login_password"
              placeholder="••••••••"
              autocomplete="current-password"
              spellcheck="false"
              required
              class="mc-input mc-input-lg pr-11"
            />
            <button
              type="button"
              aria-label="Show password"
              phx-click={
                JS.toggle_attribute({"type", "text", "password"}, to: "#login_password")
                |> JS.toggle_class("hidden", to: "#login-eye")
                |> JS.toggle_class("hidden", to: "#login-eye-off")
              }
              class="absolute right-2 top-1/2 -translate-y-1/2 mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost"
            >
              <span id="login-eye" class="hero-eye size-4"></span>
              <span id="login-eye-off" class="hero-eye-slash size-4 hidden"></span>
            </button>
          </div>
        </div>

        <label class="flex items-center gap-2 text-sm" style="color:var(--mc-text-2);">
          <input
            type="checkbox"
            name={f[:remember_me].name}
            value="true"
            class="rounded"
            style="accent-color:var(--mc-brand);"
          /> Keep me signed in for 30 days
        </label>

        <button type="submit" class="mc-btn mc-btn-lg mc-btn-primary w-full">
          Sign in <.icon name="hero-arrow-right" class="size-4" />
        </button>
      </.form>

      <%!-- Magic link (passwordless / recovery) --%>
      <div class="flex items-center gap-3 my-6">
        <div class="flex-1 mc-hairline"></div>
        <span class="text-xs font-medium" style="color:var(--mc-text-3);">prefer a magic link?</span>
        <div class="flex-1 mc-hairline"></div>
      </div>

      <.form
        :let={f}
        for={@form}
        id="login_form_magic"
        action={~p"/users/log-in"}
        phx-submit="submit_magic"
        class="space-y-3"
      >
        <div>
          <input
            type="email"
            name={f[:email].name}
            id={f[:email].id}
            value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
            readonly={!!@current_scope}
            placeholder="rana@skylinetravel.com"
            autocomplete="username"
            spellcheck="false"
            required
            class="mc-input mc-input-lg"
          />
        </div>
        <button type="submit" class="mc-btn mc-btn-secondary w-full justify-center">
          Log in with email <span aria-hidden="true">→</span>
        </button>
      </.form>

      <p class="mt-10 text-center text-xs" style="color:var(--mc-text-3);">
        By signing in you agree to our
        <a href="#" class="underline" style="color:var(--mc-text-2);">Terms</a>
        and <a href="#" class="underline" style="color:var(--mc-text-2);">Privacy Policy</a>.
      </p>
    </Layouts.auth>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  def handle_event("sso", %{"provider" => provider}, socket) do
    {:noreply,
     put_flash(socket, :info, "#{String.capitalize(provider)} single sign-on is coming soon.")}
  end

  defp local_mail_adapter? do
    Application.get_env(:quote_assist, QuoteAssist.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
