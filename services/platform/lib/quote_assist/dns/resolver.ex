defmodule QuoteAssist.Dns.Resolver do
  @moduledoc """
  Behaviour for a TXT-record resolver (R10-domain). `QuoteAssist.Dns` is the real
  `:inet_res`-backed implementation; the test env swaps in a deterministic stub. The
  resolver is chosen at runtime via the `:dns_resolver` application env, so verification
  never hits the network in tests.
  """

  @callback txt_records(domain :: String.t()) :: [String.t()]
end
