import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/quote_assist start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :quote_assist, QuoteAssistWeb.Endpoint, server: true
end

config :quote_assist, QuoteAssistWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Service integrations — read in all environments so the values injected by
# docker-compose / .env land in application config instead of being silently
# dropped. Consumers arrive in later releases (Redis: rate limiting + background
# jobs; AI service: R8 quote-reply generation). Read with
# `Application.get_env(:quote_assist, :ai_service_url | :redis_url)`.
config :quote_assist,
  ai_service_url: System.get_env("AI_SERVICE_URL") || "http://localhost:8000",
  redis_url: System.get_env("REDIS_URL")

# Deployment environment tag surfaced in the platform footer (R0a). Staging and
# prod both run as :prod releases, so they are told apart by DEPLOY_ENV; when it
# is unset we fall back to the compile-time environment (dev/test → itself,
# prod → "prod").
config :quote_assist, :deploy_env, System.get_env("DEPLOY_ENV") || to_string(config_env())

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :quote_assist, QuoteAssist.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :quote_assist, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # LiveView socket origin (R2). Tenants live on their own subdomains
  # (`*.quoteassist.mytechbytes.in`), so the `/live` websocket must accept those
  # origins — the default `check_origin` (the platform host only) rejects every
  # tenant subdomain. Allow the apex host plus the wildcard subdomain.
  #
  # Verified custom domains (R10-domain) are dynamic and won't match the wildcard;
  # when that ships, authorise them by appending an MFA that checks the DB (mirrors
  # the Caddy on-demand-TLS `ask` gate), e.g.:
  #
  #     check_origin: [..., {QuoteAssist.Tenants, :verified_origin?, []}]
  config :quote_assist, QuoteAssistWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: ["//#{host}", "//*.#{host}"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :quote_assist, QuoteAssistWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :quote_assist, QuoteAssistWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :quote_assist, QuoteAssist.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
