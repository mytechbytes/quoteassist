defmodule QuoteAssistWeb.Plugs.LoginThrottleTest do
  # async: false — exercises the process-wide RateLimiter table.
  use QuoteAssistWeb.ConnCase, async: false

  alias QuoteAssist.RateLimiter
  alias QuoteAssistWeb.Plugs.LoginThrottle

  setup do
    RateLimiter.reset()
    :ok
  end

  # Build a conn shaped like a login POST: a session + flash (so put_flash works),
  # an explicit remote IP, and pre-set params (the plug reads email from params).
  defp login_conn(params, remote_ip) do
    Phoenix.ConnTest.build_conn()
    |> Map.put(:remote_ip, remote_ip)
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.Controller.fetch_flash()
    |> Map.put(:params, params)
  end

  test "passes the connection through while under the limit" do
    opts = LoginThrottle.init(ip_limit: 5, email_limit: 5, window_ms: 60_000)
    conn = LoginThrottle.call(login_conn(%{"user" => %{"email" => "a@b.com"}}, {127, 0, 0, 1}), opts)

    refute conn.halted
  end

  test "halts and redirects to /login once the per-email limit is exceeded" do
    opts =
      LoginThrottle.init(ip_limit: 1_000, email_limit: 2, window_ms: 60_000, redirect_to: "/login")

    email = "throttle@example.com"

    # Vary the IP so the per-IP limit is never the trigger here.
    refute LoginThrottle.call(login_conn(%{"user" => %{"email" => email}}, {127, 0, 0, 1}), opts).halted
    refute LoginThrottle.call(login_conn(%{"user" => %{"email" => email}}, {127, 0, 0, 2}), opts).halted

    conn = LoginThrottle.call(login_conn(%{"user" => %{"email" => email}}, {127, 0, 0, 3}), opts)

    assert conn.halted
    assert redirected_to(conn) == "/login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many attempts"
  end

  test "halts once the per-IP limit is exceeded, regardless of email" do
    opts = LoginThrottle.init(ip_limit: 2, email_limit: 1_000, window_ms: 60_000)
    ip = {203, 0, 113, 5}

    refute LoginThrottle.call(login_conn(%{"user" => %{"email" => "a@x.com"}}, ip), opts).halted
    refute LoginThrottle.call(login_conn(%{"user" => %{"email" => "b@x.com"}}, ip), opts).halted

    assert LoginThrottle.call(login_conn(%{"user" => %{"email" => "c@x.com"}}, ip), opts).halted
  end

  test "throttles by IP even when no email is present (e.g. magic-link form blank)" do
    opts = LoginThrottle.init(ip_limit: 1, email_limit: 1_000, window_ms: 60_000)
    ip = {198, 51, 100, 7}

    refute LoginThrottle.call(login_conn(%{}, ip), opts).halted
    assert LoginThrottle.call(login_conn(%{}, ip), opts).halted
  end
end
