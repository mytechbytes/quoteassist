defmodule QuoteAssistWeb.PageControllerTest do
  use QuoteAssistWeb.ConnCase

  test "GET / renders the platform build-status table", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)

    assert body =~ "QuoteAssist"
    assert body =~ "Build status"

    # Release train rows (hard-coded in PageHTML.release_tracks/0).
    assert body =~ "R0a"
    assert body =~ "R-CD"
    assert body =~ "R8"

    # Status labels span all three states once R0a is in flight.
    assert body =~ "Done"
    assert body =~ "In progress"
    assert body =~ "Pending"

    # Public chrome: Admin login points at the (R3) admin route.
    assert body =~ "Admin login"
    assert body =~ ~s|href="/admin/login"|
  end
end
