defmodule QuoteAssistWeb.App.RoleLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Tenants

  defp log_in_role(conn, tenant, permissions) do
    role = role_fixture(tenant, %{permissions: permissions})
    user = user_fixture()
    {:ok, _membership} = Tenants.create_membership(tenant, user, role)
    log_in_member(conn, user, tenant)
  end

  describe "access" do
    test "a member without role:list gets the branded 403", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = log_in_role(conn, tenant, ["quote:list"])
      assert_error_sent 403, fn -> get(conn, ~p"/app/roles") end
    end

    test "a viewer with role:list (but not role:create) sees no New button", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = log_in_role(conn, tenant, ["role:list"])
      {:ok, lv, html} = live(conn, ~p"/app/roles")
      assert html =~ "Manager"
      refute has_element?(lv, "#new-role")
    end

    test "the create page is gated by role:create", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = log_in_role(conn, tenant, ["role:list", "role:read"])
      assert_error_sent 403, fn -> get(conn, ~p"/app/roles/new") end
    end
  end

  describe "index, as an owner" do
    setup :register_and_log_in_member

    test "lists the seeded roles and links to the form pages", %{conn: conn, tenant: tenant} do
      role = role_fixture(tenant, %{name: "Temp", slug: "temp", permissions: []})
      {:ok, lv, html} = live(conn, ~p"/app/roles")
      assert html =~ "Manager"
      assert has_element?(lv, "#new-role")
      assert has_element?(lv, ~s{#role-#{role.id} a[href="/app/roles/#{role.id}/edit"]})
    end

    test "removes a custom role but not a built-in", %{conn: conn, tenant: tenant} do
      role = role_fixture(tenant, %{name: "Temp", slug: "temp", permissions: []})
      {:ok, lv, _html} = live(conn, ~p"/app/roles")

      builtin = Tenants.get_role_by_slug(tenant, "manager")
      refute has_element?(lv, "#role-#{builtin.id} button", "Remove")

      lv |> element("#role-#{role.id} button", "Remove") |> render_click()
      lv |> element("button", "Remove role") |> render_click()
      assert Tenants.get_role(tenant, role.id) == nil
    end

    test "refuses to remove a role still assigned to a member", %{conn: conn, tenant: tenant} do
      role = role_fixture(tenant, %{name: "Busy", slug: "busy", permissions: ["quote:list"]})
      {owner_user, owner} = member_fixture(tenant, "owner")
      {_u, member} = member_fixture(tenant, "agent")
      scope = scope_fixture(tenant, owner_user, owner)
      {:ok, _} = Tenants.update_member_role(scope, member, %{"role_id" => role.id})

      {:ok, lv, _html} = live(conn, ~p"/app/roles")
      lv |> element("#role-#{role.id} button", "Remove") |> render_click()
      html = lv |> element("button", "Remove role") |> render_click()

      assert html =~ "still assigned to a member"
      assert Tenants.get_role(tenant, role.id)
    end
  end

  describe "the permission matrix form" do
    setup :register_and_log_in_member

    test "creates a role from individual cells", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      lv |> element("#perm-quote-list") |> render_click()
      lv |> element("#perm-quote-read") |> render_click()
      lv |> form("#role-form", role: %{name: "Viewer", slug: "viewer"}) |> render_submit()

      role = Tenants.get_role_by_slug(tenant, "viewer")
      assert Enum.sort(role.permissions) == ["quote:list", "quote:read"]
    end

    test "select-all for an action column grants it across every resource", %{
      conn: conn,
      tenant: tenant
    } do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      lv |> element("#col-create") |> render_click()
      lv |> form("#role-form", role: %{name: "Creators", slug: "creators"}) |> render_submit()

      perms = Tenants.get_role_by_slug(tenant, "creators").permissions
      assert "quote:create" in perms
      assert "user:create" in perms
      assert "role:create" in perms
      assert "request:create" in perms
      # singletons (settings/domain/billing) have no :create, so none leaked in
      refute Enum.any?(perms, &(&1 in ["settings:create", "domain:create", "billing:create"]))
    end

    test "select-all for a resource row grants its whole row", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      lv |> element("#resource-settings") |> render_click()
      lv |> form("#role-form", role: %{name: "Settings", slug: "settingsrole"}) |> render_submit()

      assert Enum.sort(Tenants.get_role_by_slug(tenant, "settingsrole").permissions) ==
               ["settings:read", "settings:update"]
    end

    test "grants a special (non-CRUD) permission via its chip", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      lv |> element("#perm-quote-status") |> render_click()
      lv |> element("#perm-quote-ai_generate") |> render_click()
      lv |> form("#role-form", role: %{name: "Desk", slug: "desk"}) |> render_submit()

      assert Enum.sort(Tenants.get_role_by_slug(tenant, "desk").permissions) ==
               ["quote:ai_generate", "quote:status"]
    end

    test "select-all for the Special column grants every extra", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      lv |> element("#col-special") |> render_click()
      lv |> form("#role-form", role: %{name: "Specials", slug: "specials"}) |> render_submit()

      perms = Tenants.get_role_by_slug(tenant, "specials").permissions
      assert Enum.sort(perms) == Enum.sort(QuoteAssist.Authz.Permissions.special_keys())
      # no CRUD permission leaked in
      refute Enum.any?(perms, &String.ends_with?(&1, ":create"))
    end

    test "select-all grants the entire catalog", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      lv |> element("#select-all") |> render_click()
      lv |> form("#role-form", role: %{name: "Everything", slug: "everything"}) |> render_submit()

      assert Enum.sort(Tenants.get_role_by_slug(tenant, "everything").permissions) ==
               Enum.sort(QuoteAssist.Authz.Permissions.keys())
    end

    test "edits an existing role, preselecting its permissions", %{conn: conn, tenant: tenant} do
      role = role_fixture(tenant, %{name: "Temp", slug: "temp", permissions: ["quote:list"]})
      {:ok, lv, html} = live(conn, ~p"/app/roles/#{role.id}/edit")

      # the existing permission is pre-ticked, slug is shown read-only
      assert html =~ "checked"
      assert html =~ role.slug

      lv |> element("#perm-quote-create") |> render_click()
      lv |> form("#role-form", role: %{name: "Temp"}) |> render_submit()

      assert Enum.sort(Tenants.get_role(tenant, role.id).permissions) ==
               ["quote:create", "quote:list"]
    end

    test "toggling a fully-selected column clears it", %{conn: conn, tenant: tenant} do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      lv |> element("#col-create") |> render_click()
      lv |> element("#col-create") |> render_click()
      lv |> form("#role-form", role: %{name: "Empty", slug: "emptyrole"}) |> render_submit()

      assert Tenants.get_role_by_slug(tenant, "emptyrole").permissions == []
    end

    test "reports a duplicate slug on save", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/roles/new")

      html =
        lv |> form("#role-form", role: %{name: "Dupe", slug: "manager"}) |> render_submit()

      assert html =~ "has already been taken"
    end

    test "redirects when editing a missing role", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/app/roles"}}} =
               live(conn, ~p"/app/roles/#{Ecto.UUID.generate()}/edit")
    end
  end
end
