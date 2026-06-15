defmodule QuoteAssist.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  @moduledoc """
  R0 · Postgres extensions the platform relies on.

    * `citext`   — case-insensitive text (e.g. emails).
    * `pgcrypto` — gen_random_uuid() available DB-side if ever needed.
    * `vector`   — pgvector, for RAG embeddings (used from the AI/RAG release).

  QuoteAssist runs on its own `pgvector/pgvector:pg18` database, so `vector` is
  enabled up front.
  """

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", "DROP EXTENSION IF EXISTS pgcrypto"
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"
  end
end
