defmodule QuoteAssistWeb.AppHomeLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures

  describe "/app" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/app")
      assert path == ~p"/login"
    end

    test "renders the workspace for an authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "Signed in"
      assert html =~ user.email
      assert html =~ ~p"/logout"
    end
  end
end
