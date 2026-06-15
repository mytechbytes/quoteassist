defmodule QuoteAssistWeb.UserLive.Registration do
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth flash={@flash}>
      <a href={~p"/"} class="flex items-center gap-2 mb-10 lg:hidden no-underline text-inherit">
        <span class="mc-logo" style="width:28px;height:28px;font-size:12px;">QA</span>
        <span class="font-display font-bold">QuoteAssist</span>
      </a>

      <h1 class="font-display font-bold text-3xl tracking-[-0.02em]">Register</h1>
      <p class="mt-2 text-sm" style="color:var(--mc-text-2);">
        Already have an account?
        <.link navigate={~p"/users/log-in"} class="font-semibold" style="color:var(--mc-brand);">
          Log in
        </.link>
      </p>

      <.form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        class="space-y-4 mt-7"
      >
        <div>
          <label class="mc-label">Work email</label>
          <input
            type="email"
            name={@form[:email].name}
            id={@form[:email].id}
            value={Phoenix.HTML.Form.normalize_value("email", @form[:email].value)}
            placeholder="rana@skylinetravel.com"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
            class="mc-input mc-input-lg"
          />
          <p
            :for={msg <- field_errors(@form[:email])}
            class="mt-1.5 text-xs"
            style="color:var(--mc-danger, #dc2626);"
          >
            {msg}
          </p>
        </div>

        <div>
          <label class="mc-label">Password</label>
          <div class="relative">
            <input
              type="password"
              name={@form[:password].name}
              id="register_password"
              placeholder="At least 12 characters"
              autocomplete="new-password"
              spellcheck="false"
              required
              minlength="12"
              class="mc-input mc-input-lg pr-11"
            />
            <button
              type="button"
              aria-label="Show password"
              phx-click={
                JS.toggle_attribute({"type", "text", "password"}, to: "#register_password")
                |> JS.toggle_class("hidden", to: "#register-eye")
                |> JS.toggle_class("hidden", to: "#register-eye-off")
              }
              class="absolute right-2 top-1/2 -translate-y-1/2 mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost"
            >
              <span id="register-eye" class="hero-eye size-4"></span>
              <span id="register-eye-off" class="hero-eye-slash size-4 hidden"></span>
            </button>
          </div>
          <p
            :for={msg <- field_errors(@form[:password])}
            class="mt-1.5 text-xs"
            style="color:var(--mc-danger, #dc2626);"
          >
            {msg}
          </p>
        </div>

        <button
          type="submit"
          phx-disable-with="Creating account..."
          class="mc-btn mc-btn-lg mc-btn-primary w-full"
        >
          Create account <.icon name="hero-arrow-right" class="size-4" />
        </button>
      </.form>

      <div
        class="mt-7 p-3 rounded-lg flex items-start gap-3 text-xs"
        style="background:var(--mc-surface-2);border:1px solid var(--mc-border);"
      >
        <span class="hero-shield-check size-4 mt-0.5 shrink-0" style="color:var(--mc-text-3);"></span>
        <div style="color:var(--mc-text-2);line-height:1.5;">
          We'll email a link to confirm your account. You can also sign in with a magic link any time.
        </div>
      </div>
    </Layouts.auth>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: QuoteAssistWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  defp field_errors(field) do
    if Phoenix.Component.used_input?(field) do
      Enum.map(field.errors, &translate_error/1)
    else
      []
    end
  end
end
