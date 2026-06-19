defmodule QuoteAssistWeb.FallbackControllerTest do
  use QuoteAssistWeb.ConnCase, async: true

  alias QuoteAssistWeb.FallbackController

  # The controller renders ErrorHTML directly; give the conn the endpoint it needs to
  # resolve the verified-route stylesheet path in the template.
  defp render_fallback(conn, result) do
    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, @endpoint)
    |> FallbackController.call(result)
  end

  test "maps {:error, :unauthenticated} to the branded 401", %{conn: conn} do
    conn = render_fallback(conn, {:error, :unauthenticated})
    assert conn.status == 401
    assert conn.resp_body =~ "UNAUTHORIZED"
  end

  test "maps {:error, :unauthorized} to the branded 403", %{conn: conn} do
    conn = render_fallback(conn, {:error, :unauthorized})
    assert conn.status == 403
    assert conn.resp_body =~ "FORBIDDEN"
  end

  test "maps {:error, :not_found} to the branded 404", %{conn: conn} do
    conn = render_fallback(conn, {:error, :not_found})
    assert conn.status == 404
    assert conn.resp_body =~ "NOT_FOUND"
  end
end
