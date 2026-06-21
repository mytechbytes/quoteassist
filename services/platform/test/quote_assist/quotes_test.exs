defmodule QuoteAssist.QuotesTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.QuotesFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Audit
  alias QuoteAssist.Quotes
  alias QuoteAssist.Quotes.QuoteMessage

  setup do
    %{scope: scope} = owner_scope_fixture(%{slug: "acme"})
    %{scope: scope}
  end

  describe "create_quote_request/2" do
    test "creates a tenant-scoped, audited lead stamped with the member", %{scope: scope} do
      assert {:ok, quote} = Quotes.create_quote_request(scope, valid_quote_attrs())
      assert quote.tenant_id == scope.tenant.id
      assert quote.submitted_by == scope.membership.id
      assert quote.status == :open

      actions = "quote_request" |> Audit.list_for_target(quote.id) |> Enum.map(& &1.action)
      assert "quote.created" in actions
    end

    test "rejects invalid input", %{scope: scope} do
      assert {:error, changeset} = Quotes.create_quote_request(scope, %{"customer_name" => ""})
      assert %{customer_email: _, subject: _, body: _} = errors_on(changeset)
    end
  end

  describe "list_quote_requests/2 + tenant isolation" do
    test "only returns the scope's tenant's live quotes", %{scope: scope} do
      mine = quote_request_fixture(scope)
      %{scope: other} = owner_scope_fixture(%{slug: "beta"})
      _theirs = quote_request_fixture(other)

      ids = scope |> Quotes.list_quote_requests() |> Enum.map(& &1.id)
      assert ids == [mine.id]
    end

    test "filters by status and search", %{scope: scope} do
      open = quote_request_fixture(scope, %{"subject" => "Paris honeymoon"})
      other = quote_request_fixture(scope, %{"subject" => "Tokyo business"})
      {:ok, _} = Quotes.transition_status(scope, other, :closed)

      assert [%{id: id}] = Quotes.list_quote_requests(scope, status: :open)
      assert id == open.id

      assert [%{id: found}] = Quotes.list_quote_requests(scope, query: "honeymoon")
      assert found == open.id
    end

    test "excludes soft-deleted quotes", %{scope: scope} do
      quote = quote_request_fixture(scope)
      {:ok, _} = Quotes.soft_delete_quote_request(scope, quote)
      assert Quotes.list_quote_requests(scope) == []
      assert Quotes.get_quote_request(scope, quote.id) == nil
    end
  end

  describe "transition_status/3" do
    test "applies a legal transition and audits it", %{scope: scope} do
      quote = quote_request_fixture(scope)
      assert {:ok, updated} = Quotes.transition_status(scope, quote, :in_progress)
      assert updated.status == :in_progress

      actions = "quote_request" |> Audit.list_for_target(quote.id) |> Enum.map(& &1.action)
      assert "quote.status_changed" in actions
    end

    test "rejects an illegal jump", %{scope: scope} do
      quote = quote_request_fixture(scope)
      {:ok, quoted} = Quotes.transition_status(scope, quote, :quoted)
      assert {:error, changeset} = Quotes.transition_status(scope, quoted, :open)
      assert %{status: ["cannot transition from quoted to open"]} = errors_on(changeset)
    end

    test "to-do is reachable only via in_progress (no direct jump back)", %{scope: scope} do
      quote = quote_request_fixture(scope)
      {:ok, in_progress} = Quotes.transition_status(scope, quote, :in_progress)
      {:ok, quoted} = Quotes.transition_status(scope, in_progress, :quoted)

      # A quoted lead can't jump straight back to to-do…
      assert {:error, _} = Quotes.transition_status(scope, quoted, :open)
      {:ok, closed} = Quotes.transition_status(scope, quoted, :closed)
      # …nor can a closed one; reopening lands in in_progress, not to-do.
      assert {:error, _} = Quotes.transition_status(scope, closed, :open)
      assert {:ok, reopened} = Quotes.transition_status(scope, closed, :in_progress)
      assert reopened.status == :in_progress

      # From in_progress (start) you *can* move back to to-do.
      assert {:ok, todo} = Quotes.transition_status(scope, reopened, :open)
      assert todo.status == :open
    end
  end

  describe "dashboard_stats/1" do
    test "counts open leads and leads quoted this month", %{scope: scope} do
      quote_request_fixture(scope)
      to_quote = quote_request_fixture(scope)
      {:ok, _} = Quotes.transition_status(scope, to_quote, :quoted)

      assert %{open: 1, quoted_this_month: 1} = Quotes.dashboard_stats(scope)
    end
  end

  describe "replies + AI hook (R12)" do
    test "generate_ai_reply returns a draft and does not persist a message", %{scope: scope} do
      quote = quote_request_fixture(scope)
      assert {:ok, draft} = Quotes.generate_ai_reply(scope, quote)
      assert is_binary(draft) and draft =~ "Customer"
      assert Quotes.list_messages(scope, quote) == []
    end

    test "send_reply appends a human message and advances to quoted", %{scope: scope} do
      quote = quote_request_fixture(scope)
      assert {:ok, message} = Quotes.send_reply(scope, quote, "Here's your quote.")
      assert message.author_type == :human
      assert message.author_id == scope.membership.id

      assert [%QuoteMessage{}] = Quotes.list_messages(scope, quote)
      assert Quotes.get_quote_request(scope, quote.id).status == :quoted
    end

    test "sending a reply on a closed lead doesn't change its status", %{scope: scope} do
      quote = quote_request_fixture(scope)
      {:ok, closed} = Quotes.transition_status(scope, quote, :closed)

      assert {:ok, _message} = Quotes.send_reply(scope, closed, "A late note.")
      assert Quotes.get_quote_request(scope, quote.id).status == :closed
    end
  end
end
