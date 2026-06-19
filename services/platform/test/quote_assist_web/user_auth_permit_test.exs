defmodule QuoteAssistWeb.UserAuthPermitTest do
  @moduledoc """
  `UserAuth.permit!/2` — the tenant-side "raise → branded 403" authorization primitive
  (R6-errors). The R7-rbac LiveView guards call it; here we check the predicate and the
  raise in isolation.
  """
  use ExUnit.Case, async: true

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Tenants.Membership
  alias QuoteAssistWeb.Errors.UnauthorizedError
  alias QuoteAssistWeb.UserAuth

  test "returns the scope for an owner (computed all-access)" do
    scope = %Scope{membership: %Membership{type: :owner}, permissions: []}
    assert UserAuth.permit!(scope, "quote:delete") == scope
  end

  test "returns the scope when a member's role grants the permission" do
    scope = %Scope{membership: %Membership{type: :member}, permissions: ["quote:list"]}
    assert UserAuth.permit!(scope, "quote:list") == scope
  end

  test "raises UnauthorizedError (403) when a member lacks the permission" do
    scope = %Scope{membership: %Membership{type: :member}, permissions: ["quote:list"]}
    assert_raise UnauthorizedError, fn -> UserAuth.permit!(scope, "quote:delete") end
  end
end
