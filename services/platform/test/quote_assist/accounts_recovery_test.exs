defmodule QuoteAssist.AccountsRecoveryTest do
  @moduledoc "Context-level tests for the R9-recovery token mechanics."
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.{User, UserToken}
  alias QuoteAssist.Repo

  describe "deliver_user_reset_password_instructions/2" do
    test "inserts a reset_password token and emails the link" do
      user = user_fixture()

      token =
        extract_user_token(fn url_fun ->
          Accounts.deliver_user_reset_password_instructions(user, url_fun)
        end)

      assert is_binary(token)
      assert %UserToken{sent_to: sent_to} = Repo.get_by(UserToken, context: "reset_password")
      assert sent_to == user.email
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url_fun ->
          Accounts.deliver_user_reset_password_instructions(user, url_fun)
        end)

      %{user: user, token: token}
    end

    test "returns the user for a valid token", %{user: user, token: token} do
      assert %User{id: id} = Accounts.get_user_by_reset_password_token(token)
      assert id == user.id
    end

    test "returns nil for a garbage token" do
      refute Accounts.get_user_by_reset_password_token("not-a-real-token")
    end

    test "returns nil once the token has expired", %{token: token} do
      # Push the token past its 60-minute window.
      offset_user_token(reset_token_hash(token), -61, :minute)
      refute Accounts.get_user_by_reset_password_token(token)
    end
  end

  describe "reset_user_password/2" do
    test "sets a new password and revokes all sessions (single-use)" do
      user = set_password(user_fixture())
      session = Accounts.generate_user_session_token(user)

      token =
        extract_user_token(fn url_fun ->
          Accounts.deliver_user_reset_password_instructions(user, url_fun)
        end)

      assert {:ok, _user} =
               Accounts.reset_user_password(user, %{
                 password: "a brand new password",
                 password_confirmation: "a brand new password"
               })

      # New password works, sessions are gone, and the reset token is consumed.
      assert Accounts.get_user_by_email_and_password(user.email, "a brand new password")
      assert Accounts.get_user_by_session_token(session) == nil
      refute Accounts.get_user_by_reset_password_token(token)
    end

    test "rejects a too-short password" do
      user = user_fixture()
      assert {:error, changeset} = Accounts.reset_user_password(user, %{password: "short"})
      assert %{password: ["should be at least 12 character(s)"]} = errors_on(changeset)
    end
  end

  describe "deliver_user_update_email_instructions/3 (R9 alert)" do
    test "confirms to the new address and alerts the old one" do
      user = set_password(user_fixture())
      applied = %{user | email: "new-address@example.com"}

      # Drop the login email the fixture sent so only the two change emails remain.
      flush_emails()

      {:ok, _confirm} =
        Accounts.deliver_user_update_email_instructions(
          applied,
          user.email,
          fn token -> "https://example.com/account/confirm-email/#{token}" end
        )

      # The change token is issued for (sent to) the NEW address.
      assert Repo.get_by(UserToken,
               sent_to: "new-address@example.com",
               context: "change:#{user.email}"
             )

      # Two emails go out (order-independent): a confirm link to the new address and an
      # alert to the old one. The Swoosh test adapter messages the calling process.
      assert_received {:email, email_a}
      assert_received {:email, email_b}
      emails = [email_a, email_b]

      recipients = Enum.map(emails, fn e -> e.to |> hd() |> elem(1) end)
      assert "new-address@example.com" in recipients
      assert user.email in recipients

      alert = Enum.find(emails, fn e -> e.subject =~ "email is being changed" end)
      assert alert
      assert alert.to |> hd() |> elem(1) == user.email
    end
  end

  # The reset token row stores the SHA-256 of the decoded token; `offset_user_token/3`
  # keys on the stored binary, so hash the emailed token the same way.
  defp reset_token_hash(token) do
    {:ok, decoded} = Base.url_decode64(token, padding: false)
    :crypto.hash(:sha256, decoded)
  end

  # Drain any `{:email, _}` messages the Swoosh test adapter has queued to this process.
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end
end
