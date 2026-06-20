defmodule QuoteAssistWeb.App.AccountLive do
  @moduledoc """
  Self-service account (`/app/account`) — the `self:*` baseline surface (R7-rbac). Every
  authenticated member manages their **own** record regardless of role: profile
  (`self:read`/`self:update`), password (`self:password`), email (`self:email` — the
  verified-change request; the confirm/alert token mechanics land in R9-recovery), and
  their active sessions (`self:sessions`). No permission gate — a member with an empty
  role can still do all of this, because it's scoped to their own row.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Accounts

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user
    current_session_id = Accounts.session_token_id(session["user_token"])

    {:ok,
     socket
     |> assign(
       page_title: "Account",
       current_session_id: current_session_id,
       profile_form: to_form(Accounts.change_user_profile(user), as: :profile),
       password_form: to_form(Accounts.change_user_password(user), as: :password),
       email_form: to_form(Accounts.change_user_email(user), as: :email_change)
     )
     |> load_sessions()}
  end

  defp load_sessions(socket) do
    assign(socket, :sessions, Accounts.list_user_sessions(socket.assigns.current_scope.user))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="account"
      breadcrumb="Account"
    >
      <div class="mb-7">
        <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
          Account
        </div>
        <h1
          class="mt-1.5 text-3xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          Your account
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          Manage how you appear to teammates, your sign-in, and your active sessions.
        </p>
      </div>

      <div class="space-y-5">
        <section class="mtb-card p-6">
          <h2
            class="mb-4 text-base font-bold"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Profile
          </h2>
          <.form
            for={@profile_form}
            id="profile-form"
            phx-change="validate_profile"
            phx-submit="save_profile"
          >
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <.input field={@profile_form[:display_name]} type="text" label="Display name" />
              <.input
                field={@profile_form[:timezone]}
                type="text"
                label="Timezone"
                placeholder="Europe/London"
              />
              <div class="sm:col-span-2">
                <.input
                  field={@profile_form[:avatar_url]}
                  type="text"
                  label="Avatar URL"
                  placeholder="https://…"
                />
              </div>
            </div>
            <div class="mt-3">
              <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
                Save profile
              </.button>
            </div>
          </.form>
        </section>

        <section class="mtb-card p-6">
          <h2
            class="mb-4 text-base font-bold"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Password
          </h2>
          <.form for={@password_form} id="password-form" phx-submit="save_password">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <.input
                  field={@password_form[:current_password]}
                  type="password"
                  label="Current password"
                />
              </div>
              <.input field={@password_form[:password]} type="password" label="New password (min 12)" />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
              />
            </div>
            <div class="mt-3">
              <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Updating…">
                Change password
              </.button>
            </div>
          </.form>
        </section>

        <section class="mtb-card p-6">
          <h2
            class="mb-1 text-base font-bold"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Email
          </h2>
          <p class="mb-4 text-sm" style="color:var(--mc-text-2)">
            Current: <span class="font-mono">{@current_scope.user.email}</span>. We'll send a link to
            the new address to confirm the change.
          </p>
          <.form for={@email_form} id="email-form" phx-submit="save_email">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <.input field={@email_form[:email]} type="email" label="New email" />
              <.input
                field={@email_form[:current_password]}
                name="email_change[current_password]"
                type="password"
                label="Current password"
                value=""
              />
            </div>
            <div class="mt-3">
              <.button class="mtb-btn mtb-btn-secondary mtb-btn-sm" phx-disable-with="Sending…">
                Send confirmation
              </.button>
            </div>
          </.form>
        </section>

        <section class="mtb-card p-6">
          <h2
            class="mb-1 text-base font-bold"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Active sessions
          </h2>
          <p class="mb-4 text-sm" style="color:var(--mc-text-2)">
            Devices currently signed in to your account. Revoking one signs it out.
          </p>
          <ul class="divide-y" style="border-color:var(--mc-border)">
            <li
              :for={s <- @sessions}
              id={"session-#{s.id}"}
              class="flex items-center justify-between py-3"
            >
              <div>
                <div class="text-sm font-medium" style="color:var(--mc-text)">
                  {if s.id == @current_session_id, do: "This device", else: "Session"}
                </div>
                <div class="font-mono text-xs" style="color:var(--mc-text-3)">
                  Signed in {format_datetime(s.authenticated_at)}
                </div>
              </div>
              <button
                :if={s.id != @current_session_id}
                phx-click="revoke_session"
                phx-value-id={s.id}
                class="mtb-btn mtb-btn-ghost mtb-btn-sm"
              >
                Revoke
              </button>
              <span :if={s.id == @current_session_id} class="mtb-badge mtb-badge-success">Current</span>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.workspace>
    """
  end

  @impl true
  def handle_event("validate_profile", %{"profile" => params}, socket) do
    changeset =
      socket.assigns.current_scope.user
      |> Accounts.change_user_profile(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, profile_form: to_form(changeset, as: :profile))}
  end

  def handle_event("save_profile", %{"profile" => params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_scope.user, params) do
      {:ok, user} ->
        scope = %{socket.assigns.current_scope | user: user}

        {:noreply,
         socket
         |> assign(
           current_scope: scope,
           profile_form: to_form(Accounts.change_user_profile(user), as: :profile)
         )
         |> put_flash(:info, "Profile saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, profile_form: to_form(changeset, as: :profile))}
    end
  end

  def handle_event("save_password", %{"password" => params}, socket) do
    user = socket.assigns.current_scope.user

    if Accounts.valid_user_password?(user, params["current_password"]) do
      case Accounts.update_user_password(user, params) do
        {:ok, _} ->
          # All sessions (including this one) are revoked — re-authenticate.
          {:noreply,
           socket
           |> put_flash(:info, "Password updated. Please sign in again.")
           |> redirect(to: ~p"/login")}

        {:error, changeset} ->
          {:noreply, assign(socket, password_form: to_form(changeset, as: :password))}
      end
    else
      changeset =
        user
        |> Accounts.change_user_password(params)
        |> Ecto.Changeset.add_error(:current_password, "is not correct")
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, password_form: to_form(changeset, as: :password))}
    end
  end

  def handle_event("save_email", %{"email_change" => params}, socket) do
    user = socket.assigns.current_scope.user
    %{"email" => new_email} = params
    current_password = params["current_password"] || ""

    if Accounts.valid_user_password?(user, current_password) do
      deliver_email_change(socket, user, new_email)
    else
      {:noreply, put_flash(socket, :error, "Enter your current password to change your email.")}
    end
  end

  def handle_event("revoke_session", %{"id" => id}, socket) do
    if id == socket.assigns.current_session_id do
      {:noreply, put_flash(socket, :error, "Use Log out to end your current session.")}
    else
      case Accounts.revoke_user_session(socket.assigns.current_scope.user, id) do
        {:ok, _} ->
          {:noreply, socket |> put_flash(:info, "Session revoked.") |> load_sessions()}

        {:error, :not_found} ->
          {:noreply,
           socket |> put_flash(:error, "That session is already gone.") |> load_sessions()}
      end
    end
  end

  # Applies the new email to a throwaway changeset (validates format / uniqueness / that
  # it changed) and, on success, emails a confirmation link to the new address. The
  # actual swap + old-address alert land in R9-recovery; here we only initiate it.
  defp deliver_email_change(socket, user, new_email) do
    case Ecto.Changeset.apply_action(
           Accounts.change_user_email(user, %{email: new_email}),
           :update
         ) do
      {:ok, applied} ->
        Accounts.deliver_user_update_email_instructions(
          applied,
          user.email,
          &email_confirm_url(socket, &1)
        )

        {:noreply,
         put_flash(socket, :info, "Check #{new_email} for a link to confirm the change.")}

      {:error, changeset} ->
        {:noreply, assign(socket, email_form: to_form(changeset, as: :email_change))}
    end
  end

  # The confirmation link's target lands in R9-recovery; built as a plain tenant-host URL
  # string so this release doesn't depend on a route that doesn't exist yet.
  defp email_confirm_url(socket, token) do
    tenant = socket.assigns.current_scope.tenant
    scheme = Application.get_env(:quote_assist, :tenant_url_scheme, "https")
    base = Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.mytechbytes.in")
    "#{scheme}://#{tenant.slug}.#{base}/account/confirm-email/#{token}"
  end
end
