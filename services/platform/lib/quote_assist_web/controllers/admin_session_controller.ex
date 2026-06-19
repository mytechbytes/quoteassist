defmodule QuoteAssistWeb.AdminSessionController do
  use QuoteAssistWeb, :controller

  alias QuoteAssist.Accounts
  alias QuoteAssist.Audit
  alias QuoteAssistWeb.AdminAuth

  # Password sign in for site admins. Throttled by the LoginThrottle plug in the
  # router (per-IP + per-email). A successful login is audited; a failure returns the
  # generic error (no admin enumeration).
  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    case Accounts.get_admin_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> put_flash(:email, String.slice(email, 0, 160))
        |> redirect(to: ~p"/admin/login")

      admin ->
        conn
        |> log_admin_login(admin)
        |> put_flash(:info, "Welcome back.")
        |> AdminAuth.log_in_admin(admin)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AdminAuth.log_out_admin()
  end

  # Append-only audit row for a successful admin login (platform action — tenant_id
  # nil; email masked). Never fails the login on an audit write.
  defp log_admin_login(conn, admin) do
    Audit.log(%{
      actor_type: :admin,
      actor_subtype: admin.type,
      actor_id: admin.id,
      tenant_id: nil,
      action: "admin.login",
      target_type: "admin",
      target_id: admin.id,
      metadata: %{"email" => mask_email(admin.email)}
    })

    conn
  end

  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, domain] -> "#{String.first(local)}***@#{domain}"
      _ -> "***"
    end
  end
end
