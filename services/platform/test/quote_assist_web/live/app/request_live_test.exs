defmodule QuoteAssistWeb.App.RequestLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Requests
  alias QuoteAssist.Tenants

  describe "as a member" do
    setup :register_and_log_in_member

    @tag role: "agent"
    test "raises a leave request, then can cancel it", %{conn: conn, membership: member} do
      {:ok, lv, _html} = live(conn, ~p"/app/requests")

      lv |> element("#raise-leave") |> render_click()
      lv |> form("#request-form", request: %{note: "Moving on"}) |> render_submit()

      assert Requests.has_open_request?(member, :leave)
      # The raise button disappears once an open leave exists.
      refute has_element?(lv, "#raise-leave")
      # An agent has no request:list, so the all-requests inbox is hidden.
      refute has_element?(lv, "#request-inbox")

      [req] = Requests.list_requests_for_member(member)
      lv |> element("#my-request-#{req.id} button", "Cancel") |> render_click()
      refute Requests.has_open_request?(member, :leave)
    end
  end

  describe "as an owner processing the inbox" do
    setup :register_and_log_in_member

    test "approves a member's leave, removing them", %{conn: conn, tenant: tenant} do
      {member_user, member} = member_fixture(tenant, "agent")
      member_scope = scope_fixture(tenant, member_user, member)
      {:ok, req} = Requests.create_request(member_scope, %{"type" => "leave", "note" => "bye"})

      {:ok, lv, _html} = live(conn, ~p"/app/requests")
      assert has_element?(lv, "#request-inbox")

      lv |> element("#inbox-request-#{req.id} button", "Approve") |> render_click()
      lv |> form("#resolve-form", %{resolution: "Take care"}) |> render_submit()

      assert Requests.get_request(tenant, req.id).status == :approved
      assert Tenants.get_active_membership(tenant, member_user) == nil
    end

    test "declines a member's leave, keeping them", %{conn: conn, tenant: tenant} do
      {member_user, member} = member_fixture(tenant, "agent")
      member_scope = scope_fixture(tenant, member_user, member)
      {:ok, req} = Requests.create_request(member_scope, %{"type" => "leave"})

      {:ok, lv, _html} = live(conn, ~p"/app/requests")

      lv |> element("#inbox-request-#{req.id} button", "Decline") |> render_click()
      lv |> form("#resolve-form", %{resolution: "Let's talk"}) |> render_submit()

      assert Requests.get_request(tenant, req.id).status == :declined
      assert Tenants.get_active_membership(tenant, member_user)
    end
  end
end
