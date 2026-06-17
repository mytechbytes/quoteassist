defmodule QuoteAssistWeb.AdminAuth do
  @moduledoc """
  Site-admin authentication — a fully separate pipeline from `UserAuth`. It reads the
  `admin_token` session key (never `user_token`), loads `current_admin` (never
  `current_scope`), and operates only on the platform host. An admin can therefore be
  signed in alongside a tenant user with no collision: different identities, different
  session keys, and host-scoped cookies (admin = platform host, users = tenant host).

  Admins log in with a password only — no magic link, no remember-me, no
  self-registration. Sessions are DB-backed (`admins_tokens`) so logout revokes them.
  """
  use QuoteAssistWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias QuoteAssist.Accounts

  @doc """
  Logs the admin in: stamps `last_sign_in_at`, issues a DB session token, renews the
  session id (anti-fixation), and redirects to the admin dashboard.
  """
  def log_in_admin(conn, admin) do
    {:ok, _admin} = Accounts.update_admin_last_sign_in(admin)
    token = Accounts.generate_admin_session_token(admin)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> redirect(to: ~p"/admin")
  end

  @doc """
  Logs the admin out: revokes the DB session token, disconnects any live sockets,
  clears the session, and redirects to the admin login.
  """
  def log_out_admin(conn) do
    admin_token = get_session(conn, :admin_token)
    admin_token && Accounts.delete_admin_session_token(admin_token)

    if live_socket_id = get_session(conn, :admin_live_socket_id) do
      QuoteAssistWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/admin/login")
  end

  @doc "Plug: assigns `:current_admin` from the `admin_token` session (nil if absent/invalid)."
  def fetch_current_admin(conn, _opts) do
    assign(conn, :current_admin, admin_from_session(get_session(conn, :admin_token)))
  end

  @doc "Plug: requires an authenticated admin; otherwise flashes and redirects to `/admin/login`."
  def require_authenticated_admin(conn, _opts) do
    if conn.assigns[:current_admin] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in as an administrator to access this page.")
      |> redirect(to: ~p"/admin/login")
      |> halt()
    end
  end

  @doc """
  `on_mount` callbacks for admin LiveViews:

    * `:mount_current_admin` — assigns `current_admin` (or nil); used by the login view.
    * `:require_admin` — assigns `current_admin` and halts to `/admin/login` when
      absent. Guards every authenticated admin LiveView on both the dead render and
      the connected mount.
  """
  def on_mount(:mount_current_admin, _params, session, socket) do
    {:cont, mount_current_admin(socket, session)}
  end

  def on_mount(:require_admin, _params, session, socket) do
    socket = mount_current_admin(socket, session)

    if socket.assigns.current_admin do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "You must log in as an administrator to access this page."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/admin/login")

      {:halt, socket}
    end
  end

  defp mount_current_admin(socket, session) do
    Phoenix.Component.assign_new(socket, :current_admin, fn ->
      admin_from_session(session["admin_token"])
    end)
  end

  defp admin_from_session(token) when is_binary(token) do
    Accounts.get_admin_by_session_token(token)
  end

  defp admin_from_session(_token), do: nil

  # Clears the whole session and rotates the id to prevent fixation. Safe on the
  # platform host: tenant-user sessions live on tenant hosts (separate cookies).
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:admin_token, token)
    |> put_session(:admin_live_socket_id, "admins_sessions:#{Base.url_encode64(token)}")
  end
end
