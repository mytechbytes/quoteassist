defmodule QuoteAssistWeb.AdminAuthTest do
  use QuoteAssistWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias QuoteAssist.Accounts
  alias QuoteAssistWeb.AdminAuth

  import QuoteAssist.AccountsFixtures

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, QuoteAssistWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{admin: admin_fixture(), conn: conn}
  end

  describe "log_in_admin/2" do
    test "stores the admin token, sets live_socket_id, stamps last_sign_in_at", %{
      conn: conn,
      admin: admin
    } do
      conn = AdminAuth.log_in_admin(conn, admin)
      assert token = get_session(conn, :admin_token)

      assert get_session(conn, :admin_live_socket_id) ==
               "admins_sessions:#{Base.url_encode64(token)}"

      assert redirected_to(conn) == ~p"/admin"
      assert Accounts.get_admin_by_session_token(token)
      assert Accounts.get_admin!(admin.id).last_sign_in_at
    end

    test "clears prior session data (fixation)", %{conn: conn, admin: admin} do
      conn = conn |> put_session(:to_be_removed, "value") |> AdminAuth.log_in_admin(admin)
      refute get_session(conn, :to_be_removed)
    end
  end

  describe "log_out_admin/1" do
    test "erases the admin session and revokes the token", %{conn: conn, admin: admin} do
      token = Accounts.generate_admin_session_token(admin)
      conn = conn |> put_session(:admin_token, token) |> AdminAuth.log_out_admin()

      refute get_session(conn, :admin_token)
      assert redirected_to(conn) == ~p"/admin/login"
      refute Accounts.get_admin_by_session_token(token)
    end

    test "works even if not logged in", %{conn: conn} do
      conn = AdminAuth.log_out_admin(conn)
      refute get_session(conn, :admin_token)
      assert redirected_to(conn) == ~p"/admin/login"
    end
  end

  describe "fetch_current_admin/2" do
    test "assigns the admin from the session token", %{conn: conn, admin: admin} do
      token = Accounts.generate_admin_session_token(admin)
      conn = conn |> put_session(:admin_token, token) |> AdminAuth.fetch_current_admin([])
      assert conn.assigns.current_admin.id == admin.id
    end

    test "assigns nil without a token", %{conn: conn} do
      conn = AdminAuth.fetch_current_admin(conn, [])
      assert conn.assigns.current_admin == nil
    end

    test "does NOT derive an admin from a user_token (separate identity)", %{conn: conn} do
      user = user_fixture()
      user_token = Accounts.generate_user_session_token(user)
      conn = conn |> put_session(:user_token, user_token) |> AdminAuth.fetch_current_admin([])
      assert conn.assigns.current_admin == nil
    end
  end

  describe "require_authenticated_admin/2" do
    test "redirects to /admin/login when no admin", %{conn: conn} do
      conn = conn |> fetch_flash() |> AdminAuth.require_authenticated_admin([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/admin/login"
    end

    test "passes through with an admin", %{conn: conn, admin: admin} do
      conn = conn |> assign(:current_admin, admin) |> AdminAuth.require_authenticated_admin([])
      refute conn.halted
    end
  end

  describe "on_mount :require_admin" do
    test "cont with a valid admin token", %{conn: conn, admin: admin} do
      token = Accounts.generate_admin_session_token(admin)
      session = conn |> put_session(:admin_token, token) |> get_session()
      {:cont, socket} = AdminAuth.on_mount(:require_admin, %{}, session, %LiveView.Socket{})
      assert socket.assigns.current_admin.id == admin.id
    end

    test "halt without a token", %{conn: conn} do
      session = get_session(conn)

      socket = %LiveView.Socket{
        endpoint: QuoteAssistWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, socket} = AdminAuth.on_mount(:require_admin, %{}, session, socket)
      assert socket.assigns.current_admin == nil
    end
  end

  describe "on_mount :mount_current_admin" do
    test "assigns current_admin from a token", %{conn: conn, admin: admin} do
      token = Accounts.generate_admin_session_token(admin)
      session = conn |> put_session(:admin_token, token) |> get_session()
      {:cont, socket} = AdminAuth.on_mount(:mount_current_admin, %{}, session, %LiveView.Socket{})
      assert socket.assigns.current_admin.id == admin.id
    end

    test "assigns nil without a token", %{conn: conn} do
      session = get_session(conn)
      {:cont, socket} = AdminAuth.on_mount(:mount_current_admin, %{}, session, %LiveView.Socket{})
      assert socket.assigns.current_admin == nil
    end
  end
end
