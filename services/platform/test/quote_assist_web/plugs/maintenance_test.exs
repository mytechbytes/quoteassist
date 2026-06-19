defmodule QuoteAssistWeb.Plugs.MaintenanceTest do
  @moduledoc """
  The maintenance gate (R6-errors). Mutates the global `:maintenance_mode` flag, so it
  runs synchronously (`async: false`) and resets the flag after each test.
  """
  use QuoteAssistWeb.ConnCase, async: false

  setup do
    on_exit(fn -> Application.put_env(:quote_assist, :maintenance_mode, false) end)
    :ok
  end

  test "serves the branded 503 for browser requests when maintenance is on", %{conn: conn} do
    Application.put_env(:quote_assist, :maintenance_mode, true)

    conn = get(conn, ~p"/")

    assert conn.status == 503
    assert conn.resp_body =~ "SERVICE_UNAVAILABLE"
  end

  test "lets browser requests through when maintenance is off", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert conn.status == 200
  end

  test "keeps the health probe up during maintenance (it's on the :api pipeline)", %{conn: conn} do
    Application.put_env(:quote_assist, :maintenance_mode, true)

    conn = get(conn, ~p"/health")
    assert conn.status == 200
  end
end
