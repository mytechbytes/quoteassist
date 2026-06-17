defmodule QuoteAssist.PlansAdminTest do
  use QuoteAssist.DataCase, async: true

  import QuoteAssist.AccountsFixtures
  import QuoteAssist.PlansFixtures

  alias QuoteAssist.Audit.Log
  alias QuoteAssist.Plans

  describe "admin_create_plan/2" do
    test "creates a plan and audits it" do
      admin = admin_fixture()

      assert {:ok, plan} =
               Plans.admin_create_plan(admin, %{
                 name: "Pro",
                 slug: "pro",
                 monthly_price: 99,
                 seat_limit: 20
               })

      assert plan.slug == "pro"
      log = Repo.one!(from l in Log, where: l.action == "plan.created")
      assert log.actor_type == :admin
      assert log.actor_id == admin.id
    end

    test "rolls back + audits nothing on an invalid plan" do
      admin = admin_fixture()

      assert {:error, _changeset} =
               Plans.admin_create_plan(admin, %{name: "X", monthly_price: -1})

      assert Repo.aggregate(from(l in Log, where: l.action == "plan.created"), :count) == 0
    end
  end

  describe "admin_update_plan/3" do
    test "updates name + price but never the slug" do
      admin = admin_fixture()
      plan = plan_fixture(%{name: "Growth", slug: "growth"})

      assert {:ok, updated} =
               Plans.admin_update_plan(admin, plan, %{
                 "name" => "Growth Plus",
                 "monthly_price" => 199,
                 "slug" => "hacked"
               })

      assert updated.name == "Growth Plus"
      assert updated.monthly_price == 199
      assert updated.slug == "growth"
      assert Repo.one!(from l in Log, where: l.action == "plan.updated").actor_id == admin.id
    end
  end

  describe "get_plan/1" do
    test "returns nil for a malformed or unknown id" do
      assert Plans.get_plan("not-a-uuid") == nil
      assert Plans.get_plan(Ecto.UUID.generate()) == nil
    end

    test "returns a live plan by id" do
      plan = plan_fixture()
      assert Plans.get_plan(plan.id).id == plan.id
    end
  end
end
