defmodule QuoteAssistWeb.Plugs.LoginThrottle do
  @moduledoc """
  Throttles repeated login attempts on the credential-submitting request, keyed
  by both client IP and the submitted email. Backed by `QuoteAssist.RateLimiter`.

  When either key is over its limit the plug puts an error flash and redirects
  back to the login page, halting the pipeline before any authentication work
  runs. Counting both keys means a single IP can't brute-force many accounts and
  a single account can't be hammered from many IPs.

  Wired on the login POST in the router; reused later for `/admin/login` and
  `/register` (see `docs/RELEASE_PLAN.md`). Limits come from application config:

      config :quote_assist, #{inspect(__MODULE__)},
        ip_limit: 20, email_limit: 10, window_ms: 60_000, redirect_to: "/login"

  Any of those can be overridden per-plug via `opts` (used in tests).
  """

  @behaviour Plug

  import Plug.Conn, only: [halt: 1]
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  alias QuoteAssist.RateLimiter

  @default_ip_limit 20
  @default_email_limit 10
  @default_window_ms 60_000
  @default_redirect_to "/login"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    cfg = config(opts)
    email = email_param(conn)

    over_limit? =
      RateLimiter.hit({:login_ip, ip_key(conn)}, cfg.ip_limit, cfg.window_ms) == limited() or
        (email != nil and
           RateLimiter.hit({:login_email, email}, cfg.email_limit, cfg.window_ms) == limited())

    if over_limit? do
      conn
      |> put_flash(:error, "Too many attempts. Please wait a minute and try again.")
      |> redirect(to: cfg.redirect_to)
      |> halt()
    else
      conn
    end
  end

  @doc """
  Per-email throttle for the magic-link *send* path, called from
  `QuoteAssistWeb.UserLive.Login`. The LiveView socket has no client IP, so this
  limits per-email only. Records a hit and returns `true` once the per-email
  limit for the window is exceeded.
  """
  @spec magic_link_throttled?(String.t()) :: boolean()
  def magic_link_throttled?(email) when is_binary(email) do
    cfg = config([])
    RateLimiter.hit({:login_email, normalize(email)}, cfg.email_limit, cfg.window_ms) == limited()
  end

  defp limited, do: {:error, :rate_limited}

  defp config(opts) do
    env = Application.get_env(:quote_assist, __MODULE__, [])

    %{
      ip_limit: opts[:ip_limit] || env[:ip_limit] || @default_ip_limit,
      email_limit: opts[:email_limit] || env[:email_limit] || @default_email_limit,
      window_ms: opts[:window_ms] || env[:window_ms] || @default_window_ms,
      redirect_to: opts[:redirect_to] || env[:redirect_to] || @default_redirect_to
    }
  end

  defp ip_key(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()

  # phx.gen.auth nests the login form under "user"; fall back to a top-level
  # "email" for the magic-link request form. Downcased so casing can't dodge the
  # per-email limit (emails are citext / case-insensitive anyway).
  defp email_param(conn) do
    case get_in(conn.params, ["user", "email"]) || get_in(conn.params, ["admin", "email"]) ||
           conn.params["email"] do
      email when is_binary(email) and email != "" -> normalize(email)
      _ -> nil
    end
  end

  defp normalize(email), do: String.downcase(email)
end
