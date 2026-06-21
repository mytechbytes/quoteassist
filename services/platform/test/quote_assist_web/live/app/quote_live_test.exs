defmodule QuoteAssistWeb.App.QuoteLiveTest do
  use QuoteAssistWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QuoteAssist.AccountsFixtures
  import QuoteAssist.QuotesFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Quotes
  alias QuoteAssist.Tenants

  # An owner conn for tenant "acme", plus an owner scope on it (used to seed quotes).
  defp owner_conn(conn) do
    %{tenant: tenant, user: user, scope: scope} = owner_scope_fixture(%{slug: "acme"})
    %{conn: log_in_member(conn, user, tenant), tenant: tenant, scope: scope}
  end

  # A conn for a member with exactly `permissions` on `tenant`.
  defp role_conn(conn, tenant, permissions) do
    role = role_fixture(tenant, %{permissions: permissions})
    user = user_fixture()
    {:ok, _m} = Tenants.create_membership(tenant, user, role)
    log_in_member(conn, user, tenant)
  end

  # An owner scope for an existing tenant, so a quote can be seeded in it.
  defp owner_scope_for(tenant) do
    {user, membership} = member_fixture(tenant, "owner")
    scope_fixture(tenant, user, membership)
  end

  describe "index" do
    test "lists quotes and shows the New button for an owner", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote_request_fixture(scope, %{"customer_name" => "The Bennetts"})

      {:ok, lv, html} = live(conn, ~p"/app/quotes")
      assert html =~ "Quote requests"
      assert html =~ "The Bennetts"
      assert has_element?(lv, "#new-quote")
    end

    test "filters by status", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote_request_fixture(scope, %{"customer_name" => "Stays Open"})
      closed = quote_request_fixture(scope, %{"customer_name" => "Gets Closed"})
      {:ok, _} = Quotes.transition_status(scope, closed, :closed)

      {:ok, lv, _html} = live(conn, ~p"/app/quotes")
      html = lv |> form("form[phx-change=filter]", %{status: "open"}) |> render_change()

      assert html =~ "Stays Open"
      refute html =~ "Gets Closed"
    end

    test "403s without quote:list", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = role_conn(conn, tenant, [])
      assert_error_sent 403, fn -> get(conn, ~p"/app/quotes") end
    end
  end

  describe "create" do
    test "creates a quote and lands on its detail page", %{conn: conn} do
      %{conn: conn, tenant: tenant, scope: scope} = owner_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/app/quotes/new")

      lv
      |> form("#quote-form",
        quote_request: %{
          customer_name: "Marcus Webb",
          customer_email: "marcus@example.com",
          subject: "LHR to JFK",
          body: "Business class, October."
        }
      )
      |> render_submit()

      assert [quote] = Quotes.list_quote_requests(scope)
      assert quote.customer_name == "Marcus Webb"
      assert quote.tenant_id == tenant.id
      assert_redirect(lv, ~p"/app/quotes/#{quote.id}")
    end

    test "the create page 403s without quote:create", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      conn = role_conn(conn, tenant, ["quote:list"])
      assert_error_sent 403, fn -> get(conn, ~p"/app/quotes/new") end
    end
  end

  describe "detail" do
    test "shows the lead and moves its status", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quote_request_fixture(scope, %{"subject" => "Skiing in March"})

      {:ok, lv, html} = live(conn, ~p"/app/quotes/#{quote.id}")
      assert html =~ "Skiing in March"
      assert html =~ "Open"

      html = lv |> element("button", "Start") |> render_click()
      assert html =~ "In progress"
      assert Quotes.get_quote_request(scope, quote.id).status == :in_progress
    end

    test "generating a draft fills the composer, then sending posts a reply", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quote_request_fixture(scope, %{"customer_name" => "Rana Aziz"})
      {:ok, lv, _html} = live(conn, ~p"/app/quotes/#{quote.id}")

      html = lv |> element("button", "Generate with AI") |> render_click()
      assert html =~ "Hi Rana"

      html =
        lv
        |> form("form[phx-submit=send]", reply: %{body: "Here is your quote, thanks!"})
        |> render_submit()

      assert html =~ "Here is your quote, thanks!"
      assert html =~ "Quoted"
      assert Quotes.get_quote_request(scope, quote.id).status == :quoted
    end

    test "reopening a closed lead moves it to in progress, not to-do", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quote_request_fixture(scope)
      {:ok, _} = Quotes.transition_status(scope, quote, :closed)

      {:ok, lv, html} = live(conn, ~p"/app/quotes/#{quote.id}")
      assert html =~ "Closed"

      html = lv |> element("button", "Reopen") |> render_click()
      assert html =~ "In progress"
      assert Quotes.get_quote_request(scope, quote.id).status == :in_progress
    end

    test "deleting removes the quote and returns to the list", %{conn: conn} do
      %{conn: conn, scope: scope} = owner_conn(conn)
      quote = quote_request_fixture(scope)
      {:ok, lv, _html} = live(conn, ~p"/app/quotes/#{quote.id}")

      lv |> element("button", "Delete") |> render_click()
      assert_redirect(lv, ~p"/app/quotes")
      assert Quotes.get_quote_request(scope, quote.id) == nil
    end

    test "a reader without quote:reply sees no composer", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      quote = quote_request_fixture(owner_scope_for(tenant))

      conn = role_conn(conn, tenant, ["quote:read"])
      {:ok, _lv, html} = live(conn, ~p"/app/quotes/#{quote.id}")
      refute html =~ "Send reply"
    end

    test "the detail page 403s without quote:read", %{conn: conn} do
      tenant = active_tenant_fixture(%{slug: "acme"})
      quote = quote_request_fixture(owner_scope_for(tenant))
      conn = role_conn(conn, tenant, ["quote:list"])
      assert_error_sent 403, fn -> get(conn, ~p"/app/quotes/#{quote.id}") end
    end
  end
end
