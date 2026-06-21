defmodule QuoteAssistWeb.App.QuoteLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.QuotesFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Quotes
  alias QuoteAssist.Tenants

  defp owner_conn(conn) do
    %{tenant: tenant, user: user, scope: scope} = owner_scope_fixture(%{slug: "acme"})
    %{conn: log_in_member(conn, user, tenant), tenant: tenant, scope: scope}
  end

  defp role_conn(conn, tenant, permissions) do
    role = role_fixture(tenant, %{permissions: permissions})
    user = user_fixture()
    {:ok, _m} = Tenants.create_membership(tenant, user, role)
    log_in_member(conn, user, tenant)
  end

  defp owner_scope_for(tenant) do
    {user, membership} = member_fixture(tenant, "owner")
    scope_fixture(tenant, user, membership)
  end

  describe "index (list-kit)" do
    test "lists quotes with the reference and travel facts", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote_request_fixture(scope, %{"customer_name" => "The Bennetts", "route" => "LHR–HND"})

      {:ok, lv, html} = live(conn, ~p"/app/quotes")
      assert html =~ "Quotes"
      assert html =~ "The Bennetts"
      assert html =~ "LHR–HND"
      assert html =~ "QA-1001"
      assert has_element?(lv, "#new-quote")
    end

    test "search narrows the list", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote_request_fixture(scope, %{"customer_name" => "Keep Me"})
      quote_request_fixture(scope, %{"customer_name" => "Hide Me"})

      {:ok, lv, _html} = live(conn, ~p"/app/quotes")
      html = lv |> form("#quote-search", %{query: "keep"}) |> render_change()
      assert html =~ "Keep Me"
      refute html =~ "Hide Me"
    end

    test "add a status filter, then remove it", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      new_lead = quote_request_fixture(scope, %{"customer_name" => "Fresh Lead"})
      _quoted = quoted_quote_fixture(scope, %{"customer_name" => "Quoted Lead"})

      {:ok, lv, _html} = live(conn, ~p"/app/quotes")

      # Add a filter row, set it to status is new.
      lv |> element("button", "Add filter") |> render_click()

      html =
        lv
        |> form("#quote-filters", %{
          "filters" => %{"1" => %{"field" => "status", "op" => "is", "value" => "new"}}
        })
        |> render_change()

      assert html =~ "Fresh Lead"
      refute html =~ "Quoted Lead"
      assert new_lead

      # Remove the filter — both reappear.
      html = lv |> element("button[phx-value-id='1']") |> render_click()
      assert html =~ "Fresh Lead"
      assert html =~ "Quoted Lead"
    end

    test "switches to the cards view", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote_request_fixture(scope, %{"customer_name" => "Card Person"})

      {:ok, lv, _html} = live(conn, ~p"/app/quotes")
      html = lv |> element("button[phx-value-view='cards']") |> render_click()
      assert html =~ "Card Person"
    end

    test "403s without quote:list", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = role_conn(conn, tenant, [])
      assert_error_sent 403, fn -> get(conn, ~p"/app/quotes") end
    end
  end

  describe "create" do
    test "captures a quote and lands on its detail page", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/app/quotes/new")

      lv
      |> form("#quote-form",
        quote_request: %{
          customer_name: "Marcus Webb",
          customer_email: "marcus@example.com",
          subject: "LHR to JFK",
          body: "Business class, October.",
          route: "LHR–JFK",
          total: "3290"
        }
      )
      |> render_submit()

      assert [quote] = Quotes.list_quote_requests(scope)
      assert quote.customer_name == "Marcus Webb"
      assert quote.status == :new
      assert_redirect(lv, ~p"/app/quotes/#{quote.id}")
    end

    test "403s without quote:create", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = role_conn(conn, tenant, ["quote:list"])
      assert_error_sent 403, fn -> get(conn, ~p"/app/quotes/new") end
    end
  end

  describe "detail — the gate" do
    test "shows the lead and trip facts", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quote_request_fixture(scope, %{"customer_name" => "Skyline", "route" => "CDG–FCO"})

      {:ok, _lv, html} = live(conn, ~p"/app/quotes/#{quote.id}")
      assert html =~ "Skyline"
      assert html =~ "CDG–FCO"
      assert html =~ "New"
    end

    test "generate → confirm & send moves the quote to quoted", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quote_request_fixture(scope, %{"customer_name" => "Rana Aziz"})
      {:ok, lv, _html} = live(conn, ~p"/app/quotes/#{quote.id}")

      # AI draft → in progress.
      html = lv |> element("button", "Generate with AI") |> render_click()
      assert html =~ "Hi Rana"
      assert html =~ "In progress"
      assert Quotes.get_quote_request(scope, quote.id).status == :in_progress

      # Confirm & send the draft → quoted, awaiting client.
      html = lv |> element("button", "Confirm & send") |> render_click()
      assert html =~ "Quoted"
      assert html =~ "Awaiting client"

      reloaded = Quotes.get_quote_request(scope, quote.id)
      assert reloaded.status == :quoted
      assert reloaded.awaiting == :client
    end

    test "logging a client acceptance resolves the quote", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quoted_quote_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/app/quotes/#{quote.id}")

      html =
        lv
        |> form("#client-reply", %{body: "Yes, book it!", disposition: "acceptance"})
        |> render_submit()

      assert html =~ "Accepted"
      assert Quotes.get_quote_request(scope, quote.id).status == :accepted
    end

    test "cancelling a lead", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quote_request_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/app/quotes/#{quote.id}")

      html = lv |> element("button", "Cancel") |> render_click()
      assert html =~ "Cancelled"
      assert Quotes.get_quote_request(scope, quote.id).status == :cancelled
    end

    test "a reader without quote:reply sees no composer", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      quote = quote_request_fixture(owner_scope_for(tenant))
      conn = role_conn(conn, tenant, ["quote:read"])

      {:ok, lv, _html} = live(conn, ~p"/app/quotes/#{quote.id}")
      refute has_element?(lv, "#composer")
      refute has_element?(lv, "#client-reply")
    end

    test "the detail page 403s without quote:read", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      quote = quote_request_fixture(owner_scope_for(tenant))
      conn = role_conn(conn, tenant, ["quote:list"])
      assert_error_sent 403, fn -> get(conn, ~p"/app/quotes/#{quote.id}") end
    end
  end
end
