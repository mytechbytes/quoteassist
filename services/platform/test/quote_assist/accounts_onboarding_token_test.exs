defmodule QuoteAssist.AccountsOnboardingTokenTest do
  @moduledoc """
  The platform-host owner onboarding token mechanics (R5-selfreg): issuing the 7-day
  link, exchanging it for the user, and completing onboarding (password + email
  confirmation in one transaction, single-use token).
  """
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.{User, UserToken}

  describe "register_owner/1" do
    test "creates an unconfirmed, password-less user with a display name" do
      assert {:ok, %User{} = user} =
               Accounts.register_owner(%{email: "owner@acme.test", display_name: "Rana Aziz"})

      assert user.email == "owner@acme.test"
      assert user.display_name == "Rana Aziz"
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
    end

    test "requires a display name" do
      assert {:error, changeset} = Accounts.register_owner(%{email: "owner@acme.test"})
      assert %{display_name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "onboarding tokens" do
    setup do
      %{user: unconfirmed_user_fixture(%{email: "owner@acme.test"})}
    end

    test "deliver_onboarding_instructions/2 stores an onboarding token and emails the link",
         %{user: user} do
      token =
        extract_user_token(fn url -> Accounts.deliver_onboarding_instructions(user, url) end)

      assert is_binary(token)
      assert Repo.get_by(UserToken, user_id: user.id, context: "onboarding")
    end

    test "get_user_by_onboarding_token/1 returns the user for a valid token", %{user: user} do
      {encoded, user_token} = UserToken.build_email_token(user, "onboarding")
      Repo.insert!(user_token)

      assert %User{id: id} = Accounts.get_user_by_onboarding_token(encoded)
      assert id == user.id
    end

    test "returns nil for an unknown token" do
      assert Accounts.get_user_by_onboarding_token("not-a-real-token") == nil
    end

    test "returns nil once the token has expired (older than 7 days)", %{user: user} do
      {encoded, user_token} = UserToken.build_email_token(user, "onboarding")
      inserted = Repo.insert!(user_token)

      Repo.update_all(
        from(t in UserToken, where: t.id == ^inserted.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(:second), -8, :day)]
      )

      assert Accounts.get_user_by_onboarding_token(encoded) == nil
    end
  end

  describe "complete_onboarding/2" do
    setup do
      %{user: unconfirmed_user_fixture(%{email: "owner@acme.test"})}
    end

    test "sets the password and confirms the email in one update", %{user: user} do
      assert {:ok, %User{} = updated} =
               Accounts.complete_onboarding(user, %{
                 password: "a valid password 1",
                 password_confirmation: "a valid password 1"
               })

      assert updated.confirmed_at
      assert Accounts.get_user_by_email_and_password(user.email, "a valid password 1")
    end

    test "consumes every token for the user (single-use link)", %{user: user} do
      {encoded, user_token} = UserToken.build_email_token(user, "onboarding")
      Repo.insert!(user_token)

      {:ok, _user} =
        Accounts.complete_onboarding(user, %{
          password: "a valid password 1",
          password_confirmation: "a valid password 1"
        })

      assert Accounts.get_user_by_onboarding_token(encoded) == nil
      assert Repo.all(from t in UserToken, where: t.user_id == ^user.id) == []
    end

    test "rejects a too-short password", %{user: user} do
      assert {:error, changeset} =
               Accounts.complete_onboarding(user, %{
                 password: "short",
                 password_confirmation: "short"
               })

      assert %{password: ["should be at least 12 character(s)"]} = errors_on(changeset)
      refute Accounts.get_user!(user.id).confirmed_at
    end

    test "rejects a mismatched confirmation", %{user: user} do
      assert {:error, changeset} =
               Accounts.complete_onboarding(user, %{
                 password: "a valid password 1",
                 password_confirmation: "different password 2"
               })

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end
  end
end
