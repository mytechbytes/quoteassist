defmodule QuoteAssistWeb.PageControllerTest do
  use QuoteAssistWeb.ConnCase

  test "GET / renders the platform build-status table", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)

    assert body =~ "QuoteAssist"
    assert body =~ "Build status"

    # Release train rows (hard-coded in PageHTML.release_tracks/0).
    assert body =~ "R0a"
    assert body =~ "R10-domain"
    assert body =~ "R12-quote-reply"

    # Status labels: R0–R3 are done, later releases pending.
    assert body =~ "Done"
    assert body =~ "Pending"

    # Public chrome: Admin login points at the (R3) admin route.
    assert body =~ "Admin login"
    assert body =~ ~s|href="/admin/login"|
  end
end
