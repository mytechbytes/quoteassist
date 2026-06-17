defmodule QuoteAssist.Repo do
  use Ecto.Repo,
    otp_app: :quote_assist,
    adapter: Ecto.Adapters.Postgres
end
