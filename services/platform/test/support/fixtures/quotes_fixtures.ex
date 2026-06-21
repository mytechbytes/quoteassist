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
      "body" => "We'd like a quote for an upcoming trip."
    })
  end

  @doc "Creates a quote request for the scope's tenant (as the scope's member)."
  def quote_request_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, quote_request} = Quotes.create_quote_request(scope, valid_quote_attrs(attrs))
    quote_request
  end
end
