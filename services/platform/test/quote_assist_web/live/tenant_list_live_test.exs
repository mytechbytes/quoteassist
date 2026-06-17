defmodule QuoteAssistWeb.TenantListLiveTest do
  use QuoteAssistWeb.ConnCase

  import Phoenix.LiveViewTest

  test "GET /tenants renders the directory with an empty state", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/tenants")

    assert html =~ "Tenants"
    assert html =~ "No tenants yet"

    # Public chrome is shared with the home page.
    assert html =~ "Admin login"
  end
end
