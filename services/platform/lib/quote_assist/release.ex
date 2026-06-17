defmodule QuoteAssist.Release do
  @moduledoc """
  Release tasks for running Ecto migrations on a production build that has no
  Mix available. Invoked from the deploy pipeline via:

      bin/quote_assist eval "QuoteAssist.Release.migrate()"
  """
  @app :quote_assist

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
