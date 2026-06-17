defmodule QuoteAssistWeb.UserSessionController do
  use QuoteAssistWeb, :controller

  alias QuoteAssist.Accounts
  alias QuoteAssist.Audit
  alias QuoteAssist.Tenants
  alias QuoteAssistWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login — scoped to the resolved tenant. The membership is checked
  # before the token is consumed, so a link submitted on the wrong tenant's host is
  # rejected (with the generic error, no enumeration) without burning the token.
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    tenant = conn.assigns[:current_tenant]
    user = tenant && Accounts.get_user_by_magic_link_token(token)

    cond do
      is_nil(user) or not Tenants.member?(tenant, user) ->
        invalid_link(conn)

      Tenants.enforce_trial_expiry(tenant) == :expired ->
        deny_expired_trial(conn)

      true ->
        consume_magic_link(conn, token, user_params, info)
    end
  end

  # email + password login — scoped to the resolved tenant. A user can only sign in
  # to a tenant they have a live membership for.
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params
    tenant = conn.assigns[:current_tenant]
    user = Accounts.get_user_by_email_and_password(email, password)

    if user && tenant && Tenants.member?(tenant, user) do
      case Tenants.enforce_trial_expiry(tenant) do
        :ok ->
          conn
          |> log_login(user, "password")
          |> put_flash(:info, info)
          |> UserAuth.log_in_user(user, user_params)

        :expired ->
          deny_expired_trial(conn)
      end
    else
      # Generic error — never reveal whether the email exists or belongs to another
      # tenant (prevents cross-tenant user enumeration).
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/login")
    end
  end

  # Consumes a verified, in-tenant magic-link token and logs the user in. Split out of
  # create/3 to keep nesting shallow (membership + trial are checked by the caller).
  defp consume_magic_link(conn, token, user_params, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> log_login(user, "magic_link")
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        invalid_link(conn)
    end
  end

  # NOTE: password change (`update_password`) and the settings screen land in R6
  # (account flows). The generated action was removed here to keep R1 to sign
  # in / out only; re-introduce it with the settings UI in R6.

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp invalid_link(conn) do
    conn
    |> put_flash(:error, "The link is invalid or it has expired.")
    |> redirect(to: ~p"/login")
  end

  # Trial lapsed: Tenants.enforce_trial_expiry/1 has just auto-suspended the tenant
  # (audited). Deny the login; the redirect to /login then hits the now-suspended host
  # and renders the branded "workspace not registered" 404.
  defp deny_expired_trial(conn) do
    conn
    |> put_flash(:error, "This workspace's trial has ended. Contact your administrator.")
    |> redirect(to: ~p"/login")
  end

  # Writes an append-only audit row for a successful login. Tenant id comes from the
  # host-resolved tenant (nil on the platform host); the email is masked — never
  # store it in full. Login never fails on an audit write, so the result is ignored.
  defp log_login(conn, user, method) do
    Audit.log(%{
      actor_type: :user,
      actor_id: user.id,
      tenant_id: current_tenant_id(conn),
      action: "user.login",
      target_type: "user",
      target_id: user.id,
      metadata: %{"method" => method, "email" => mask_email(user.email)}
    })

    conn
  end

  defp current_tenant_id(conn) do
    case conn.assigns[:current_tenant] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, domain] -> "#{String.first(local)}***@#{domain}"
      _ -> "***"
    end
  end
end
