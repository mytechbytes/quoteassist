import Config

# Configure your database.
#
# In CI the database lives in a throwaway container, so DATABASE_URL is set and
# wins. Locally (no DATABASE_URL) we fall back to localhost. MIX_TEST_PARTITION
# enables built-in test partitioning — see `mix help test`.
if database_url = System.get_env("DATABASE_URL") do
  config :quote_assist, QuoteAssist.Repo,
    url: database_url,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
else
  config :quote_assist, QuoteAssist.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "quote_assist_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
end

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :quote_assist, QuoteAssistWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "hJdIDT/N3dporLSqpOY7QY4e5hUIw5JTnjaEowH1E/KJYRnDv7261CJyYCrVhzRU",
  server: false

# In test we don't send emails
config :quote_assist, QuoteAssist.Mailer, adapter: Swoosh.Adapters.Test

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
