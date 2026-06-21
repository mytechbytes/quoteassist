defmodule QuoteAssist.AIService do
  @moduledoc """
  Boundary to the AI service (RELEASE_PLAN.md, R12-quote-reply). Phoenix calls the AI
  service over HTTP; all prompt/model logic lives in the Python `ai-service`, never here.

  Today `generate_reply/1` is a **stub** that returns a placeholder draft so the
  human-in-the-loop reply flow is fully wired. When the real service is ready, only the
  body of this function changes (swap the placeholder for an HTTP call) — no schema,
  context, or UI changes. Generated text is always a *draft* for human review; nothing is
  ever auto-sent.
  """

  alias QuoteAssist.Quotes.QuoteRequest

  @doc """
  Returns a draft reply for a quote request as a plain string. Stub for now — composed
  from the lead's own fields so the draft reads sensibly in the composer.
  """
  def generate_reply(%QuoteRequest{} = quote_request) do
    name = first_name(quote_request.customer_name)

    """
    Hi #{name},

    Thanks for your enquiry about "#{quote_request.subject}". We'd be glad to help and \
    are putting together a quote for you now.

    We'll follow up shortly with the details and pricing. In the meantime, let us know if \
    anything changes or if you have any questions.

    Best regards,
    The team
    """
    |> String.trim()
  end

  defp first_name(name) when is_binary(name) do
    case name |> String.trim() |> String.split(" ", parts: 2) do
      [first | _] when first != "" -> first
      _ -> "there"
    end
  end

  defp first_name(_name), do: "there"
end
