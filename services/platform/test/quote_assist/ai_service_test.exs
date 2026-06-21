defmodule QuoteAssist.AIServiceTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.AIService
  alias QuoteAssist.Quotes.QuoteRequest

  defp quote_request(attrs) do
    struct(%QuoteRequest{subject: "Trip enquiry", customer_name: "Rana Aziz"}, attrs)
  end

  test "draft greets the customer's first name and references the subject" do
    draft =
      AIService.generate_reply(quote_request(%{customer_name: "Rana Aziz", subject: "LHR → JFK"}))

    assert draft =~ "Hi Rana,"
    assert draft =~ "LHR → JFK"
  end

  test "falls back to a neutral greeting when there's no usable name" do
    assert AIService.generate_reply(quote_request(%{customer_name: ""})) =~ "Hi there,"
    assert AIService.generate_reply(quote_request(%{customer_name: nil})) =~ "Hi there,"
  end

  test "uses a single-word name as-is" do
    assert AIService.generate_reply(quote_request(%{customer_name: "Marcus"})) =~ "Hi Marcus,"
  end
end
