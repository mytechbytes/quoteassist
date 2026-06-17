defmodule QuoteAssist.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QuoteAssistWeb.Telemetry,
      QuoteAssist.Repo,
      {DNSCluster, query: Application.get_env(:quote_assist, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: QuoteAssist.PubSub},
      # In-memory login throttle backend (QuoteAssistWeb.Plugs.LoginThrottle).
      QuoteAssist.RateLimiter,
      # Start to serve requests, typically the last entry
      QuoteAssistWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: QuoteAssist.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QuoteAssistWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
