defmodule QuoteAssist.DnsStub do
  @moduledoc """
  In-memory `QuoteAssist.Dns.Resolver` for tests (R10-domain) — no network. A single
  Agent maps `domain => [txt records]`; `put/2` publishes a domain's records and
  `txt_records/1` returns them (or `[]` when unknown). Tests use unique domains, so the
  shared Agent is safe under `async: true`. Started in `test_helper.exs`.
  """

  @behaviour QuoteAssist.Dns.Resolver

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @doc "Publish the TXT records a lookup of `domain` should return."
  def put(domain, records) when is_binary(domain) and is_list(records) do
    Agent.update(__MODULE__, &Map.put(&1, String.downcase(domain), records))
  end

  @impl true
  def txt_records(domain) when is_binary(domain) do
    Agent.get(__MODULE__, &Map.get(&1, String.downcase(domain), []))
  end
end
