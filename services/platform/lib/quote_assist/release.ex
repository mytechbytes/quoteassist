defmodule QuoteAssist.Release do
  @moduledoc """
  Release tasks for a production build that has no Mix available. Invoked from the
  deploy pipeline via the release binary:

      bin/quote_assist eval "QuoteAssist.Release.migrate()"
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
  Create or reset a site administrator — the only way to make an admin (no HTTP
  route, seed, or env-var path). Idempotent: an existing live email has its
  password reset. Raises on invalid input.
  """
  def create_admin(email, password) when is_binary(email) and is_binary(password) do
    ensure_started()

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
    IO.puts("admin ready: #{admin.email} (last_sign_in_at: #{admin.last_sign_in_at})")
    admin
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp ensure_started do
    Application.load(@app)
    {:ok, _} = Application.ensure_all_started(@app)
    :ok
  end

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
