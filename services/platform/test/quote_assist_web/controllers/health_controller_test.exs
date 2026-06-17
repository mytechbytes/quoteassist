defmodule QuoteAssistWeb.HealthControllerTest do
  use QuoteAssistWeb.ConnCase

  describe "GET /health" do
    test "returns 200 with status ok", %{conn: conn} do
      conn = get(conn, ~p"/health")
      assert json_response(conn, 200) == %{"status" => "ok"}
    end
  end

  describe "GET /health/ready" do
    test "returns 200 with status ready when DB is reachable", %{conn: conn} do
      conn = get(conn, ~p"/health/ready")
      assert json_response(conn, 200) == %{"status" => "ready"}
    end
  end
end
