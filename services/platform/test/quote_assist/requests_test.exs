defmodule QuoteAssist.RequestsTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Audit
  alias QuoteAssist.Requests
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Request

  defp audited?(tenant_id, action) do
    tenant_id |> Audit.list_for_tenant(100) |> Enum.any?(&(&1.action == action))
  end

  setup do
    ctx = owner_scope_fixture(%{slug: "acme"})
    {member_user, member} = member_fixture(ctx.tenant, "agent")
    member_scope = scope_fixture(ctx.tenant, member_user, member)
    Map.merge(ctx, %{member: member, member_user: member_user, member_scope: member_scope})
  end

  describe "Request schema" do
    test "exposes its types/statuses and labels" do
      assert Request.types() == [:leave]
      assert :open in Request.statuses()
      assert Request.type_label(:leave) == "Leave workspace"
      assert Request.type_label(:other) == "Other"
      assert Request.status_label(:approved) == "Approved"
      assert Request.can_transition?(:open, :approved)
      refute Request.can_transition?(:approved, :open)
    end
  end

  describe "create_request/2" do
    test "raises a leave request (audited) and caps at one open per type", ctx do
      assert {:ok, request} =
               Requests.create_request(ctx.member_scope, %{
                 "type" => "leave",
                 "note" => "Moving on"
               })

      assert request.type == :leave
      assert request.status == :open
      assert request.requested_by == ctx.member.id
      assert Requests.has_open_request?(ctx.member, :leave)
      assert audited?(ctx.tenant.id, "request.created")

      assert {:error, changeset} =
               Requests.create_request(ctx.member_scope, %{"type" => "leave"})

      assert errors_on(changeset).type != []
    end
  end

  describe "listing" do
    test "owner inbox sees all; a member sees only their own", ctx do
      {:ok, req} = Requests.create_request(ctx.member_scope, %{"type" => "leave"})

      assert ctx.tenant |> Requests.list_requests() |> Enum.map(& &1.id) == [req.id]
      assert ctx.member |> Requests.list_requests_for_member() |> Enum.map(& &1.id) == [req.id]
      assert Requests.get_request(ctx.tenant, req.id).id == req.id
      assert Requests.get_request(ctx.tenant, "not-a-uuid") == nil
    end
  end

  describe "cancel_request/2" do
    test "the requester can cancel their own open request", ctx do
      {:ok, req} = Requests.create_request(ctx.member_scope, %{"type" => "leave"})

      assert {:ok, cancelled} = Requests.cancel_request(ctx.member_scope, req)
      assert cancelled.status == :cancelled
      assert audited?(ctx.tenant.id, "request.cancelled")
      refute Requests.has_open_request?(ctx.member, :leave)
    end

    test "another member cannot cancel someone else's request", ctx do
      {:ok, req} = Requests.create_request(ctx.member_scope, %{"type" => "leave"})
      assert {:error, :not_owner} = Requests.cancel_request(ctx.scope, req)
    end
  end

  describe "approve_request/3" do
    test "approving a leave removes the requester's membership (audited)", ctx do
      {:ok, req} = Requests.create_request(ctx.member_scope, %{"type" => "leave"})

      assert {:ok, approved} = Requests.approve_request(ctx.scope, req, "Sorry to see you go")
      assert approved.status == :approved
      assert approved.resolved_by == ctx.membership.id
      assert Tenants.get_active_membership(ctx.tenant, ctx.member_user) == nil
      assert audited?(ctx.tenant.id, "request.approved")
      assert audited?(ctx.tenant.id, "user.removed")
    end
  end

  describe "decline_request/3" do
    test "declining records the resolution and keeps the membership", ctx do
      {:ok, req} = Requests.create_request(ctx.member_scope, %{"type" => "leave"})

      assert {:ok, declined} = Requests.decline_request(ctx.scope, req, "Let's talk first")
      assert declined.status == :declined
      assert declined.resolution == "Let's talk first"
      assert Tenants.get_active_membership(ctx.tenant, ctx.member_user)
      assert audited?(ctx.tenant.id, "request.declined")
    end

    test "a resolved request can't be resolved again", ctx do
      {:ok, req} = Requests.create_request(ctx.member_scope, %{"type" => "leave"})
      {:ok, declined} = Requests.decline_request(ctx.scope, req, "no")

      assert {:error, changeset} = Requests.decline_request(ctx.scope, declined, "again")
      assert errors_on(changeset).status != []
    end
  end
end
