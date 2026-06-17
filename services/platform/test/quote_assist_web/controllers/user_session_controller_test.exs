defmodule QuoteAssistWeb.UserSessionControllerTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Ecto.Query
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.UserToken
  alias QuoteAssist.Audit.Log
  alias QuoteAssist.Repo

  # Login is tenant-scoped: requests run on a tenant host with a member user.
  setup %{conn: conn} do
    tenant = active_tenant_fixture(%{slug: "acme"})
    {member, _membership} = member_fixture(tenant, "owner")
    %{conn: put_tenant_host(conn, tenant), tenant: tenant, member: member}
  end

  describe "POST /login - email and password" do
    test "logs a member in", %{conn: conn, member: member} do
      member = set_password(member)

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => member.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/app"
    end

    test "writes an audit row scoped to the tenant (email masked)", %{
      conn: conn,
      tenant: tenant,
      member: member
    } do
      member = set_password(member)

      post(conn, ~p"/login", %{
        "user" => %{"email" => member.email, "password" => valid_user_password()}
      })

      log = Repo.one!(from l in Log, where: l.action == "user.login")
      assert log.actor_type == :user
      assert log.actor_id == member.id
      assert log.tenant_id == tenant.id
      assert log.metadata["method"] == "password"
      assert log.metadata["email"] =~ "***"
      refute log.metadata["email"] == member.email
    end

    test "rejects a user who is not a member of this tenant (no enumeration)", %{conn: conn} do
      other = active_tenant_fixture(%{slug: "globex"})
      {stranger, _} = member_fixture(other, "owner")
      stranger = set_password(stranger)

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => stranger.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/login"
    end

    test "logs a member in with remember me", %{conn: conn, member: member} do
      member = set_password(member)

      conn =
        post(conn, ~p"/login", %{
          "user" => %{
            "email" => member.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_quote_assist_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/app"
    end

    test "logs a member in with return to", %{conn: conn, member: member} do
      member = set_password(member)

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/login", %{
          "user" => %{"email" => member.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, member: member} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => member.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/login"
    end
  end

  describe "POST /login - magic link" do
    test "logs a member in", %{conn: conn, member: member} do
      {token, _hashed_token} = generate_user_magic_link_token(member)

      conn = post(conn, ~p"/login", %{"user" => %{"token" => token}})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/app"

      assert Repo.one!(from l in Log, where: l.action == "user.login").metadata["method"] ==
               "magic_link"
    end

    test "confirms an unconfirmed member", %{conn: conn, tenant: tenant} do
      user = unconfirmed_user_fixture()
      membership_fixture(tenant, user, "viewer")
      {token, _hashed_token} = generate_user_magic_link_token(user)
      refute user.confirmed_at

      conn = post(conn, ~p"/login", %{"user" => %{"token" => token}, "_action" => "confirmed"})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/app"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully."
      assert Accounts.get_user!(user.id).confirmed_at
    end

    test "rejects a magic link for a non-member without consuming the token", %{conn: conn} do
      other = active_tenant_fixture(%{slug: "globex"})
      {stranger, _} = member_fixture(other, "owner")
      {token, hashed_token} = generate_user_magic_link_token(stranger)

      conn = post(conn, ~p"/login", %{"user" => %{"token" => token}})

      refute get_session(conn, :user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/login"
      # Token not burned — the stranger can still use it on their own tenant.
      assert Repo.get_by(UserToken, token: hashed_token, context: "login")
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn = post(conn, ~p"/login", %{"user" => %{"token" => "invalid"}})

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/login"
    end
  end

  describe "platform host" do
    test "POST /login is redirected to the directory (no tenant login there)", %{
      conn: conn,
      member: member
    } do
      member = set_password(member)
      conn = %{conn | host: "www.example.com"}

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => member.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/tenants"
    end
  end

  describe "DELETE /logout" do
    test "logs the user out", %{conn: conn, member: member} do
      conn = conn |> log_in_user(member) |> delete(~p"/logout")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/logout")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end

  describe "POST /login - expired trial" do
    test "blocks an expired-trial member and auto-suspends the tenant (audited)", %{conn: conn} do
      tenant = expired_trial_tenant_fixture(%{slug: "expired"})
      {member, _membership} = member_fixture(tenant, "owner")
      member = set_password(member)

      conn =
        conn
        |> put_tenant_host(tenant)
        |> post(~p"/login", %{
          "user" => %{"email" => member.email, "password" => valid_user_password()}
        })

      refute get_session(conn, :user_token)
      assert Repo.reload(tenant).status == :suspended

      log =
        Repo.one!(
          from l in Log,
            where: l.action == "tenant.status_changed" and l.tenant_id == ^tenant.id
        )

      assert log.metadata == %{"from" => "trial", "to" => "suspended"}
      assert log.actor_type == :system
    end

    test "an active tenant member still logs in", %{conn: conn, member: member} do
      member = set_password(member)

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => member.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/app"
    end
  end
end
