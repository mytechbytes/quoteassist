defmodule QuoteAssistWeb.UserLive.Confirmation do
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative grid min-h-screen place-items-center p-6" style="background:var(--mc-bg)">
      <a
        href="/"
        class="absolute left-6 top-6 flex items-center gap-2 no-underline"
        style="color:var(--mc-text)"
      >
        <span class="mtb-logo" style="width:28px;height:28px;font-size:12px">QA</span>
        <span style="font-family:var(--font-display);font-weight:700">QuoteAssist</span>
      </a>
      <div class="absolute right-6 top-6">
        <Layouts.theme_toggle />
      </div>

      <div class="mtb-auth-card">
        <div class="mtb-card p-8 text-center">
          <div
            class="mx-auto mb-5 grid h-12 w-12 place-items-center rounded-2xl"
            style="background:var(--mc-brand-soft);color:var(--mc-brand)"
          >
            <.icon name="hero-envelope" class="size-6" />
          </div>

          <h1
            class="text-2xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            {if @user.confirmed_at, do: "Welcome back", else: "Confirm your email"}
          </h1>
          <p class="mx-auto mt-2 max-w-xs text-sm" style="color:var(--mc-text-2)">
            <%= if @user.confirmed_at do %>
              Finish signing in as <b style="color:var(--mc-text)">{@user.email}</b>.
            <% else %>
              Activate <b style="color:var(--mc-text)">{@user.email}</b> and head to your workspace.
            <% end %>
          </p>

          <.form
            :if={!@user.confirmed_at}
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/login?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
            class="mt-7 space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Confirming…"
              class="mtb-btn mtb-btn-lg mtb-btn-primary w-full"
            >
              Confirm and stay logged in
            </.button>
            <.button
              phx-disable-with="Confirming…"
              class="mtb-btn mtb-btn-lg mtb-btn-secondary w-full"
            >
              Confirm and log in only this time
            </.button>
          </.form>

          <.form
            :if={@user.confirmed_at}
            for={@form}
            id="login_form"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/login"}
            phx-trigger-action={@trigger_submit}
            class="mt-7 space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <%= if @current_scope do %>
              <.button
                phx-disable-with="Logging in…"
                class="mtb-btn mtb-btn-lg mtb-btn-primary w-full"
              >
                Log in
              </.button>
            <% else %>
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Logging in…"
                class="mtb-btn mtb-btn-lg mtb-btn-primary w-full"
              >
                Keep me logged in on this device
              </.button>
              <.button
                phx-disable-with="Logging in…"
                class="mtb-btn mtb-btn-lg mtb-btn-secondary w-full"
              >
                Log me in only this time
              </.button>
            <% end %>
          </.form>
        </div>
      </div>
    </div>

    <Layouts.flash_group flash={@flash} />
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
       |> push_navigate(to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
