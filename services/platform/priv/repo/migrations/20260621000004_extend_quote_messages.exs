defmodule QuoteAssist.Repo.Migrations.ExtendQuoteMessages do
  use Ecto.Migration

  # The message track gains the human-in-the-loop gate + provenance + disposition:
  #   * status      — draft → confirmed → sent (outbound) · received (inbound)
  #   * authored_by — the human who wrote it (renamed from author_id; null for ai/client)
  #   * sent_by     — the human who confirmed & sent it (null until sent)
  #   * edited_by_human — was an AI draft touched before sending
  #   * disposition — client reply intent (question|change_request|acceptance|rejection|other)
  # `author_type` also gains the `client` value (app-level enum; column stays a string).
  def change do
    rename table(:quote_messages), :author_id, to: :authored_by

    alter table(:quote_messages) do
      add :status, :string, null: false, default: "draft"
      add :sent_by, references(:memberships, type: :binary_id, on_delete: :nilify_all)
      add :edited_by_human, :boolean, null: false, default: false
      add :disposition, :string
    end

    # Any pre-existing messages were historical sends — mark them sent by their author.
    execute(
      "UPDATE quote_messages SET status = 'sent', sent_by = authored_by WHERE status = 'draft'",
      ""
    )

    create index(:quote_messages, [:quote_request_id, :status])
  end
end
