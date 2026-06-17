defmodule QuoteAssistWeb.UserLive.LoginTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts.UserToken
  alias QuoteAssist.Repo
  alias QuoteAssistWeb.UserLive.Login

  # Login is tenant-scoped: every test runs on a tenant host with a member user.
  setup %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    {member, _membership} = member_fixture(tenant, "owner")
    %{conn: put_tenant_host(conn, tenant), tenant: tenant, member: member}
  end

  describe "login page" do
    test "renders login page on a tenant host", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Sign in"
      assert html =~ "Email me a login link"
      # Registration lands in R4 — the page links out with a plain href for now.
      assert html =~ ~s(href="/register")
    end

    test "is not available on the platform host (redirects to the directory)", %{conn: conn} do
      conn = %{conn | host: "www.example.com"}
      assert {:error, {:redirect, %{to: "/tenants"}}} = live(conn, ~p"/login")
    end
  end

  describe "user login - magic link" do
    test "sends a magic link when a member of this tenant requests it", %{
      conn: conn,
      member: member
    } do
      {:ok, lv, _html} = live(conn, ~p"/login")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: member.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/login")

      assert html =~ "If your email is in our system"
      assert Repo.get_by!(UserToken, user_id: member.id).context == "login"
    end

    test "stays silent and sends nothing for a member of another tenant", %{conn: conn} do
      other = active_tenant_fixture(%{slug: "globex"})
      {stranger, _} = member_fixture(other, "owner")

      {:ok, lv, _html} = live(conn, ~p"/login")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: stranger.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/login")

      assert html =~ "If your email is in our system"
      refute Repo.get_by(UserToken, user_id: stranger.id, context: "login")
    end

    test "does not disclose if the email is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/login")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/login")

      assert html =~ "If your email is in our system"
    end
  end

  describe "user login - password" do
    test "redirects to /app when a member logs in with valid credentials", %{
      conn: conn,
      member: member
    } do
      member = set_password(member)
      {:ok, lv, _html} = live(conn, ~p"/login")

      form =
        form(lv, "#login_form_password",
          user: %{email: member.email, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)
      assert redirected_to(conn) == ~p"/app"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/login")

      form =
        form(lv, "#login_form_password", user: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/login"
    end
  end

  describe "login navigation" do
    test "links to registration (which lands in R4)", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")
      assert html =~ ~s(href="/register")
    end
  end

  describe "re-authentication (sudo mode)" do
    test "shows login page with email filled in", %{conn: conn, tenant: tenant, member: member} do
      conn = log_in_member(conn, member, tenant)
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "reauthenticate"
      assert html =~ "Email me a login link"
      assert html =~ "login_form_magic_email"
      assert html =~ member.email
    end
  end

  describe "magic_link_url/2" do
    test "builds the link on the request host (tenant subdomain / custom domain)" do
      assert Login.magic_link_url("http://acme.example.com:4000/login", "tok-123") ==
               "http://acme.example.com:4000/login/tok-123"
    end

    test "preserves a custom-domain host" do
      assert Login.magic_link_url("https://quotes.acme.test/login", "abc") ==
               "https://quotes.acme.test/login/abc"
    end

    test "falls back to the endpoint host when there is no request uri" do
      assert Login.magic_link_url(nil, "tok-123") =~ "/login/tok-123"
    end
  end
end
