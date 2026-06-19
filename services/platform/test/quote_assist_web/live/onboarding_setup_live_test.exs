defmodule QuoteAssistWeb.OnboardingSetupLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts

  # A trial tenant, an unconfirmed owner, a live owner membership, and a fresh
  # onboarding token — the state right after self-registration. The default conn host
  # (www.example.com) is the platform host, where these routes live.
  setup do
    tenant = tenant_fixture(%{slug: "skyline", name: "Skyline Travel"})
    user = unconfirmed_user_fixture(%{email: "rana@skyline.test"})
    membership_fixture(tenant, user, "owner")
    token = extract_user_token(fn url -> Accounts.deliver_onboarding_instructions(user, url) end)

    %{tenant: tenant, user: user, token: token}
  end

  describe "a valid token" do
    test "renders the set-password form", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/onboarding/#{token}")
      assert html =~ "Set your password"
    end

    test "sets the password, confirms the email, and offers the sign-in link", %{
      conn: conn,
      token: token,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/onboarding/#{token}")

      html =
        lv
        |> form("#onboarding-setup-form",
          user: %{
            password: "a valid password 1",
            password_confirmation: "a valid password 1"
          }
        )
        |> render_submit()

      assert html =~ "You're all set"
      # The sign-in link points at the tenant's own subdomain login.
      assert html =~ "http://skyline.example.com/login"

      updated = Accounts.get_user!(user.id)
      assert updated.confirmed_at
      assert Accounts.get_user_by_email_and_password(user.email, "a valid password 1")
    end

    test "shows the done state directly for an already-onboarded owner", %{
      conn: conn,
      user: user
    } do
      {:ok, _user} =
        Accounts.complete_onboarding(user, %{
          password: "a valid password 1",
          password_confirmation: "a valid password 1"
        })

      # complete_onboarding consumed the setup-time token; issue a fresh one.
      fresh =
        extract_user_token(fn url -> Accounts.deliver_onboarding_instructions(user, url) end)

      {:ok, _lv, html} = live(conn, ~p"/onboarding/#{fresh}")
      assert html =~ "You're all set"
    end
  end

  describe "an invalid or expired token" do
    test "renders the resend form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/onboarding/not-a-real-token")
      assert html =~ "This link has expired"
      assert html =~ "Send a new link"
    end

    test "resending gives a neutral confirmation", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding/not-a-real-token")

      html =
        lv
        |> form("#resend-form", resend: %{email: user.email})
        |> render_submit()

      assert html =~ "a fresh link is on its way"
    end
  end

  test "404s on a tenant host", %{conn: conn, token: token} do
    active_tenant_fixture(%{slug: "acme"})
    conn = %{conn | host: "acme.example.com"} |> get(~p"/onboarding/#{token}")
    assert conn.status == 404
  end
end
