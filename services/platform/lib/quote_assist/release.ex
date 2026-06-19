defmodule QuoteAssist.Release do
  @moduledoc """
  Release tasks for a built release that has no Mix available. Invoked via the release
  binary — typically `docker compose exec quoteassist bin/quote_assist eval '...'`.

  Every task starts **only the repo** (via `Ecto.Migrator.with_repo/2`) and shuts it
  down afterwards; none of them boot the web endpoint. That makes them safe to run with
  `eval` inside a container whose app is already running — the task spins up a throwaway
  repo connection rather than a second full app instance (no port clash):

      bin/quote_assist eval "QuoteAssist.Release.migrate()"
      bin/quote_assist eval "QuoteAssist.Release.seed()"
      bin/quote_assist eval 'QuoteAssist.Release.create_admin("admin@example.com", "a-strong-passphrase")'
  """
  @app :quote_assist

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.Admin

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

  @doc """
  Runs `priv/repo/seeds.exs` against the release build. Plans and the built-in admin
  roles seed in every environment; dev/staging additionally seed the showcase tenants
  (the script gates that on `DEPLOY_ENV`). Starts only the repo, so it's safe to run
  alongside the live app.
  """
  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo -> run_seeds() end)
    end

    :ok
  end

  defp run_seeds do
    seeds = Path.join([:code.priv_dir(@app), "repo", "seeds.exs"])

    if File.exists?(seeds) do
      Code.eval_file(seeds)
      :ok
    else
      IO.puts("no seeds script found at #{seeds}")
    end
  end

  @doc """
  Create or reset a site **super_admin** — the only way to make a super_admin (no HTTP
  route, no seed). Idempotent: an existing live email has its password reset (its type
  is left untouched). Starts only the repo, so running it via `eval` inside the app
  container won't clash with the running instance. Raises on invalid input.
  """
  def create_admin(email, password) when is_binary(email) and is_binary(password) do
    load_app()
    [repo | _] = repos()
    {:ok, admin, _} = Ecto.Migrator.with_repo(repo, fn _repo -> upsert_admin(email, password) end)
    admin
  end

  defp upsert_admin(email, password) do
    case Accounts.get_admin_by_email(email) do
      nil ->
        case Accounts.register_admin(%{email: email, password: password}) do
          {:ok, admin} -> report(admin)
          {:error, changeset} -> raise "could not register admin: #{errors(changeset)}"
        end

      %Admin{} = admin ->
        case Accounts.update_admin_password(admin, %{password: password}) do
          {:ok, admin} -> report(admin)
          {:error, changeset} -> raise "invalid password: #{errors(changeset)}"
        end
    end
  end

  defp report(%Admin{} = admin) do
    IO.puts("super_admin ready: #{admin.email} (#{admin.type})")
    admin
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
