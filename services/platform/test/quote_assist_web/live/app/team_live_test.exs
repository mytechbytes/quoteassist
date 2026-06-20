defmodule QuoteAssistWeb.App.TeamLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Repo
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Membership

  # Logs in a member of `tenant` carrying a fresh role with exactly `permissions`.
  defp log_in_role(conn, tenant, permissions) do
    role = role_fixture(tenant, %{permissions: permissions})
    user = user_fixture()
    {:ok, membership} = Tenants.create_membership(tenant, user, role)
    %{conn: log_in_member(conn, user, tenant), user: user, membership: membership}
  end

  describe "access" do
    test "redirects to /login when signed out", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = put_tenant_host(conn, tenant)
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/app/team")
    end

    test "a member without user:list gets the branded 403", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      %{conn: conn} = log_in_role(conn, tenant, [])
      assert_error_sent 403, fn -> get(conn, ~p"/app/team") end
    end
  end

  describe "as an owner" do
    setup :register_and_log_in_member

    test "lists members and shows the invite button", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/app/team")
      assert html =~ user.email
      assert html =~ "Invite member"
    end

    test "invites a member and assigns the agent role", %{conn: conn, tenant: tenant} do
      role = Tenants.get_role_by_slug(tenant, "agent")
      {:ok, lv, _html} = live(conn, ~p"/app/team")

      lv |> element("#invite-member") |> render_click()

      lv
      |> form("#invite-form", invite: %{email: "agent@acme.test", role_id: role.id})
      |> render_submit()

      membership = fetch_membership(tenant, "agent@acme.test")
      assert membership.type == :member
      assert membership.role_id == role.id
    end

    test "deactivating a member blocks their access at the next request", %{
      conn: conn,
      tenant: tenant
    } do
      {member_user, member} = member_fixture(tenant, "agent")
      {:ok, lv, _html} = live(conn, ~p"/app/team")

      lv |> element("#member-#{member.id} button", "Deactivate") |> render_click()

      refute Repo.get(Membership, member.id).active
      assert Tenants.get_active_membership(tenant, member_user) == nil
    end

    test "promotes a member to owner then demotes them back", %{conn: conn, tenant: tenant} do
      {_u, member} = member_fixture(tenant, "agent")
      agent = Tenants.get_role_by_slug(tenant, "agent")
      {:ok, lv, _html} = live(conn, ~p"/app/team")

      lv |> element("#member-#{member.id} button", "Make owner") |> render_click()
      assert Repo.get(Membership, member.id).type == :owner

      lv |> element("#member-#{member.id} button", "Demote") |> render_click()
      lv |> form("#role-assign-form", membership: %{role_id: agent.id}) |> render_submit()
      assert Repo.get(Membership, member.id).type == :member
    end

    test "removes a member via the confirm modal", %{conn: conn, tenant: tenant} do
      {_u, member} = member_fixture(tenant, "agent")
      {:ok, lv, _html} = live(conn, ~p"/app/team")

      lv |> element("#member-#{member.id} button", "Remove") |> render_click()
      lv |> element("button", "Remove member") |> render_click()

      refute has_element?(lv, "#member-#{member.id}")
      assert Repo.get(Membership, member.id).deleted_at
    end

    test "the last active owner can't be removed", %{conn: conn, membership: owner} do
      {:ok, lv, _html} = live(conn, ~p"/app/team")
      # No deactivate/remove control is offered for the acting owner themselves.
      refute has_element?(lv, "#member-#{owner.id} button", "Remove")
    end

    test "invite shows a validation error for a bad email", %{conn: conn, tenant: tenant} do
      role = Tenants.get_role_by_slug(tenant, "agent")
      {:ok, lv, _html} = live(conn, ~p"/app/team")

      lv |> element("#invite-member") |> render_click()

      html =
        lv
        |> form("#invite-form", invite: %{email: "nope", role_id: role.id})
        |> render_change()

      assert html =~ "must have the @ sign"
    end

    test "inviting an existing member surfaces a friendly error", %{conn: conn, tenant: tenant} do
      {existing, _} = member_fixture(tenant, "agent")
      role = Tenants.get_role_by_slug(tenant, "agent")
      {:ok, lv, _html} = live(conn, ~p"/app/team")

      lv |> element("#invite-member") |> render_click()

      html =
        lv
        |> form("#invite-form", invite: %{email: existing.email, role_id: role.id})
        |> render_submit()

      assert html =~ "already a member"
    end
  end

  describe "owner protection from a member" do
    setup :register_and_log_in_member

    @tag role: "agent"
    test "a member never sees an owner in the team list", %{conn: conn, tenant: tenant} do
      {owner_user, owner} = member_fixture(tenant, "owner")
      {:ok, lv, html} = live(conn, ~p"/app/team")

      refute html =~ owner_user.email
      refute has_element?(lv, "#member-#{owner.id}")
      # An agent holds user:list/read but not user:create → no invite button.
      refute has_element?(lv, "#invite-member")
    end
  end

  defp fetch_membership(tenant, email) do
    user = QuoteAssist.Accounts.get_user_by_email(email)
    Tenants.get_active_membership(tenant, user)
  end
end
