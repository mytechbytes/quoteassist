defmodule QuoteAssistWeb.RegistrationLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.UserToken
  alias QuoteAssist.Tenants

  setup do
    # Self-registration defaults new tenants to the seeded Starter plan.
    %{plan: plan_fixture(%{slug: "starter", name: "Starter"})}
  end

  test "renders the registration form on the platform host", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/register")
    assert html =~ "Create your account"
    assert html =~ "Company name"
    assert html =~ "Workspace address"
  end

  test "self-registers a tenant and shows the check-your-inbox panel", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/register")

    html =
      lv
      |> form("#registration-form",
        tenant: %{
          name: "Skyline Travel",
          slug: "skyline",
          owner_name: "Rana Aziz",
          owner_email: "rana@skyline.test"
        }
      )
      |> render_submit()

    assert html =~ "Check your inbox"
    assert html =~ "rana@skyline.test"

    tenant = Tenants.get_tenant_by_slug("skyline")
    assert tenant.status == :trial
    assert tenant.source == :self_signup

    owner = Accounts.get_user_by_email("rana@skyline.test")
    assert owner.display_name == "Rana Aziz"
    assert QuoteAssist.Repo.get_by(UserToken, user_id: owner.id, context: "onboarding")
  end

  test "shows a validation error for a reserved slug", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/register")

    html =
      lv
      |> form("#registration-form",
        tenant: %{name: "X", slug: "admin", owner_name: "Y", owner_email: "y@x.test"}
      )
      |> render_submit()

    assert html =~ "is reserved"
    assert Tenants.get_tenant_by_slug("admin") == nil
  end

  test "404s on a tenant host (onboarding lives on the platform host)", %{conn: conn} do
    import QuoteAssist.TenantsFixtures
    active_tenant_fixture(%{slug: "acme"})

    conn = %{conn | host: "acme.example.com"} |> get(~p"/register")
    assert conn.status == 404
  end
end
