defmodule QuoteAssist.TenantsAdminTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures
  import QuoteAssist.PlansFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Accounts
  alias QuoteAssist.Accounts.{User, UserToken}
  alias QuoteAssist.Audit.Log
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.Tenant

  describe "create_tenant_with_owner/2" do
    setup do
      %{admin: admin_fixture(), plan: plan_fixture()}
    end

    test "creates the tenant on a 15-day trial with the chosen plan", %{admin: admin, plan: plan} do
      assert {:ok, tenant} =
               Tenants.create_tenant_with_owner(admin, %{
                 "name" => "Acme Travel",
                 "slug" => "acme",
                 "owner_email" => "owner@acme.test",
                 "plan_id" => plan.id
               })

      assert tenant.status == :trial
      assert tenant.plan_id == plan.id
      assert %DateTime{} = tenant.trial_expires_at
      assert DateTime.diff(tenant.trial_expires_at, DateTime.utc_now(), :day) in 14..15
    end

    test "creates the owner user + an owner membership", %{admin: admin, plan: plan} do
      {:ok, tenant} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "owner@acme.test"))

      user = Accounts.get_user_by_email("owner@acme.test")
      assert user
      membership = Tenants.get_active_membership(tenant, user)
      assert membership.type == :owner
    end

    test "reuses an existing user for the owner email", %{admin: admin, plan: plan} do
      existing = user_fixture(%{email: "reuse@acme.test"})

      {:ok, tenant} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "reuse@acme.test"))

      assert Tenants.get_active_membership(tenant, existing)

      assert Repo.aggregate(from(u in User, where: u.email == "reuse@acme.test"), :count) == 1
    end

    test "sends the owner a magic-link invite", %{admin: admin, plan: plan} do
      {:ok, _tenant} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "owner@acme.test"))

      owner = Accounts.get_user_by_email("owner@acme.test")
      assert Repo.get_by(UserToken, user_id: owner.id, context: "login")
    end

    test "writes an audit row (actor = admin, owner email masked)", %{admin: admin, plan: plan} do
      {:ok, tenant} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "owner@acme.test"))

      log = Repo.one!(from l in Log, where: l.action == "tenant.created")
      assert log.actor_type == :admin
      assert log.actor_id == admin.id
      assert log.tenant_id == tenant.id
      assert log.metadata["owner_email"] =~ "***"
      refute log.metadata["owner_email"] == "owner@acme.test"
    end

    test "rejects an invalid form (missing owner email + plan)", %{admin: admin} do
      assert {:error, changeset} =
               Tenants.create_tenant_with_owner(admin, %{"name" => "X", "slug" => "xy"})

      errors = errors_on(changeset)
      assert errors.owner_email != []
      assert errors.plan_id != []
    end

    test "rejects a duplicate slug and rolls back", %{admin: admin, plan: plan} do
      {:ok, _} = Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "a@acme.test", "dup"))

      assert {:error, changeset} =
               Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "b@acme.test", "dup"))

      assert "has already been taken" in errors_on(changeset).slug
      assert Repo.aggregate(from(t in Tenant, where: t.slug == "dup"), :count) == 1
    end
  end

  describe "update_tenant/3" do
    setup do
      admin = admin_fixture()
      plan = plan_fixture()

      {:ok, tenant} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "owner@acme.test"))

      %{admin: admin, tenant: tenant, plan2: plan_fixture()}
    end

    test "updates name + plan and audits", %{admin: admin, tenant: tenant, plan2: plan2} do
      assert {:ok, updated} =
               Tenants.update_tenant(admin, tenant, %{
                 "name" => "Acme Renamed",
                 "plan_id" => plan2.id
               })

      assert updated.name == "Acme Renamed"
      assert updated.plan_id == plan2.id
      assert Repo.one!(from l in Log, where: l.action == "tenant.updated").actor_id == admin.id
    end

    test "ignores slug + custom_domain (edit is locked to name + plan)", %{
      admin: admin,
      tenant: tenant,
      plan2: plan2
    } do
      assert {:ok, updated} =
               Tenants.update_tenant(admin, tenant, %{
                 "name" => "Renamed",
                 "plan_id" => plan2.id,
                 "slug" => "hacked",
                 "custom_domain" => "evil.test"
               })

      assert updated.name == "Renamed"
      assert updated.slug == tenant.slug
      refute updated.custom_domain == "evil.test"
    end
  end

  describe "soft_delete_tenant/2" do
    test "sets deleted_at, audits, and makes the tenant unresolvable" do
      admin = admin_fixture()
      plan = plan_fixture()

      {:ok, tenant} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "o@acme.test", "delme"))

      assert {:ok, deleted} = Tenants.soft_delete_tenant(admin, tenant)
      assert deleted.deleted_at
      refute Tenants.get_tenant_for_admin(tenant.id)
      assert Tenants.resolve_host("delme.example.com") == :not_found
      assert Repo.one!(from l in Log, where: l.action == "tenant.deleted").actor_type == :admin
    end
  end

  describe "trial expiry" do
    test "trial_expired?/1" do
      refute Tenants.trial_expired?(active_tenant_fixture(%{slug: "act"}))
      assert Tenants.trial_expired?(expired_trial_tenant_fixture(%{slug: "exp"}))

      future =
        %{slug: "fut"}
        |> tenant_fixture()
        |> Ecto.Changeset.change(
          trial_expires_at: DateTime.add(DateTime.utc_now(:second), 5, :day)
        )
        |> Repo.update!()

      refute Tenants.trial_expired?(future)
    end

    test "enforce_trial_expiry/1 suspends an expired trial (audited) and returns :expired" do
      tenant = expired_trial_tenant_fixture(%{slug: "exp2"})
      assert :expired = Tenants.enforce_trial_expiry(tenant)
      assert Repo.reload(tenant).status == :suspended

      log = Repo.one!(from l in Log, where: l.action == "tenant.status_changed")
      assert log.metadata == %{"from" => "trial", "to" => "suspended"}
      assert log.actor_type == :system
    end

    test "enforce_trial_expiry/1 is a no-op for a live trial" do
      tenant =
        %{slug: "live"}
        |> tenant_fixture()
        |> Ecto.Changeset.change(
          trial_expires_at: DateTime.add(DateTime.utc_now(:second), 5, :day)
        )
        |> Repo.update!()

      assert :ok = Tenants.enforce_trial_expiry(tenant)
      assert Repo.reload(tenant).status == :trial
    end
  end

  describe "list_tenants_for_admin/0 + owner_email/1" do
    test "excludes soft-deleted, preloads plan + members, and derives the owner email" do
      admin = admin_fixture()
      plan = plan_fixture()

      {:ok, _acme} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "owner@acme.test", "acme"))

      {:ok, gone} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "x@gone.test", "gone"))

      Tenants.soft_delete_tenant(admin, gone)

      tenants = Tenants.list_tenants_for_admin()
      slugs = Enum.map(tenants, & &1.slug)
      assert "acme" in slugs
      refute "gone" in slugs

      loaded = Enum.find(tenants, &(&1.slug == "acme"))
      assert loaded.plan.id == plan.id
      assert Tenants.owner_email(loaded) == "owner@acme.test"
    end
  end

  describe "list_tenants_for_plan/1 + tenant_count_by_plan/0" do
    test "scopes to live tenants on the given plan" do
      admin = admin_fixture()
      plan = plan_fixture()
      other_plan = plan_fixture()
      {:ok, _a} = Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "a@x.test", "aa"))
      {:ok, _b} = Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "b@x.test", "bb"))

      {:ok, _c} =
        Tenants.create_tenant_with_owner(admin, valid_attrs(other_plan, "c@x.test", "cc"))

      assert length(Tenants.list_tenants_for_plan(plan.id)) == 2

      counts = Tenants.tenant_count_by_plan()
      assert counts[plan.id] == 2
      assert counts[other_plan.id] == 1
    end

    test "excludes soft-deleted tenants" do
      admin = admin_fixture()
      plan = plan_fixture()
      {:ok, tenant} = Tenants.create_tenant_with_owner(admin, valid_attrs(plan, "o@x.test", "dd"))
      Tenants.soft_delete_tenant(admin, tenant)

      assert Tenants.list_tenants_for_plan(plan.id) == []
      assert Map.get(Tenants.tenant_count_by_plan(), plan.id, 0) == 0
    end
  end

  defp valid_attrs(plan, email, slug \\ "acme") do
    %{"name" => "Acme Travel", "slug" => slug, "owner_email" => email, "plan_id" => plan.id}
  end
end
