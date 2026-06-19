defmodule QuoteAssistWeb.Admin.AdminLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts

  describe "access control" do
    test "index redirects to /admin/login when not signed in", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/login"}}} = live(conn, ~p"/admin/admins")
      assert kind in [:redirect, :live_redirect]
    end

    @tag admin_permissions: []
    test "a normal admin without admin:list is bounced to /admin", %{conn: _conn} = ctx do
      %{conn: conn} = register_and_log_in_normal_admin(ctx)
      assert {:error, {kind, %{to: "/admin"}}} = live(conn, ~p"/admin/admins")
      assert kind in [:redirect, :live_redirect]
    end
  end

  describe "as a super_admin" do
    setup :register_and_log_in_admin

    test "lists administrators and notes CLI-only super_admin creation", %{
      conn: conn,
      admin: admin
    } do
      {:ok, lv, html} = live(conn, ~p"/admin/admins")
      assert html =~ admin.email
      assert html =~ "mix qa.create_admin"
      assert has_element?(lv, "#new-admin")
    end

    test "creates a scoped normal admin via the modal", %{conn: conn} do
      role = admin_role_fixture(%{permissions: ["tenant:list"]})
      {:ok, lv, _html} = live(conn, ~p"/admin/admins")

      lv |> element("#new-admin") |> render_click()

      html =
        lv
        |> form("#admin-form")
        |> render_submit(
          admin: %{
            email: "ops@quoteassist.test",
            password: valid_admin_password(),
            role_id: role.id
          }
        )

      assert html =~ "ops@quoteassist.test"
      created = Accounts.get_admin_by_email("ops@quoteassist.test")
      assert created.type == :admin
      assert created.role_id == role.id
    end

    test "reassigns a normal admin's role", %{conn: conn} do
      target = normal_admin_fixture(["tenant:list"])
      other = admin_role_fixture(%{name: "Other", slug: "other", permissions: ["plan:list"]})
      {:ok, lv, _html} = live(conn, ~p"/admin/admins")

      lv |> element("#admin-#{target.id} button", "Edit role") |> render_click()
      lv |> form("#admin-form") |> render_submit(admin: %{role_id: other.id})

      assert Accounts.get_admin(target.id).role_id == other.id
    end

    test "deactivates and reactivates a normal admin", %{conn: conn} do
      target = normal_admin_fixture(["tenant:list"])
      {:ok, lv, _html} = live(conn, ~p"/admin/admins")

      lv |> element("#admin-#{target.id} button", "Deactivate") |> render_click()
      refute Accounts.get_admin(target.id).active

      lv |> element("#admin-#{target.id} button", "Reactivate") |> render_click()
      assert Accounts.get_admin(target.id).active
    end

    test "removes a normal admin via the confirm modal", %{conn: conn} do
      target = normal_admin_fixture(["tenant:list"])
      {:ok, lv, _html} = live(conn, ~p"/admin/admins")

      lv |> element("#admin-#{target.id} button", "Remove") |> render_click()
      lv |> element("button", "Remove admin") |> render_click()

      refute has_element?(lv, "#admin-#{target.id}")
      assert Accounts.get_admin(target.id) == nil
    end

    test "shows an administrator's detail + activity", %{conn: conn, admin: admin} do
      {:ok, _lv, html} = live(conn, ~p"/admin/admins/#{admin.id}")
      assert html =~ admin.email
      assert html =~ "Activity"
      assert html =~ "Super admin"
    end

    test "redirects for an unknown administrator", %{conn: conn} do
      assert {:error, {kind, %{to: "/admin/admins"}}} =
               live(conn, ~p"/admin/admins/#{Ecto.UUID.generate()}")

      assert kind in [:redirect, :live_redirect]
    end
  end

  describe "super_admin protection (query-layer visibility)" do
    @describetag admin_permissions: ["admin:list", "admin:read"]
    setup :register_and_log_in_normal_admin

    test "a normal admin never sees a super_admin in the list", %{conn: conn, admin: normal} do
      boss = admin_fixture()
      {:ok, lv, html} = live(conn, ~p"/admin/admins")
      assert html =~ normal.email
      refute html =~ boss.email
      refute has_element?(lv, "#admin-#{boss.id}")
      # No create permission → no New admin button.
      refute has_element?(lv, "#new-admin")
    end

    test "a normal admin cannot open a super_admin's detail page", %{conn: conn} do
      boss = admin_fixture()

      assert {:error, {kind, %{to: "/admin/admins"}}} =
               live(conn, ~p"/admin/admins/#{boss.id}")

      assert kind in [:redirect, :live_redirect]
    end
  end
end
