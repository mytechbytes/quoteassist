defmodule QuoteAssist.PlansTest do
  use QuoteAssist.DataCase, async: true

  alias QuoteAssist.Plans
  alias QuoteAssist.Plans.Plan

  describe "seed_plans/0" do
    test "seeds Starter + Growth, idempotently" do
      first = Plans.seed_plans()
      assert length(first) == 2
      assert first |> Enum.map(& &1.slug) |> Enum.sort() == ["growth", "starter"]

      Plans.seed_plans()
      assert Repo.aggregate(Plan, :count) == 2
    end
  end

  describe "list_plans/0 + lookups" do
    setup do
      Plans.seed_plans()
      :ok
    end

    test "lists live plans ordered by price (Starter before Growth)" do
      names = Plans.list_plans() |> Enum.map(& &1.name)
      assert "Starter" in names
      assert "Growth" in names

      assert Enum.find_index(names, &(&1 == "Starter")) <
               Enum.find_index(names, &(&1 == "Growth"))
    end

    test "get_plan!/1 + get_plan_by_slug/1" do
      starter = Plans.get_plan_by_slug("starter")
      assert starter.slug == "starter"
      assert Plans.get_plan!(starter.id).id == starter.id
      assert is_nil(Plans.get_plan_by_slug("nope"))
    end

    test "soft-deleted plans are excluded" do
      starter = Plans.get_plan_by_slug("starter")
      starter |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second)) |> Repo.update!()
      refute Plans.get_plan_by_slug("starter")
      refute Enum.any?(Plans.list_plans(), &(&1.slug == "starter"))
    end
  end

  describe "create_plan/1" do
    test "rejects a negative price" do
      assert {:error, changeset} = Plans.create_plan(%{name: "X", slug: "x", monthly_price: -1})
      assert errors_on(changeset).monthly_price != []
    end

    test "enforces a unique slug among live plans" do
      Plans.seed_plans()
      assert {:error, changeset} = Plans.create_plan(%{name: "Dup", slug: "starter"})
      assert "has already been taken" in errors_on(changeset).slug
    end
  end
end
