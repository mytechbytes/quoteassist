defmodule Mix.Tasks.Qa.CreateAdmin do
  @shortdoc "Creates/updates a site administrator with a password (all environments)"

  @moduledoc """
  Creates a **super_admin** site administrator — the protected root type
  (RELEASE_PLAN.md, R4-retrofit). This is the only way to mint a super_admin; there is
  no HTTP route, seed, or env-var path, and the console can only create scoped, normal
  admins. Credentials exist only as a bcrypt hash in the `admins` table.

  Unlike `qa.create_user` (dev/staging only), this runs in EVERY environment,
  including production, so the first super_admin can be bootstrapped on a fresh deploy
  and the "≥1 active super_admin" invariant holds from the start.

      mix qa.create_admin --email admin@example.com --password "a-strong-passphrase"

  Idempotent: if the email already exists (and is live), its password is reset (its
  type is left untouched). The password must be at least 12 characters.
  """

  use Mix.Task

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.Admin

  @switches [email: :string, password: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} = OptionParser.parse(args, strict: @switches)

    email = opts[:email] || Mix.raise("--email is required")
    password = opts[:password] || Mix.raise("--password is required (min 12 characters)")

    Mix.Task.run("app.start")

    admin = find_or_register(email, password)

    Mix.shell().info(
      "admin ready: #{admin.email} (#{admin.type}, last_sign_in_at: #{admin.last_sign_in_at})"
    )
  end

  defp find_or_register(email, password) do
    case Accounts.get_admin_by_email(email) do
      nil ->
        case Accounts.register_admin(%{email: email, password: password}) do
          {:ok, admin} -> admin
          {:error, changeset} -> Mix.raise("could not register admin: #{errors(changeset)}")
        end

      %Admin{} = admin ->
        case Accounts.update_admin_password(admin, %{password: password}) do
          {:ok, admin} -> admin
          {:error, changeset} -> Mix.raise("invalid password: #{errors(changeset)}")
        end
    end
  end

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
