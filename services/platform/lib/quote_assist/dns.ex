defmodule QuoteAssist.Dns do
  @moduledoc """
  Thin wrapper over Erlang's `:inet_res` resolver — the single place real DNS is hit
  (R10-domain custom-domain verification).

  `txt_records/1` returns the TXT records for a host as a list of strings (each record's
  character strings are concatenated, per RFC 1035 §3.3.14). Lookup failures (NXDOMAIN,
  timeout, …) come back as `[]` rather than raising, so a missing record is just "not
  verified yet", not a crash.

  Tests don't hit the network: `QuoteAssist.Tenants` resolves the configured
  `:dns_resolver` (defaulting to this module), and the test env points it at a stub.
  """

  @behaviour QuoteAssist.Dns.Resolver

  @impl true
  # coveralls-ignore-start — hits real DNS over the network; exercised in deployment, not
  # unit tests (which use QuoteAssist.DnsStub via the :dns_resolver app env).
  def txt_records(domain) when is_binary(domain) do
    domain
    |> String.to_charlist()
    |> :inet_res.lookup(:in, :txt)
    |> Enum.map(fn parts -> Enum.map_join(parts, &to_string/1) end)
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  # coveralls-ignore-stop
end
