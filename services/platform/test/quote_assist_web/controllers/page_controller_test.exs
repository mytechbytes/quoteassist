defmodule QuoteAssistWeb.PageControllerTest do
  use QuoteAssistWeb.ConnCase

  test "GET / renders the R0 placeholder page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "QuoteAssist"
    assert html_response(conn, 200) =~ "R0"
  end
end
