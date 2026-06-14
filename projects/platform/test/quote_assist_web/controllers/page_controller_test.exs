defmodule QuoteAssistWeb.PageControllerTest do
  use QuoteAssistWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "QuoteAssist"
  end
end
