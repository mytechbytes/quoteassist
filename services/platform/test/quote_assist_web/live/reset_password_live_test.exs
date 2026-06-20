defmodule QuoteAssistWeb.ResetPasswordLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts

  defp reset_token(user) do
    extract_user_token(fn url_fun ->
      Accounts.deliver_user_reset_password_instructions(user, url_fun)
    end)
  end

  test "renders the new-password form for a valid token", %{conn: conn} do
    user = user_fixture()
    {:ok, _lv, html} = live(conn, ~p"/reset/#{reset_token(user)}")

    assert html =~ "Set a new password"
    assert html =~ user.email
  end

  test "shows the expired state for an unknown token", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/reset/not-a-real-token")
    assert html =~ "This link has expired"
  end

  test "resets the password and consumes the token", %{conn: conn} do
    user = user_fixture()
    token = reset_token(user)
    {:ok, lv, _html} = live(conn, ~p"/reset/#{token}")

    html =
      lv
      |> form("#reset-form",
        user: %{password: "a brand new password", password_confirmation: "a brand new password"}
      )
      |> render_submit()

    assert html =~ "Password updated"
    assert Accounts.get_user_by_email_and_password(user.email, "a brand new password")
    # Single-use: the token no longer resolves.
    refute Accounts.get_user_by_reset_password_token(token)
  end

  test "after reset, links to the user's newest tenant login", %{conn: conn} do
    %{tenant: tenant, user: user} = owner_scope_fixture(%{slug: "acme"})
    {:ok, lv, _html} = live(conn, ~p"/reset/#{reset_token(user)}")

    html =
      lv
      |> form("#reset-form",
        user: %{password: "a brand new password", password_confirmation: "a brand new password"}
      )
      |> render_submit()

    assert html =~ "Password updated"
    assert html =~ QuoteAssist.Tenants.tenant_login_url(tenant)
  end

  test "rejects a mismatched confirmation", %{conn: conn} do
    user = user_fixture()
    {:ok, lv, _html} = live(conn, ~p"/reset/#{reset_token(user)}")

    html =
      lv
      |> form("#reset-form",
        user: %{password: "a brand new password", password_confirmation: "different one here"}
      )
      |> render_submit()

    assert html =~ "does not match password"
  end

  test "404s on a tenant host", %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    conn = %{conn | host: "#{tenant.slug}.example.com"} |> get(~p"/reset/whatever")
    assert conn.status == 404
  end
end
