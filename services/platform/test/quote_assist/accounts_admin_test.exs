defmodule QuoteAssist.AccountsAdminTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.Admin

  describe "register_admin/1" do
    test "creates an admin with a hashed password" do
      email = unique_admin_email()

      assert {:ok, admin} =
               Accounts.register_admin(%{email: email, password: valid_admin_password()})

      assert admin.email == email
      assert is_binary(admin.hashed_password)
      refute admin.hashed_password == valid_admin_password()
      assert is_nil(admin.password)
    end

    test "requires email and password" do
      assert {:error, changeset} = Accounts.register_admin(%{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors.email
      assert "can't be blank" in errors.password
    end

    test "rejects a short password" do
      assert {:error, changeset} =
               Accounts.register_admin(%{email: unique_admin_email(), password: "short"})

      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "rejects a malformed email" do
      assert {:error, changeset} =
               Accounts.register_admin(%{email: "nope", password: valid_admin_password()})

      assert errors_on(changeset).email != []
    end

    test "enforces a unique email (case-insensitive)" do
      admin = admin_fixture()

      assert {:error, changeset} =
               Accounts.register_admin(%{
                 email: String.upcase(admin.email),
                 password: valid_admin_password()
               })

      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "get_admin_by_email_and_password/2" do
    setup do
      %{admin: admin_fixture()}
    end

    test "returns the admin with a correct password", %{admin: admin} do
      assert %Admin{id: id} =
               Accounts.get_admin_by_email_and_password(admin.email, valid_admin_password())

      assert id == admin.id
    end

    test "returns nil with a wrong password", %{admin: admin} do
      refute Accounts.get_admin_by_email_and_password(admin.email, "wrong-password-here")
    end

    test "returns nil for an unknown email" do
      refute Accounts.get_admin_by_email_and_password(
               "nobody@example.com",
               valid_admin_password()
             )
    end
  end

  describe "soft delete" do
    test "a soft-deleted admin cannot be fetched or authenticate" do
      admin = admin_fixture()
      admin |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second)) |> Repo.update!()

      refute Accounts.get_admin_by_email(admin.email)
      refute Accounts.get_admin_by_email_and_password(admin.email, valid_admin_password())
    end
  end

  describe "update_admin_password/2 + update_admin_last_sign_in/1" do
    test "resets the password" do
      admin = admin_fixture()

      assert {:ok, updated} =
               Accounts.update_admin_password(admin, %{password: "a different pass 123"})

      assert Admin.valid_password?(updated, "a different pass 123")
    end

    test "stamps last_sign_in_at" do
      admin = admin_fixture()
      assert is_nil(admin.last_sign_in_at)
      assert {:ok, updated} = Accounts.update_admin_last_sign_in(admin)
      assert %DateTime{} = updated.last_sign_in_at
    end
  end

  describe "session tokens" do
    setup do
      %{admin: admin_fixture()}
    end

    test "generate + get round-trips the admin", %{admin: admin} do
      token = Accounts.generate_admin_session_token(admin)
      assert %Admin{id: id} = Accounts.get_admin_by_session_token(token)
      assert id == admin.id
    end

    test "delete invalidates the token", %{admin: admin} do
      token = Accounts.generate_admin_session_token(admin)
      assert :ok = Accounts.delete_admin_session_token(token)
      refute Accounts.get_admin_by_session_token(token)
    end

    test "a soft-deleted admin's token no longer resolves", %{admin: admin} do
      token = Accounts.generate_admin_session_token(admin)
      admin |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second)) |> Repo.update!()
      refute Accounts.get_admin_by_session_token(token)
    end
  end

  describe "list_admins/0 + get_admin/1" do
    test "lists live admins ordered by email" do
      admin_fixture(%{email: "b@example.com"})
      admin_fixture(%{email: "a@example.com"})
      emails = Accounts.list_admins() |> Enum.map(& &1.email)

      assert Enum.find_index(emails, &(&1 == "a@example.com")) <
               Enum.find_index(emails, &(&1 == "b@example.com"))
    end

    test "get_admin/1 returns nil for a malformed or unknown id" do
      assert Accounts.get_admin("not-a-uuid") == nil
      assert Accounts.get_admin(Ecto.UUID.generate()) == nil
    end

    test "get_admin/1 returns a live admin by id" do
      admin = admin_fixture()
      assert Accounts.get_admin(admin.id).id == admin.id
    end
  end
end
