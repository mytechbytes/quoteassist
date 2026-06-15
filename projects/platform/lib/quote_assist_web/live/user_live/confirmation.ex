defmodule QuoteAssistWeb.UserLive.Confirmation do
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

      <h1 class="font-display font-bold text-3xl tracking-[-0.02em]">Welcome</h1>
      <p class="mt-2 text-sm" style="color:var(--mc-text-2);">
        Signing in as <span class="font-semibold" style="color:var(--mc-text);">{@user.email}</span>
      </p>

      <.form
        :if={!@user.confirmed_at}
        for={@form}
        id="confirmation_form"
        phx-mounted={JS.focus_first()}
        phx-submit="submit"
        action={~p"/users/log-in?_action=confirmed"}
        phx-trigger-action={@trigger_submit}
        class="space-y-3 mt-7"
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <button
          name={@form[:remember_me].name}
          value="true"
          phx-disable-with="Confirming..."
          class="mc-btn mc-btn-lg mc-btn-primary w-full"
        >
          Confirm and stay logged in
        </button>
        <button phx-disable-with="Confirming..." class="mc-btn mc-btn-secondary w-full justify-center">
          Confirm and log in only this time
        </button>
      </.form>

      <.form
        :if={@user.confirmed_at}
        for={@form}
        id="login_form"
        phx-submit="submit"
        phx-mounted={JS.focus_first()}
        action={~p"/users/log-in"}
        phx-trigger-action={@trigger_submit}
        class="space-y-3 mt-7"
      >
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <%= if @current_scope do %>
          <button phx-disable-with="Logging in..." class="mc-btn mc-btn-lg mc-btn-primary w-full">
            Log in
          </button>
        <% else %>
          <button
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Logging in..."
            class="mc-btn mc-btn-lg mc-btn-primary w-full"
          >
            Keep me logged in on this device
          </button>
          <button
            phx-disable-with="Logging in..."
            class="mc-btn mc-btn-secondary w-full justify-center"
          >
            Log me in only this time
          </button>
        <% end %>
      </.form>

      <div
        :if={!@user.confirmed_at}
        class="mt-7 p-3 rounded-lg flex items-start gap-3 text-xs"
        style="background:var(--mc-surface-2);border:1px solid var(--mc-border);"
      >
        <span class="hero-information-circle size-4 mt-0.5 shrink-0" style="color:var(--mc-text-3);"></span>
        <div style="color:var(--mc-text-2);line-height:1.5;">
          Tip: prefer passwords? You can set one any time from your account settings.
        </div>
      </div>
    </Layouts.auth>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
