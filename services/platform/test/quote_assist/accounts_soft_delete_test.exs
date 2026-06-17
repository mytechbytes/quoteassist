defmodule QuoteAssist.Accounts.SoftDeleteTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.User

  defp soft_delete(user) do
    {:ok, user} =
      user
      |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
      |> Repo.update()

    user
  end

  test "get_user_by_email/1 ignores soft-deleted users" do
    user = user_fixture()
    assert Accounts.get_user_by_email(user.email)

    soft_delete(user)
    refute Accounts.get_user_by_email(user.email)
  end

  test "get_user_by_email_and_password/2 ignores soft-deleted users" do
    user = user_fixture() |> set_password()
    assert Accounts.get_user_by_email_and_password(user.email, valid_user_password())

    soft_delete(user)
    refute Accounts.get_user_by_email_and_password(user.email, valid_user_password())
  end

  test "a soft-deleted user's session token no longer resolves" do
    user = user_fixture()
    token = Accounts.generate_user_session_token(user)
    assert {%User{}, _} = Accounts.get_user_by_session_token(token)

    soft_delete(user)
    refute Accounts.get_user_by_session_token(token)
  end
end
