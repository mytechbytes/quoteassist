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
    test "creates a `new` lead with a per-tenant reference, stamped + audited", %{scope: scope} do
      assert {:ok, q} = Quotes.create_quote_request(scope, valid_quote_attrs())
      assert q.status == :new
      assert q.submitted_by == scope.membership.id
      assert q.reference == "QA-1001"

      assert {:ok, q2} = Quotes.create_quote_request(scope, valid_quote_attrs())
      assert q2.reference == "QA-1002"

      actions = "quote_request" |> Audit.list_for_target(q.id) |> Enum.map(& &1.action)
      assert "quote.created" in actions
    end

    test "rejects invalid input", %{scope: scope} do
      assert {:error, changeset} = Quotes.create_quote_request(scope, %{"customer_name" => ""})
      assert %{customer_email: _, subject: _, body: _} = errors_on(changeset)
    end
  end

  describe "list / isolation / filter" do
    test "only returns the scope's tenant's live quotes", %{scope: scope} do
      mine = quote_request_fixture(scope)
      %{scope: other} = owner_scope_fixture(%{slug: "beta"})
      _theirs = quote_request_fixture(other)

      assert Enum.map(Quotes.list_quote_requests(scope), & &1.id) == [mine.id]
    end

    test "filters by status and search; excludes soft-deleted", %{scope: scope} do
      open = quote_request_fixture(scope, %{"customer_name" => "Paris Honeymoon"})
      gone = quote_request_fixture(scope)
      {:ok, _} = Quotes.soft_delete_quote_request(scope, gone)

      assert [%{id: id}] = Quotes.list_quote_requests(scope, status: :new)
      assert id == open.id
      assert [%{id: ^id}] = Quotes.list_quote_requests(scope, query: "honeymoon")
      assert Quotes.get_quote_request(scope, gone.id) == nil
    end
  end

  describe "status workflow" do
    test "cancel is reachable from any active state; terminals don't transition", %{scope: scope} do
      quote = quote_request_fixture(scope)
      assert {:ok, cancelled} = Quotes.transition_status(scope, quote, :cancelled)
      assert cancelled.status == :cancelled
      assert {:error, _} = Quotes.transition_status(scope, cancelled, :in_progress)
    end

    test "a new lead can't jump straight to accepted", %{scope: scope} do
      quote = quote_request_fixture(scope)
      assert {:error, changeset} = Quotes.transition_status(scope, quote, :accepted)
      assert %{status: [_]} = errors_on(changeset)
    end
  end

  describe "message gate" do
    test "generating an AI draft adds a draft and moves new → in_progress", %{scope: scope} do
      quote = quote_request_fixture(scope)
      assert {:ok, msg} = Quotes.generate_ai_reply(scope, quote)
      assert msg.author_type == :ai
      assert msg.status == :draft
      assert is_nil(msg.sent_by)
      assert Quotes.get_quote_request(scope, quote.id).status == :in_progress
    end

    test "confirm then send delivers the draft and moves the quote to quoted", %{scope: scope} do
      quote = quote_request_fixture(scope)
      {:ok, draft} = Quotes.compose_draft(scope, quote, "Here's your quote.")
      assert draft.author_type == :human
      assert draft.authored_by == scope.membership.id

      assert {:ok, confirmed} = Quotes.confirm_message(scope, draft)
      assert confirmed.status == :confirmed

      assert {:ok, sent} = Quotes.send_message(scope, confirmed)
      assert sent.status == :sent
      assert sent.sent_by == scope.membership.id

      reloaded = Quotes.get_quote_request(scope, quote.id)
      assert reloaded.status == :quoted
      assert reloaded.awaiting == :client
      assert reloaded.valid_until
    end

    test "editing a draft marks it human-edited and keeps it a draft", %{scope: scope} do
      quote = quote_request_fixture(scope)
      {:ok, draft} = Quotes.generate_ai_reply(scope, quote)
      assert {:ok, edited} = Quotes.edit_draft(scope, draft, "Tweaked by a human.")
      assert edited.edited_by_human
      assert edited.status == :draft
    end

    test "a sent message can't be sent again", %{scope: scope} do
      quote = quote_request_fixture(scope)
      {:ok, draft} = Quotes.compose_draft(scope, quote, "Quote.")
      {:ok, sent} = Quotes.send_message(scope, draft)
      assert {:error, :not_sendable} = Quotes.send_message(scope, sent)
    end
  end

  describe "client replies + disposition" do
    test "a question keeps the quote quoted and flips the ball to us", %{scope: scope} do
      quoted = quoted_quote_fixture(scope)
      assert {:ok, msg} = Quotes.receive_client_reply(scope, quoted, "One question…", :question)
      assert msg.author_type == :client
      assert msg.status == :received
      assert msg.disposition == :question

      reloaded = Quotes.get_quote_request(scope, quoted.id)
      assert reloaded.status == :quoted
      assert reloaded.awaiting == :us
    end

    test "acceptance resolves the quote to accepted", %{scope: scope} do
      quoted = quoted_quote_fixture(scope)
      assert {:ok, _} = Quotes.receive_client_reply(scope, quoted, "Yes please!", :acceptance)
      assert Quotes.get_quote_request(scope, quoted.id).status == :accepted
    end

    test "rejection resolves the quote to rejected", %{scope: scope} do
      quoted = quoted_quote_fixture(scope)
      assert {:ok, _} = Quotes.receive_client_reply(scope, quoted, "No thanks.", :rejection)
      assert Quotes.get_quote_request(scope, quoted.id).status == :rejected
    end

    test "the thread carries the loop", %{scope: scope} do
      quoted = quoted_quote_fixture(scope)

      {:ok, _} =
        Quotes.receive_client_reply(scope, quoted, "Can you change the hotel?", :change_request)

      {:ok, draft} = Quotes.compose_draft(scope, quoted, "Revised quote attached.")
      {:ok, _} = Quotes.send_message(scope, draft)

      # original sent + client received + revised sent (counts, not sub-second order)
      messages = Quotes.list_messages(scope, quoted)
      assert Enum.frequencies_by(messages, & &1.status) == %{sent: 2, received: 1}
    end
  end

  describe "dashboard_stats/1" do
    test "counts open (new/in_progress), quoted this month, and total", %{scope: scope} do
      quote_request_fixture(scope)
      quoted_quote_fixture(scope)
      assert %{open: 1, quoted_this_month: 1, total: 2} = Quotes.dashboard_stats(scope)
    end
  end

  test "list_messages preloads authors", %{scope: scope} do
    quote = quote_request_fixture(scope)
    {:ok, _} = Quotes.compose_draft(scope, quote, "Hi.")
    assert [%QuoteMessage{authored_by_membership: %{}}] = Quotes.list_messages(scope, quote)
  end
end
