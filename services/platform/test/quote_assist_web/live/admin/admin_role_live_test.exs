defmodule QuoteAssistWeb.Admin.AdminRoleLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts

  describe "access control" do
    test "redirects to /admin/login when not signed in", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/login"}}} = live(conn, ~p"/admin/roles")
      assert kind in [:redirect, :live_redirect]
    end

    @tag admin_permissions: []
    test "a normal admin without admin_role:list is bounced to /admin", %{conn: _conn} = ctx do
      %{conn: conn} = register_and_log_in_normal_admin(ctx)
      assert {:error, {kind, %{to: "/admin"}}} = live(conn, ~p"/admin/roles")
      assert kind in [:redirect, :live_redirect]
    end
  end

  describe "as a super_admin" do
    setup :register_and_log_in_admin

    test "lists roles and shows the New role action", %{conn: conn} do
      role = admin_role_fixture(%{name: "Operations", slug: "operations"})
      {:ok, lv, html} = live(conn, ~p"/admin/roles")
      assert html =~ "Operations"
      assert has_element?(lv, "#new-role")
      assert has_element?(lv, "#role-#{role.id}")
    end

    test "creates a role via the modal", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/roles")
      lv |> element("#new-role") |> render_click()

      html =
        lv
        |> form("#role-form")
        |> render_submit(
          admin_role: %{name: "Billing ops", slug: "billing-ops", permissions: ["tenant:list"]}
        )

      assert html =~ "Billing ops"
      role = Accounts.get_admin_role_by_slug("billing-ops")
      assert role.permissions == ["tenant:list"]
    end

    test "edits a role's permissions", %{conn: conn} do
      role = admin_role_fixture(%{name: "Support", slug: "support", permissions: ["tenant:list"]})
      {:ok, lv, _html} = live(conn, ~p"/admin/roles")

      lv |> element("#role-#{role.id} button", "Edit") |> render_click()

      lv
      |> form("#role-form")
      |> render_submit(admin_role: %{permissions: ["tenant:list", "tenant:read"]})

      assert Enum.sort(Accounts.get_admin_role(role.id).permissions) == [
               "tenant:list",
               "tenant:read"
             ]
    end

    test "soft-deletes a custom role via the confirm modal", %{conn: conn} do
      role = admin_role_fixture(%{name: "Temp", slug: "temp"})
      {:ok, lv, _html} = live(conn, ~p"/admin/roles")

      lv |> element("#role-#{role.id} button", "Remove") |> render_click()
      lv |> element("button", "Remove role") |> render_click()

      refute has_element?(lv, "#role-#{role.id}")
      assert Accounts.get_admin_role(role.id) == nil
    end

    test "built-in roles cannot be removed", %{conn: conn} do
      [builtin | _] = Accounts.seed_default_admin_roles()
      {:ok, lv, _html} = live(conn, ~p"/admin/roles")
      refute has_element?(lv, "#role-#{builtin.id} button", "Remove")
    end

    test "shows a role's detail with its permissions", %{conn: conn} do
      role =
        admin_role_fixture(%{name: "Support", slug: "support", permissions: ["tenant:list"]})

      {:ok, _lv, html} = live(conn, ~p"/admin/roles/#{role.id}")
      assert html =~ "Support"
      assert html =~ "View agency list"
    end

    test "redirects for an unknown role", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/roles"}}} =
               live(conn, ~p"/admin/roles/#{Ecto.UUID.generate()}")

      assert kind in [:redirect, :live_redirect]
    end
  end

  describe "as a read-only normal admin" do
    @tag admin_permissions: ["admin_role:list"]
    setup :register_and_log_in_normal_admin

    test "can list but cannot create", %{conn: conn} do
      admin_role_fixture(%{name: "Operations", slug: "operations"})
      {:ok, lv, html} = live(conn, ~p"/admin/roles")
      assert html =~ "Operations"
      refute has_element?(lv, "#new-role")
    end
  end
end
