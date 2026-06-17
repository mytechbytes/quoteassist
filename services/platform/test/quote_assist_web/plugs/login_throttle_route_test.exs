defmodule QuoteAssistWeb.LoginThrottleRouteTest do
  # async: false — mutates the global LoginThrottle config + shared RateLimiter,
  # so it must run in isolation from the async login tests.
  use QuoteAssistWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.RateLimiter
  alias QuoteAssistWeb.Plugs.LoginThrottle

  setup do
    original = Application.get_env(:quote_assist, LoginThrottle)

    on_exit(fn ->
      Application.put_env(:quote_assist, LoginThrottle, original)
      RateLimiter.reset()
    end)

    RateLimiter.reset()
    :ok
  end

  test "throttles repeated login POSTs from the same IP", %{conn: conn} do
    Application.put_env(:quote_assist, LoginThrottle,
      ip_limit: 2,
      email_limit: 1_000,
      window_ms: 60_000,
      redirect_to: "/login"
    )

    user = user_fixture() |> set_password()
    creds = %{"user" => %{"email" => user.email, "password" => "wrong-password"}}

    # First two POSTs reach the controller (invalid creds → redirect to /login).
    for _ <- 1..2 do
      resp = post(conn, ~p"/login", creds)
      assert redirected_to(resp) == ~p"/login"
      assert Phoenix.Flash.get(resp.assigns.flash, :error) == "Invalid email or password"
    end

    # The third POST is throttled before authentication runs.
    resp = post(conn, ~p"/login", creds)
    assert redirected_to(resp) == ~p"/login"
    assert Phoenix.Flash.get(resp.assigns.flash, :error) =~ "Too many attempts"
  end

  test "throttles repeated magic-link sends for the same email", %{conn: conn} do
    Application.put_env(:quote_assist, LoginThrottle,
      ip_limit: 1_000,
      email_limit: 1,
      window_ms: 60_000,
      redirect_to: "/login"
    )

    user = user_fixture()

    # First send is allowed (navigates away with the neutral info flash).
    {:ok, lv, _html} = live(conn, ~p"/login")
    lv |> form("#login_form_magic", user: %{email: user.email}) |> render_submit()

    # Second send for the same email is throttled — stays on the page with an error.
    {:ok, lv2, _html} = live(conn, ~p"/login")
    html = lv2 |> form("#login_form_magic", user: %{email: user.email}) |> render_submit()

    assert html =~ "Too many attempts"
  end
end
