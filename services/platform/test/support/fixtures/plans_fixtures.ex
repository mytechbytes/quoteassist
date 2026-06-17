defmodule QuoteAssist.PlansFixtures do
  @moduledoc """
  Test helpers for creating plans via the `QuoteAssist.Plans` context.
  """

  alias QuoteAssist.Plans

  def plan_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        name: "Plan #{System.unique_integer([:positive])}",
        slug: "plan#{System.unique_integer([:positive])}",
        monthly_price: 99,
        seat_limit: 10
      })

    {:ok, plan} = Plans.create_plan(attrs)
    plan
  end
end
