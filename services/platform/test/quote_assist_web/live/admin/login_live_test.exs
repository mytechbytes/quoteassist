defmodule QuoteAssistWeb.Admin.LoginLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures

  test "renders the admin sign in page", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/admin/login")
    assert html =~ "Administrator sign in"
  end

  test "redirects an already-authenticated admin to /admin", %{conn: conn} do
    conn = log_in_admin(conn, admin_fixture())
    assert {:error, {kind, %{to: "/admin"}}} = live(conn, ~p"/admin/login")
    assert kind in [:redirect, :live_redirect]
  end
end
