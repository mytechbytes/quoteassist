defmodule QuoteAssistWeb.App.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias QuoteAssist.Accounts.User
  alias QuoteAssist.Tenants.{Membership, Role}
  alias QuoteAssistWeb.App.Components

  test "member_type_badge distinguishes owners from members" do
    assert render_component(&Components.member_type_badge/1, type: :owner) =~ "Owner"
    assert render_component(&Components.member_type_badge/1, type: :member) =~ "Member"
  end

  test "member_active_badge reflects the active flag" do
    assert render_component(&Components.member_active_badge/1, active: true) =~ "Active"
    assert render_component(&Components.member_active_badge/1, active: false) =~ "Inactive"
  end

  test "request_status_badge labels each status" do
    for {status, label} <- [
          {:open, "Open"},
          {:approved, "Approved"},
          {:declined, "Declined"},
          {:cancelled, "Cancelled"}
        ] do
      assert render_component(&Components.request_status_badge/1, status: status) =~ label
    end
  end

  test "member_name prefers the display name, falls back to the email local part" do
    named = %Membership{user: %User{display_name: "Rana", email: "rana@acme.com"}}
    unnamed = %Membership{user: %User{display_name: nil, email: "rana@acme.com"}}
    assert Components.member_name(named) == "Rana"
    assert Components.member_name(unnamed) == "rana"
    assert Components.member_name(%Membership{}) == "—"
  end

  test "member_role_label uses the membership role" do
    owner = %Membership{type: :owner}
    member = %Membership{type: :member, role: %Role{name: "Agent"}}
    assert Components.member_role_label(owner) == "Owner"
    assert Components.member_role_label(member) == "Agent"
  end

  test "format_datetime renders or dashes" do
    assert Components.format_datetime(~U[2026-06-20 09:30:00Z]) =~ "20 Jun 2026"
    assert Components.format_datetime(nil) == "—"
  end
end
