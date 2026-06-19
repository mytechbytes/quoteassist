defmodule QuoteAssistWeb.Plugs.Maintenance do
  @moduledoc """
  Renders the branded 503 maintenance page for every browser request while the
  `:maintenance_mode` flag is on (R6-errors). Off by default; flipped per deploy via
  the `MAINTENANCE_MODE` env var (see `config/runtime.exs`).

  Runs first in the `:browser` pipeline, so it short-circuits before any tenant
  resolution or auth. The health probes live on the `:api` pipeline (no maintenance
  plug), so load balancers can still read liveness/readiness while the site is down
  for maintenance.
  """
  @behaviour Plug

  import Plug.Conn, only: [put_status: 2, halt: 1]
  import Phoenix.Controller, only: [put_view: 2, put_format: 2, render: 2]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    if maintenance_mode?() do
      conn
      |> put_status(:service_unavailable)
      |> put_format("html")
      |> put_view(html: QuoteAssistWeb.ErrorHTML)
      |> render(:"503")
      |> halt()
    else
      conn
    end
  end

  defp maintenance_mode? do
    Application.get_env(:quote_assist, :maintenance_mode, false) == true
  end
end
