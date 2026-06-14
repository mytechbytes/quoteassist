defmodule QuoteAssistWeb.HealthController do
  @moduledoc """
  R0 · Liveness and readiness probes (used by Caddy/Container health checks and
  the deploy smoke test).

    * `GET /health`        — liveness: the app is up. Always 200.
    * `GET /health/ready`  — readiness: dependencies (DB) are reachable. 200 / 503.
  """
  use QuoteAssistWeb, :controller

  alias Ecto.Adapters.SQL

  def show(conn, _params) do
    json(conn, %{status: "ok", service: "platform", version: version()})
  end

  def ready(conn, _params) do
    if database_up?() do
      json(conn, %{status: "ready", checks: %{database: "ok"}})
    else
      conn
      |> put_status(:service_unavailable)
      |> json(%{status: "unavailable", checks: %{database: "down"}})
    end
  end

  defp database_up? do
    case SQL.query(QuoteAssist.Repo, "SELECT 1", []) do
      {:ok, _} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp version do
    case :application.get_key(:quote_assist, :vsn) do
      {:ok, vsn} -> to_string(vsn)
      _ -> "dev"
    end
  end
end
