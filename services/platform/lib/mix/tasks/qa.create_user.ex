defmodule Mix.Tasks.Qa.CreateUser do
  @shortdoc "Creates/updates a confirmed tenant user with a password (dev/staging only)"

  @moduledoc """
  Creates a confirmed tenant `User` with a password so you can sign in during
  development. R1 has no registration UI (that lands in R4) and R2 is what seeds
  the real dev tenant + user — this task fills the gap without touching
  `priv/repo/seeds.exs`.

  Dev/staging convenience only: no HTTP surface, mirroring the planned
  `mix qa.create_admin` (R3). It refuses to run when the deploy environment is
  production.

      mix qa.create_user --email dev@example.com --password "change-me-please"

  If the email already exists (and is live), its password is reset and the
  account is confirmed — the task is idempotent. The password must be at least
  12 characters (per the User password changeset).
  """

  use Mix.Task

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.User
  alias QuoteAssist.Repo

  @switches [email: :string, password: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: @switches)

    email = opts[:email] || Mix.raise("--email is required")
    password = opts[:password] || Mix.raise("--password is required (min 12 characters)")

    Mix.Task.run("app.start")
    ensure_not_production!()

    user =
      email
      |> find_or_register()
      |> set_password(password)
      |> confirm()

    Mix.shell().info("user ready: #{user.email} (confirmed_at: #{user.confirmed_at})")
  end

  defp ensure_not_production! do
    deploy_env = Application.get_env(:quote_assist, :deploy_env, "dev")

    if Mix.env() == :prod or deploy_env in ["prod", "production"] do
      Mix.raise("qa.create_user is disabled in production (deploy_env=#{deploy_env})")
    end
  end

  defp find_or_register(email) do
    case Accounts.get_user_by_email(email) do
      nil ->
        case Accounts.register_user(%{email: email}) do
          {:ok, user} -> user
          {:error, changeset} -> Mix.raise("could not register user: #{errors(changeset)}")
        end

      %User{} = user ->
        user
    end
  end

  defp set_password(user, password) do
    case user |> User.password_changeset(%{password: password}) |> Repo.update() do
      {:ok, user} -> user
      {:error, changeset} -> Mix.raise("invalid password: #{errors(changeset)}")
    end
  end

  defp confirm(user) do
    {:ok, user} = user |> User.confirm_changeset() |> Repo.update()
    user
  end

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
