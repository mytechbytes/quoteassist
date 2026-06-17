defmodule QuoteAssistWeb.UserSessionController do
  use QuoteAssistWeb, :controller

  alias QuoteAssist.Accounts
  alias QuoteAssist.Audit
  alias QuoteAssistWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> log_login(user, "magic_link")
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/login")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> log_login(user, "password")
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/login")
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
