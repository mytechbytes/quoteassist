defmodule QuoteAssistWeb.HealthController do
  use QuoteAssistWeb, :controller

  @doc """
  GET /health — liveness probe.

  Returns 200 immediately if the application process is running.
  Safe to call with no DB dependency; suitable for load-balancer pings.
  """
  def liveness(conn, _params) do
    json(conn, %{status: "ok"})
  end

  @doc """
  GET /health/ready — readiness probe.

  Returns 200 if the database is reachable. Returns 503 if not.
  Used by container orchestrators before routing traffic.
  """
  def readiness(conn, _params) do
    case check_db() do
      :ok ->
        json(conn, %{status: "ready"})

      # coveralls-ignore-start — DB-down path is verified in deployment (smoke
      # test), not unit-tested; no deterministic way to drop the DB mid-test.
      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unavailable", reason: inspect(reason)})
        # coveralls-ignore-stop
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp check_db do
    QuoteAssist.Repo.query!("SELECT 1")
    :ok
  rescue
    # coveralls-ignore-start — failure path requires the DB to be unreachable.
    error -> {:error, error}
    # coveralls-ignore-stop
  end
end
