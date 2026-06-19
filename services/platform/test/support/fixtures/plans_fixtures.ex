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
        price: 9900,
        interval: :monthly,
        active: true,
        limits: %{
          "quotes_per_month" => 100,
          "seats" => 10,
          "ai_generations_per_month" => 100,
          "custom_domain" => false
        }
      })

    {:ok, plan} = Plans.create_plan(attrs)
    plan
  end
end
