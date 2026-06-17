defmodule QuoteAssist.RateLimiter do
  @moduledoc """
  Fixed-window in-memory rate limiter backed by a single public ETS table.

  Used by `QuoteAssistWeb.Plugs.LoginThrottle` to throttle repeated login
  attempts per IP and per email. Cheap and node-local — good enough for a single
  node and a public login URL. When the platform runs multiple nodes (or needs
  durable limits), swap the ETS backend for Redis (`:redis_url` is already
  plumbed in `config/runtime.exs`); the `hit/3` contract here stays the same.

  Counting is a fixed window: each `{key, window_start}` bucket counts hits via
  `:ets.update_counter/4`, where `window_start` is the absolute millisecond the
  bucket's window began. A periodic sweep drops buckets older than `@retain_ms`
  so the table can't grow without bound.
  """

  use GenServer

  @table __MODULE__
  @sweep_interval_ms :timer.minutes(5)
  # Buckets older than this are swept. Must comfortably exceed the largest
  # `window_ms` any caller uses (login windows are on the order of a minute).
  @retain_ms :timer.hours(1)

  # ── Client ──────────────────────────────────────────────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records one hit for `key` in the current `window_ms` window and reports
  whether the caller is still within `limit` hits for that window.

  Returns `:ok` while at or below `limit`, and `{:error, :rate_limited}` once the
  limit is exceeded (i.e. on hit number `limit + 1` and after, within the window).
  """
  @spec hit(term(), pos_integer(), pos_integer()) :: :ok | {:error, :rate_limited}
  def hit(key, limit, window_ms)
      when is_integer(limit) and limit > 0 and is_integer(window_ms) and window_ms > 0 do
    now = System.system_time(:millisecond)
    window_start = now - rem(now, window_ms)
    bucket = {key, window_start}
    count = :ets.update_counter(@table, bucket, {2, 1}, {bucket, 0})

    if count > limit, do: {:error, :rate_limited}, else: :ok
  end

  @doc "Clears all recorded hits. Intended for tests."
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@table)
    :ok
  end

  # ── Server ──────────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval_ms)

  # Delete every bucket whose window started before the retain horizon. The
  # match spec matches on the second element of the {key, window_start} tuple.
  defp sweep do
    cutoff = System.system_time(:millisecond) - @retain_ms
    :ets.select_delete(@table, [{{{:_, :"$1"}, :_}, [{:<, :"$1", cutoff}], [true]}])
  end
end
