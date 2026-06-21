defmodule QuoteAssist.QuotesFixtures do
  @moduledoc "Test helpers for quote requests + reply messages via `QuoteAssist.Quotes`."

  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Quotes

  def valid_quote_attrs(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    Enum.into(attrs, %{
      "customer_name" => "Customer #{n}",
      "customer_email" => "customer#{n}@example.com",
      "subject" => "Trip enquiry #{n}",
      "body" => "We'd like a quote for an upcoming trip.",
      "route" => "LHR–HND",
      "travel_dates" => "14–28 Aug",
      "pax" => "2A · 2C",
      "total" => 6150,
      "currency" => "GBP"
    })
  end

  @doc "Creates a quote request (status `:new`) for the scope's tenant."
  def quote_request_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, quote_request} = Quotes.create_quote_request(scope, valid_quote_attrs(attrs))
    quote_request
  end

  @doc """
  A quoted (sent) quote: creates a lead, composes a draft, and sends it — leaving the
  quote in `:quoted` with one `:sent` message. Returns the reloaded quote.
  """
  def quoted_quote_fixture(%Scope{} = scope, attrs \\ %{}) do
    quote = quote_request_fixture(scope, attrs)
    {:ok, draft} = Quotes.compose_draft(scope, quote, "Here is your quote.")
    {:ok, _sent} = Quotes.send_message(scope, draft)
    Quotes.get_quote_request(scope, quote.id)
  end
end
