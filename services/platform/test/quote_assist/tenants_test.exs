defmodule QuoteAssist.TenantsTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures
  import QuoteAssist.TenantsFixtures

  alias QuoteAssist.Audit.Log
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.{Role, Tenant}

  describe "resolve_host/1 — platform hosts" do
    test "treats platform hosts as having no tenant" do
      for host <- ["example.com", "www.example.com", "localhost", "127.0.0.1"] do
        assert Tenants.resolve_host(host) == :platform
      end
    end

    test "is case-insensitive" do
      assert Tenants.resolve_host("WWW.Example.com") == :platform
    end
  end

  describe "resolve_host/1 — subdomains" do
    test "resolves a live, resolvable tenant by slug" do
      tenant = active_tenant_fixture(%{slug: "acme"})
      assert {:ok, resolved} = Tenants.resolve_host("acme.example.com")
      assert resolved.id == tenant.id
    end

    test "resolves a trial tenant (trial is resolvable)" do
      tenant = tenant_fixture(%{slug: "trialco"})
      assert tenant.status == :trial
      assert {:ok, resolved} = Tenants.resolve_host("trialco.example.com")
      assert resolved.id == tenant.id
    end

    test "404s an unknown subdomain" do
      assert Tenants.resolve_host("nope.example.com") == :not_found
    end

    test "resolves a suspended tenant to {:suspended, tenant} (403, not 404)" do
      suspended = tenant_with_status_fixture(:suspended, %{slug: "susp"})
      assert {:suspended, resolved} = Tenants.resolve_host("susp.example.com")
      assert resolved.id == suspended.id
    end

    test "404s a cancelled tenant" do
      tenant_with_status_fixture(:cancelled, %{slug: "gone"})
      assert Tenants.resolve_host("gone.example.com") == :not_found
    end

    test "404s a soft-deleted tenant" do
      tenant = active_tenant_fixture(%{slug: "deleted"})
      soft_delete!(tenant)
      assert Tenants.resolve_host("deleted.example.com") == :not_found
    end
  end

  describe "resolve_host/1 — custom domains" do
    test "resolves a verified custom domain" do
      tenant =
        active_tenant_fixture(%{slug: "withcd"})
        |> put_custom_domain!("quotes.acme.test", :verified)

      assert {:ok, resolved} = Tenants.resolve_host("quotes.acme.test")
      assert resolved.id == tenant.id
    end

    test "404s an unverified (pending) custom domain" do
      active_tenant_fixture(%{slug: "pendingcd"})
      |> put_custom_domain!("pending.acme.test", :pending)

      assert Tenants.resolve_host("pending.acme.test") == :not_found
    end

    test "resolves a suspended tenant's verified custom domain to {:suspended, tenant}" do
      suspended =
        tenant_with_status_fixture(:suspended, %{slug: "suspcd"})
        |> put_custom_domain!("quotes.susp.test", :verified)

      assert {:suspended, resolved} = Tenants.resolve_host("quotes.susp.test")
      assert resolved.id == suspended.id
    end

    test "404s an unknown host" do
      assert Tenants.resolve_host("random.example.org") == :not_found
    end
  end

  describe "directory + lookups" do
    test "list_live_tenants/0 returns live tenants ordered by name" do
      _b = tenant_fixture(%{name: "Beta", slug: "beta"})
      _a = tenant_fixture(%{name: "Alpha", slug: "alpha"})
      deleted = tenant_fixture(%{name: "Zeta", slug: "zeta"})
      soft_delete!(deleted)

      assert ["Alpha", "Beta"] == Enum.map(Tenants.list_live_tenants(), & &1.name)
    end

    test "fetch_live_tenant/1 returns resolvable tenants, nil otherwise" do
      tenant = active_tenant_fixture(%{slug: "fetchme"})
      assert %Tenant{} = Tenants.fetch_live_tenant(tenant.id)

      assert Tenants.fetch_live_tenant(nil) == nil
      assert Tenants.fetch_live_tenant(Ecto.UUID.generate()) == nil

      suspended = tenant_with_status_fixture(:suspended, %{slug: "fetchsusp"})
      assert Tenants.fetch_live_tenant(suspended.id) == nil
    end

    test "get_tenant_by_slug/1 ignores soft-deleted tenants" do
      tenant = tenant_fixture(%{slug: "byslug"})
      assert Tenants.get_tenant_by_slug("byslug").id == tenant.id

      soft_delete!(tenant)
      assert Tenants.get_tenant_by_slug("byslug") == nil
    end
  end

  describe "create_tenant/1 validations" do
    test "requires a name and slug" do
      assert {:error, changeset} = Tenants.create_tenant(%{})
      assert %{name: ["can't be blank"], slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an invalid slug format" do
      assert {:error, changeset} = Tenants.create_tenant(%{name: "X", slug: "has spaces"})
      assert errors_on(changeset).slug != []
    end

    test "rejects reserved slugs" do
      assert {:error, changeset} = Tenants.create_tenant(%{name: "X", slug: "www"})
      assert "is reserved" in errors_on(changeset).slug
    end

    test "normalizes slug and custom domain (trim + downcase)" do
      {:ok, tenant} =
        Tenants.create_tenant(%{name: "X", slug: "  AcMe  ", custom_domain: " Quotes.ACME.test "})

      assert tenant.slug == "acme"
      assert tenant.custom_domain == "quotes.acme.test"
    end

    test "enforces unique live slug" do
      tenant_fixture(%{slug: "dup"})
      assert {:error, changeset} = Tenants.create_tenant(%{name: "Other", slug: "dup"})
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "blanks a whitespace-only custom domain to nil" do
      assert {:ok, tenant} =
               Tenants.create_tenant(%{name: "X", slug: "blankcd", custom_domain: "   "})

      assert tenant.custom_domain == nil
    end
  end

  describe "transition_status/3 (state machine + audit)" do
    test "applies a legal transition and writes an audit row" do
      tenant = tenant_fixture(%{slug: "fsm1"})
      assert {:ok, updated} = Tenants.transition_status(tenant, :active, :system)
      assert updated.status == :active

      log = Repo.one!(from l in Log, where: l.action == "tenant.status_changed")
      assert log.actor_type == :system
      assert log.actor_id == nil
      assert log.tenant_id == tenant.id
      assert log.metadata == %{"from" => "trial", "to" => "active"}
    end

    test "records a user actor when given one" do
      tenant = tenant_fixture(%{slug: "fsm2"})
      user = user_fixture()

      assert {:ok, _} = Tenants.transition_status(tenant, :suspended, user)
      log = Repo.one!(from l in Log, where: l.action == "tenant.status_changed")
      assert log.actor_type == :user
      assert log.actor_id == user.id
    end

    test "rejects an illegal transition and writes no audit row" do
      # active_tenant_fixture already wrote one trial→active row; assert the rejected
      # transition adds none (the transaction rolls back).
      tenant = active_tenant_fixture(%{slug: "fsm3"})

      count = fn ->
        Repo.aggregate(from(l in Log, where: l.action == "tenant.status_changed"), :count)
      end

      before = count.()

      assert {:error, changeset} = Tenants.transition_status(tenant, :trial, :system)
      assert "cannot transition from active to trial" in errors_on(changeset).status
      assert count.() == before
    end

    test "can_transition?/2 graph (cancelled is terminal)" do
      assert Tenant.can_transition?(:trial, :active)
      assert Tenant.can_transition?(:suspended, :active)
      refute Tenant.can_transition?(:active, :trial)
      refute Tenant.can_transition?(:cancelled, :active)
    end

    test "statuses/0 lists the valid statuses" do
      assert Tenant.statuses() == [:trial, :active, :suspended, :cancelled]
    end
  end

  describe "roles" do
    test "seed_default_roles/1 seeds the two built-in member roles, idempotently" do
      tenant = tenant_fixture(%{slug: "roles1"})
      first = Tenants.seed_default_roles(tenant)
      assert length(first) == 2

      # Re-running does not duplicate.
      Tenants.seed_default_roles(tenant)
      assert Repo.aggregate(from(r in Role, where: r.tenant_id == ^tenant.id), :count) == 2
    end

    test "manager runs the desk; agent is quote-focused; both builtin (owner is a type, not a role)" do
      tenant = tenant_fixture(%{slug: "roles2"})
      manager = Tenants.get_role_by_slug(tenant, "manager")
      agent = Tenants.get_role_by_slug(tenant, "agent")

      assert manager.builtin
      assert agent.builtin
      # owner is a protected membership type, never a seeded role.
      assert Tenants.get_role_by_slug(tenant, "owner") == nil

      assert "quote:delete" in manager.permissions
      assert "user:create" in manager.permissions
      refute "quote:delete" in agent.permissions
      refute "user:create" in agent.permissions
    end

    test "create_role/2 rejects unknown permission keys" do
      tenant = tenant_fixture(%{slug: "roles3"})

      assert {:error, changeset} =
               Tenants.create_role(tenant, %{name: "Bad", slug: "bad", permissions: ["nope:fake"]})

      assert errors_on(changeset).permissions != []
    end

    test "create_role/2 rejects the self:* baseline (not role-composable)" do
      tenant = tenant_fixture(%{slug: "roles3a"})

      assert {:error, changeset} =
               Tenants.create_role(tenant, %{
                 name: "Selfy",
                 slug: "selfy",
                 permissions: ["self:read"]
               })

      assert errors_on(changeset).permissions != []
    end

    test "create_role/2 accepts catalog keys" do
      tenant = tenant_fixture(%{slug: "roles4"})

      assert {:ok, role} =
               Tenants.create_role(tenant, %{
                 name: "Custom",
                 slug: "custom",
                 permissions: ["quote:list"]
               })

      assert role.permissions == ["quote:list"]
    end
  end

  describe "memberships" do
    test "create_membership/3 + get_active_membership/2 (role preloaded)" do
      tenant = tenant_fixture(%{slug: "mem1"})
      user = user_fixture()
      role = Tenants.get_role_by_slug(tenant, "agent")

      assert {:ok, _membership} = Tenants.create_membership(tenant, user, role)

      membership = Tenants.get_active_membership(tenant, user)
      assert membership.role.slug == "agent"
    end

    test "get_active_membership/2 ignores soft-deleted memberships" do
      tenant = tenant_fixture(%{slug: "mem2"})
      {user, membership} = member_fixture(tenant, "owner")

      soft_delete!(membership)
      assert Tenants.get_active_membership(tenant, user) == nil
    end

    test "get_active_membership/2 returns nil for a non-member" do
      tenant = tenant_fixture(%{slug: "mem3"})
      assert Tenants.get_active_membership(tenant, user_fixture()) == nil
    end

    test "create_membership/3 creates a :member with a role; create_owner_membership/2 a roleless :owner" do
      tenant = tenant_fixture(%{slug: "mem4"})
      role = Tenants.get_role_by_slug(tenant, "agent")

      {:ok, member} = Tenants.create_membership(tenant, user_fixture(), role)
      assert member.type == :member
      assert member.role_id == role.id
      assert member.active

      {:ok, owner} = Tenants.create_owner_membership(tenant, user_fixture())
      assert owner.type == :owner
      assert owner.role_id == nil
    end

    test "active_owner_count/1 counts live, active owners only" do
      tenant = tenant_fixture(%{slug: "mem5"})
      assert Tenants.active_owner_count(tenant) == 0

      {_user, _owner} = member_fixture(tenant, "owner")
      member_fixture(tenant, "agent")
      assert Tenants.active_owner_count(tenant) == 1
    end
  end

  # Soft-delete any schema row with a deleted_at column.
  defp soft_delete!(record) do
    record
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update!()
  end
end
