defmodule QuoteAssist.Repo.Migrations.EnableExtensions do
  use Ecto.Migration

  @moduledoc """
  R0 · Postgres extensions the platform relies on.

    * `citext`   — case-insensitive text (e.g. emails) for later releases.
    * `vector`   — pgvector, for RAG embeddings on the same instance (later).
    * `pgcrypto` — gen_random_uuid() available DB-side if ever needed.

  Requires the `pgvector/pgvector:pg16` image (the `vector` extension ships there).
  """

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"
    execute "CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector"
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", "DROP EXTENSION IF EXISTS pgcrypto"
  end
end
