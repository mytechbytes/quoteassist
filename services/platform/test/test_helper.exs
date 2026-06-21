ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(QuoteAssist.Repo, :manual)

# Shared, in-memory DNS stub for custom-domain verification tests (R10-domain).
{:ok, _} = QuoteAssist.DnsStub.start_link()
