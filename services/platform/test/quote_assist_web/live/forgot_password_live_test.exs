defmodule QuoteAssistWeb.ForgotPasswordLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts.UserToken
  alias QuoteAssist.Repo

  test "renders the forgot form on the platform host", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/forgot")
    assert html =~ "Forgot your password?"
    assert html =~ "Work email"
  end

  test "sends a reset link for a known email and shows the neutral panel", %{conn: conn} do
    user = user_fixture()
    {:ok, lv, _html} = live(conn, ~p"/forgot")

    html = lv |> form("#forgot-form", forgot: %{email: user.email}) |> render_submit()

    assert html =~ "Check your inbox"
    assert Repo.get_by(UserToken, user_id: user.id, context: "reset_password")
  end

  test "shows the same panel for an unknown email and issues no token", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/forgot")

    html =
      lv |> form("#forgot-form", forgot: %{email: "nobody@example.com"}) |> render_submit()

    assert html =~ "Check your inbox"
    refute Repo.get_by(UserToken, context: "reset_password")
  end

  test "404s on a tenant host (recovery lives on the platform host)", %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    conn = %{conn | host: "#{tenant.slug}.example.com"} |> get(~p"/forgot")
    assert conn.status == 404
  end
end
