defmodule QuoteAssistWeb.App.AccountLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.UserToken
  alias QuoteAssist.Repo

  # A member of `acme` with a real password (so password/email flows can authorise).
  setup %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    user = set_password(user_fixture())
    {:ok, membership} = QuoteAssist.Tenants.create_membership(tenant, user, role_for(tenant))
    %{conn: log_in_member(conn, user, tenant), user: user, tenant: tenant, membership: membership}
  end

  defp role_for(tenant), do: QuoteAssist.Tenants.get_role_by_slug(tenant, "agent")

  test "a member with an empty-ish role still reaches their account", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/app/account")
    assert html =~ "Your account"
    assert html =~ "Active sessions"
  end

  test "saves the profile", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/app/account")

    lv
    |> form("#profile-form", profile: %{display_name: "Rana Aziz", timezone: "Europe/London"})
    |> render_submit()

    assert Accounts.get_user!(user.id).display_name == "Rana Aziz"
  end

  test "changing the password revokes sessions and bounces to login", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/account")

    result =
      lv
      |> form("#password-form",
        password: %{
          current_password: valid_user_password(),
          password: "a new long password",
          password_confirmation: "a new long password"
        }
      )
      |> render_submit()

    assert {:error, {:redirect, %{to: "/login"}}} = result
  end

  test "a wrong current password is rejected", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/account")

    html =
      lv
      |> form("#password-form",
        password: %{
          current_password: "nope nope nope",
          password: "a new long password",
          password_confirmation: "a new long password"
        }
      )
      |> render_submit()

    assert html =~ "is not correct"
  end

  test "initiates a verified email change", %{conn: conn, user: user} do
    {:ok, lv, _html} = live(conn, ~p"/app/account")

    html =
      lv
      |> form("#email-form",
        email_change: %{email: "fresh@example.com", current_password: valid_user_password()}
      )
      |> render_submit()

    assert html =~ "Check fresh@example.com"
    # The verification token is issued for (sent to) the NEW address.
    assert Repo.get_by(UserToken, sent_to: "fresh@example.com", context: "change:#{user.email}")
  end

  test "email change requires the current password", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/app/account")

    html =
      lv
      |> form("#email-form", email_change: %{email: "fresh@example.com", current_password: ""})
      |> render_submit()

    assert html =~ "Enter your current password"
  end

  test "revokes another session but not the current one", %{conn: conn, user: user} do
    other = Accounts.generate_user_session_token(user)
    other_id = Accounts.session_token_id(other)
    {:ok, lv, _html} = live(conn, ~p"/app/account")

    assert has_element?(lv, "#session-#{other_id} button", "Revoke")
    lv |> element("#session-#{other_id} button", "Revoke") |> render_click()

    refute has_element?(lv, "#session-#{other_id}")
    assert Accounts.get_user_by_session_token(other) == nil
  end
end
