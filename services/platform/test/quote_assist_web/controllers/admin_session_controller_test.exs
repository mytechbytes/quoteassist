defmodule QuoteAssistWeb.AdminSessionControllerTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Ecto.Query
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Audit.Log
  alias QuoteAssist.Repo

  setup do
    %{admin: admin_fixture()}
  end

  describe "POST /admin/login" do
    test "logs in a valid admin and writes an audit row", %{conn: conn, admin: admin} do
      conn =
        post(conn, ~p"/admin/login", %{
          "admin" => %{"email" => admin.email, "password" => valid_admin_password()}
        })

      assert get_session(conn, :admin_token)
      assert redirected_to(conn) == ~p"/admin"

      log = Repo.one!(from l in Log, where: l.action == "admin.login")
      assert log.actor_type == :admin
      assert log.actor_id == admin.id
      assert log.tenant_id == nil
      assert log.metadata["email"] =~ "***"
    end

    test "rejects bad credentials with a generic error", %{conn: conn, admin: admin} do
      conn =
        post(conn, ~p"/admin/login", %{
          "admin" => %{"email" => admin.email, "password" => "wrong-password"}
        })

      refute get_session(conn, :admin_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/admin/login"
    end

    test "is unreachable on a tenant host", %{conn: conn, admin: admin} do
      active_tenant_fixture(%{slug: "acme"})

      conn =
        %{conn | host: "acme.example.com"}
        |> post(~p"/admin/login", %{
          "admin" => %{"email" => admin.email, "password" => valid_admin_password()}
        })

      assert conn.status == 404
      refute get_session(conn, :admin_token)
    end
  end

  describe "DELETE /admin/logout" do
    test "logs the admin out", %{conn: conn, admin: admin} do
      conn = conn |> log_in_admin(admin) |> delete(~p"/admin/logout")
      assert redirected_to(conn) == ~p"/admin/login"
      refute get_session(conn, :admin_token)
    end
  end
end
