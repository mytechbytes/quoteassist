defmodule QuoteAssist.AccountsOnboardingTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.User

  describe "onboard_user/2" do
    test "sets display name + password" do
      user = unconfirmed_user_fixture()
      refute user.hashed_password

      assert {:ok, updated} =
               Accounts.onboard_user(user, %{
                 display_name: "Rana Aziz",
                 password: "a valid password 1",
                 password_confirmation: "a valid password 1"
               })

      assert updated.display_name == "Rana Aziz"
      assert User.valid_password?(updated, "a valid password 1")
    end

    test "requires a display name" do
      user = unconfirmed_user_fixture()
      assert {:error, changeset} = Accounts.onboard_user(user, %{password: "a valid password 1"})
      assert "can't be blank" in errors_on(changeset).display_name
    end

    test "rejects a short password" do
      user = unconfirmed_user_fixture()

      assert {:error, changeset} =
               Accounts.onboard_user(user, %{display_name: "X", password: "short"})

      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "rejects a mismatched confirmation" do
      user = unconfirmed_user_fixture()

      assert {:error, changeset} =
               Accounts.onboard_user(user, %{
                 display_name: "X",
                 password: "a valid password 1",
                 password_confirmation: "different"
               })

      assert "does not match password" in errors_on(changeset).password_confirmation
    end
  end

  describe "change_user_onboarding/2" do
    test "does not hash during validation (hash_password: false default)" do
      user = unconfirmed_user_fixture()

      changeset =
        Accounts.change_user_onboarding(user, %{display_name: "X", password: "a valid password 1"})

      assert Ecto.Changeset.get_change(changeset, :password) == "a valid password 1"
      refute Ecto.Changeset.get_change(changeset, :hashed_password)
    end
  end
end
