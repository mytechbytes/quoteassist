defmodule QuoteAssistWeb.UserLive.ConfirmationTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts

  # Magic-link confirmation is reached on the tenant host, by a member.
  setup %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    %{conn: put_tenant_host(conn, tenant), tenant: tenant}
  end

  describe "Confirm user" do
    setup %{tenant: tenant} do
      unconfirmed = unconfirmed_user_fixture()
      membership_fixture(tenant, unconfirmed, "agent")
      confirmed = user_fixture()
      membership_fixture(tenant, confirmed, "owner")
      %{unconfirmed_user: unconfirmed, confirmed_user: confirmed}
    end

    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      {:ok, _lv, html} = live(conn, ~p"/login/#{token}")
      assert html =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed user", %{conn: conn, confirmed_user: user} do
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      {:ok, _lv, html} = live(conn, ~p"/login/#{token}")
      refute html =~ "Confirm and stay logged in"
      assert html =~ "Keep me logged in on this device"
    end

    test "renders login page for already logged in user", %{
      conn: conn,
      tenant: tenant,
      confirmed_user: user
    } do
      conn = log_in_member(conn, user, tenant)
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      {:ok, _lv, html} = live(conn, ~p"/login/#{token}")
      refute html =~ "Confirm and stay logged in"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, tenant: tenant, unconfirmed_user: user} do
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      {:ok, lv, _html} = live(conn, ~p"/login/#{token}")

      form = form(lv, "#confirmation_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully"
      assert Accounts.get_user!(user.id).confirmed_at
      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/app"

      # New (logged-out) conn — the token is single-use.
      conn = put_tenant_host(build_conn(), tenant)

      {:ok, _lv, html} =
        live(conn, ~p"/login/#{token}") |> follow_redirect(conn, ~p"/login")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed user in without changing confirmed_at", %{
      conn: conn,
      tenant: tenant,
      confirmed_user: user
    } do
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      {:ok, lv, _html} = live(conn, ~p"/login/#{token}")

      form = form(lv, "#login_form", %{"user" => %{"token" => token}})
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
      assert Accounts.get_user!(user.id).confirmed_at == user.confirmed_at

      conn = put_tenant_host(build_conn(), tenant)

      {:ok, _lv, html} =
        live(conn, ~p"/login/#{token}") |> follow_redirect(conn, ~p"/login")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "redirects to login page for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/login/invalid-token") |> follow_redirect(conn, ~p"/login")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
