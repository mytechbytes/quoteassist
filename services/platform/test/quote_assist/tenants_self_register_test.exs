defmodule QuoteAssist.TenantsSelfRegisterTest do
  @moduledoc """
  Self-registration context (R5-selfreg): `register_self_service/1` and the helpers
  the onboarding flow leans on (`newest_owner_tenant/1`, `resend_onboarding/1`,
  `tenant_login_url/1`).
  """
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.{User, UserToken}
  alias QuoteAssist.Audit.Log
  alias QuoteAssist.Tenants

  setup do
    # The signup defaults to the seeded Starter plan; tests seed just that one.
    %{plan: plan_fixture(%{slug: "starter", name: "Starter"})}
  end

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "Skyline Travel",
        "slug" => "skyline",
        "owner_name" => "Rana Aziz",
        "owner_email" => "rana@skyline.test"
      },
      overrides
    )
  end

  describe "register_self_service/1" do
    test "creates a trial tenant on the Starter plan, marked self_signup", %{plan: plan} do
      assert {:ok, %{tenant: tenant}} = Tenants.register_self_service(valid_attrs())

      assert tenant.status == :trial
      assert tenant.source == :self_signup
      assert tenant.plan_id == plan.id
      assert %DateTime{} = tenant.trial_expires_at
      assert DateTime.diff(tenant.trial_expires_at, DateTime.utc_now(), :day) in 14..15
    end

    test "creates the owner user (with display name) + an owner membership" do
      assert {:ok, %{tenant: tenant, owner: owner}} = Tenants.register_self_service(valid_attrs())

      assert owner.email == "rana@skyline.test"
      assert owner.display_name == "Rana Aziz"
      assert is_nil(owner.hashed_password)
      assert is_nil(owner.confirmed_at)

      membership = Tenants.get_active_membership(tenant, owner)
      assert membership.type == :owner
    end

    test "seeds the built-in member roles for the new tenant" do
      {:ok, %{tenant: tenant}} = Tenants.register_self_service(valid_attrs())

      assert Tenants.get_role_by_slug(tenant, "manager")
      assert Tenants.get_role_by_slug(tenant, "agent")
    end

    test "reuses an existing user for the owner email (name untouched)" do
      existing = user_fixture(%{email: "rana@skyline.test"})

      {:ok, %{tenant: tenant, owner: owner}} = Tenants.register_self_service(valid_attrs())

      assert owner.id == existing.id
      assert Repo.aggregate(from(u in User, where: u.email == "rana@skyline.test"), :count) == 1
      assert Tenants.get_active_membership(tenant, existing)
    end

    test "emails a platform-host onboarding token to the owner" do
      {:ok, %{owner: owner}} = Tenants.register_self_service(valid_attrs())
      assert Repo.get_by(UserToken, user_id: owner.id, context: "onboarding")
    end

    test "writes a system audit row with the owner email masked", %{plan: _plan} do
      {:ok, %{tenant: tenant}} = Tenants.register_self_service(valid_attrs())

      log = Repo.one!(from l in Log, where: l.action == "tenant.self_registered")
      assert log.actor_type == :system
      assert is_nil(log.actor_id)
      assert log.tenant_id == tenant.id
      assert log.metadata["slug"] == "skyline"
      assert log.metadata["owner_email"] =~ "***"
      refute log.metadata["owner_email"] == "rana@skyline.test"
    end

    test "rejects a reserved slug" do
      assert {:error, changeset} =
               Tenants.register_self_service(valid_attrs(%{"slug" => "admin"}))

      assert "is reserved" in errors_on(changeset).slug
    end

    test "rejects a missing owner name + email" do
      assert {:error, changeset} =
               Tenants.register_self_service(%{"name" => "X", "slug" => "xy"})

      assert errors_on(changeset).owner_email != []
      assert errors_on(changeset).owner_name != []
    end

    test "rejects a duplicate slug and rolls the whole thing back" do
      {:ok, _} = Tenants.register_self_service(valid_attrs(%{"owner_email" => "a@skyline.test"}))

      assert {:error, changeset} =
               Tenants.register_self_service(valid_attrs(%{"owner_email" => "b@skyline.test"}))

      assert "has already been taken" in errors_on(changeset).slug
      # The second owner user was never created (rollback).
      assert Accounts.get_user_by_email("b@skyline.test") == nil
    end
  end

  describe "newest_owner_tenant/1 and tenant_login_url/1" do
    test "returns the owner's tenant and builds its subdomain login URL" do
      {:ok, %{tenant: tenant, owner: owner}} = Tenants.register_self_service(valid_attrs())

      assert Tenants.newest_owner_tenant(owner).id == tenant.id
      # Test env base domain is example.com, scheme http (config/test.exs).
      assert Tenants.tenant_login_url(tenant) == "http://skyline.example.com/login"
    end
  end

  describe "resend_onboarding/1" do
    test "re-issues a link for a not-yet-onboarded owner" do
      {:ok, %{owner: owner}} = Tenants.register_self_service(valid_attrs())

      assert Tenants.resend_onboarding(owner.email) == :ok

      count =
        Repo.aggregate(
          from(t in UserToken, where: t.user_id == ^owner.id and t.context == "onboarding"),
          :count
        )

      assert count == 2
    end

    test "is a no-op (but still :ok) for an unknown email" do
      assert Tenants.resend_onboarding("nobody@nowhere.test") == :ok
      assert Repo.aggregate(from(t in UserToken, where: t.context == "onboarding"), :count) == 0
    end

    test "does not re-issue for an already-onboarded owner" do
      {:ok, %{owner: owner}} = Tenants.register_self_service(valid_attrs())

      {:ok, _} =
        Accounts.complete_onboarding(owner, %{
          password: "a valid password 1",
          password_confirmation: "a valid password 1"
        })

      assert Tenants.resend_onboarding(owner.email) == :ok
      # complete_onboarding consumed the original token; resend issues none.
      assert Repo.aggregate(
               from(t in UserToken, where: t.user_id == ^owner.id and t.context == "onboarding"),
               :count
             ) == 0
    end
  end
end
