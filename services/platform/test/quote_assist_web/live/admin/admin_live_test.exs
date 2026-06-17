defmodule QuoteAssistWeb.Admin.AdminLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "index redirects to /admin/login when not signed in", %{conn: conn} do
    assert {:error, {kind, %{to: "/admin/login"}}} = live(conn, ~p"/admin/admins")
    assert kind in [:redirect, :live_redirect]
  end

  describe "signed in" do
    setup :register_and_log_in_admin

    test "lists administrators and notes CLI-only creation", %{conn: conn, admin: admin} do
      {:ok, _lv, html} = live(conn, ~p"/admin/admins")
      assert html =~ admin.email
      assert html =~ "mix qa.create_admin"
    end

    test "shows an administrator's detail + activity", %{conn: conn, admin: admin} do
      {:ok, _lv, html} = live(conn, ~p"/admin/admins/#{admin.id}")
      assert html =~ admin.email
      assert html =~ "Activity"
    end

    test "redirects for an unknown administrator", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/admins"}}} =
               live(conn, ~p"/admin/admins/#{Ecto.UUID.generate()}")

      assert kind in [:redirect, :live_redirect]
    end
  end
end
