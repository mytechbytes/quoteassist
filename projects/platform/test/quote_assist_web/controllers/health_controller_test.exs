defmodule QuoteAssistWeb.HealthControllerTest do
  use QuoteAssistWeb.ConnCase, async: true

  test "GET /health returns liveness", %{conn: conn} do
    conn = get(conn, ~p"/health")
    body = json_response(conn, 200)
    assert body["status"] == "ok"
    assert body["service"] == "platform"
  end

  test "GET /health/ready returns readiness when the DB is up", %{conn: conn} do
    conn = get(conn, ~p"/health/ready")
    body = json_response(conn, 200)
    assert body["status"] == "ready"
    assert body["checks"]["database"] == "ok"
  end
end
