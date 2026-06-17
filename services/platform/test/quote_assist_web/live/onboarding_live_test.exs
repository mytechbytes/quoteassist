defmodule QuoteAssistWeb.OnboardingLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts

  describe "owner without a password" do
    setup :register_and_log_in_member

    test "renders the onboarding form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/welcome")
      assert html =~ "Welcome to QuoteAssist"
    end

    test "sets display name + password then redirects to /app", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/app/welcome")

      result =
        lv
        |> form("#onboarding-form",
          user: %{
            display_name: "Rana",
            password: "a valid password 1",
            password_confirmation: "a valid password 1"
          }
        )
        |> render_submit()

      assert {:error, {kind, %{to: "/app"}}} = result
      assert kind in [:redirect, :live_redirect]

      updated = Accounts.get_user!(user.id)
      assert updated.display_name == "Rana"
      assert Accounts.get_user_by_email_and_password(user.email, "a valid password 1")
    end
  end

  describe "owner with a password already" do
    test "redirects straight to /app", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      {user, _membership} = member_fixture(tenant, "owner")
      # Set the password first, THEN log in (set_password expires existing tokens).
      user = set_password(user)
      conn = log_in_member(conn, user, tenant)

      assert {:error, {kind, %{to: "/app"}}} = live(conn, ~p"/app/welcome")
      assert kind in [:redirect, :live_redirect]
    end
  end
end
