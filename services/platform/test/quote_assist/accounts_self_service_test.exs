defmodule QuoteAssist.AccountsSelfServiceTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts

  describe "profile" do
    test "update_user_profile/2 sets name, avatar, and timezone" do
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.update_user_profile(user, %{
                 "display_name" => "Rana Aziz",
                 "avatar_url" => "https://img/x.png",
                 "timezone" => "Europe/London"
               })

      assert updated.display_name == "Rana Aziz"
      assert updated.avatar_url == "https://img/x.png"
      assert updated.timezone == "Europe/London"
    end

    test "requires a display name" do
      user = user_fixture()
      assert {:error, changeset} = Accounts.update_user_profile(user, %{"display_name" => ""})
      assert errors_on(changeset).display_name != []
    end

    test "change_user_profile/2 returns a changeset" do
      assert %Ecto.Changeset{} = Accounts.change_user_profile(user_fixture())
    end
  end

  describe "password verification" do
    test "valid_user_password?/2 matches the current password" do
      user = set_password(user_fixture())
      assert Accounts.valid_user_password?(user, valid_user_password())
      refute Accounts.valid_user_password?(user, "wrong wrong wrong")
      refute Accounts.valid_user_password?(nil, "x")
    end
  end

  describe "sessions" do
    test "lists, identifies the current, and revokes own sessions" do
      user = user_fixture()
      a = Accounts.generate_user_session_token(user)
      b = Accounts.generate_user_session_token(user)

      sessions = Accounts.list_user_sessions(user)
      assert length(sessions) == 2

      current_id = Accounts.session_token_id(a)
      assert current_id in Enum.map(sessions, & &1.id)
      assert Accounts.session_token_id("nope") == nil
      assert Accounts.session_token_id(nil) == nil

      other = Enum.find(sessions, &(&1.id != current_id))
      assert {:ok, _} = Accounts.revoke_user_session(user, other.id)
      assert length(Accounts.list_user_sessions(user)) == 1
      # `a` still resolves (we revoked `b`).
      assert {%{id: id}, _} = Accounts.get_user_by_session_token(a)
      assert id == user.id
      assert Accounts.get_user_by_session_token(b) == nil
    end

    test "revoking is scoped to the owner and id-safe" do
      user = user_fixture()
      other = user_fixture()
      token = Accounts.generate_user_session_token(other)
      other_id = Accounts.session_token_id(token)

      assert Accounts.get_user_session(user, other_id) == nil
      assert Accounts.revoke_user_session(user, other_id) == {:error, :not_found}
      assert Accounts.revoke_user_session(user, "not-a-uuid") == {:error, :not_found}
    end
  end
end
