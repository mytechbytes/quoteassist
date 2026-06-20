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

    @tag admin_permissions: ["admin_role:list"]
    test "the create page is gated by admin_role:create", %{conn: _conn} = ctx do
      %{conn: conn} = register_and_log_in_normal_admin(ctx)
      assert {:error, {kind, %{to: "/admin"}}} = live(conn, ~p"/admin/roles/new")
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

    test "creates a role from the matrix", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/roles/new")

      lv |> element("#perm-tenant-list") |> render_click()
      lv |> element("#perm-plan-read") |> render_click()

      lv
      |> form("#role-form", admin_role: %{name: "Billing ops", slug: "billing-ops"})
      |> render_submit()

      role = Accounts.get_admin_role_by_slug("billing-ops")
      assert Enum.sort(role.permissions) == ["plan:read", "tenant:list"]
    end

    test "select-all for a column grants it across every resource", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/roles/new")

      lv |> element("#col-read") |> render_click()
      lv |> form("#role-form", admin_role: %{name: "Readers", slug: "readers"}) |> render_submit()

      perms = Accounts.get_admin_role_by_slug("readers").permissions
      assert "tenant:read" in perms
      assert "plan:read" in perms
      assert "admin:read" in perms
      assert "admin_role:read" in perms
      assert "audit:read" in perms
    end

    test "grants admin-side special permissions (suspend/cancel/purge) via chips", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/roles/new")

      lv |> element("#perm-tenant-suspend") |> render_click()
      lv |> element("#perm-tenant-purge") |> render_click()

      lv
      |> form("#role-form", admin_role: %{name: "Enforcers", slug: "enforcers"})
      |> render_submit()

      assert Enum.sort(Accounts.get_admin_role_by_slug("enforcers").permissions) ==
               ["tenant:purge", "tenant:suspend"]
    end

    test "edits a role's permissions from the matrix", %{conn: conn} do
      role = admin_role_fixture(%{name: "Support", slug: "support", permissions: ["tenant:list"]})
      {:ok, lv, html} = live(conn, ~p"/admin/roles/#{role.id}/edit")

      assert html =~ role.slug
      lv |> element("#perm-tenant-read") |> render_click()
      lv |> form("#role-form", admin_role: %{name: "Support"}) |> render_submit()

      assert Enum.sort(Accounts.get_admin_role(role.id).permissions) == [
               "tenant:list",
               "tenant:read"
             ]
    end

    test "redirects when editing a missing role", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/roles"}}} =
               live(conn, ~p"/admin/roles/#{Ecto.UUID.generate()}/edit")
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
