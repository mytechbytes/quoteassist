import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
#
# DATABASE_URL lets CI point tests at a containerised Postgres (e.g. the
# Jenkins `quoteassist-postgres-ci` service); locally it falls back to a
# localhost connection with optional per-partition database names.
config :quote_assist, QuoteAssist.Repo,
  url:
    System.get_env("DATABASE_URL") ||
      "ecto://postgres:postgres@localhost/quote_assist_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :quote_assist, QuoteAssistWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "sL1xmfzwow0gh/QvvreSYqnLT5SkOw2mcmNlwxAqE24fj1ayKnEYOeJgti/+a7bK",
  server: false

# In test we don't send emails
config :quote_assist, QuoteAssist.Mailer, adapter: Swoosh.Adapters.Test

# Effectively disable the login throttle by default so generated auth tests
# (which submit many logins) aren't rate-limited. The throttle's own test passes
# explicit low limits via plug opts to exercise the limiting path.
config :quote_assist, QuoteAssistWeb.Plugs.LoginThrottle,
  ip_limit: 1_000_000,
  email_limit: 1_000_000,
  window_ms: 60_000,
  redirect_to: "/login"

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
