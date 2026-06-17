defmodule QuoteAssist.Plans do
  @moduledoc """
  The subscription plan catalog. Plans are platform-level (not tenant-scoped): the
  admin picks one when creating a tenant, and `tenant.plan_id` references it. Seeded
  with Starter + Growth via `seed_plans/0` (idempotent, called from
  `priv/repo/seeds.exs`).
  """
  import Ecto.Query

  alias QuoteAssist.Accounts.Admin
  alias QuoteAssist.Audit
  alias QuoteAssist.Plans.Plan
  alias QuoteAssist.Repo

  # Seeded set — "seed two" per the release plan. Prices are monthly, in whole
  # currency units; seat_limit is informational for now (enforced when team
  # management lands in R5).
  @default_plans [
    %{slug: "starter", name: "Starter", monthly_price: 49, seat_limit: 5},
    %{slug: "growth", name: "Growth", monthly_price: 149, seat_limit: 25}
  ]

  @doc "Live plans, ordered by price then name."
  def list_plans do
    Repo.all(
      from p in Plan,
        where: is_nil(p.deleted_at),
        order_by: [asc: p.monthly_price, asc: p.name]
    )
  end

  @doc "Fetches a live plan by id, raising if missing."
  def get_plan!(id) do
    Repo.one!(from p in Plan, where: p.id == ^id and is_nil(p.deleted_at))
  end

  @doc "Fetches a live plan by slug, or nil."
  def get_plan_by_slug(slug) do
    Repo.one(from p in Plan, where: p.slug == ^slug and is_nil(p.deleted_at))
  end

  @doc "Fetches a live plan by id, or nil. Safe for untrusted ids (bad UUID -> nil)."
  def get_plan(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.one(from p in Plan, where: p.id == ^uuid and is_nil(p.deleted_at))
      :error -> nil
    end
  end

  @doc "Creates a plan."
  def create_plan(attrs) do
    %Plan{} |> Plan.changeset(attrs) |> Repo.insert()
  end

  @doc "Changeset backing the admin plan create/edit form."
  def change_plan(plan \\ %Plan{}, attrs \\ %{}) do
    Plan.changeset(plan, attrs)
  end

  @doc "Admin-creates a plan (audited, actor = admin)."
  def admin_create_plan(%Admin{} = admin, attrs) do
    Repo.transact(fn ->
      with {:ok, plan} <- create_plan(attrs) do
        log_plan(admin, plan, "plan.created")
        {:ok, plan}
      end
    end)
  end

  @doc "Changeset backing the admin plan edit form (slug immutable)."
  def change_plan_update(%Plan{} = plan, attrs \\ %{}) do
    Plan.update_changeset(plan, attrs)
  end

  @doc "Admin-edits a plan (audited, actor = admin)."
  def admin_update_plan(%Admin{} = admin, %Plan{} = plan, attrs) do
    Repo.transact(fn ->
      with {:ok, updated} <- plan |> Plan.update_changeset(attrs) |> Repo.update() do
        log_plan(admin, updated, "plan.updated")
        {:ok, updated}
      end
    end)
  end

  @doc "The built-in plan specs (Starter + Growth)."
  def default_plan_specs, do: @default_plans

  @doc "Seeds the built-in plans, idempotently (skips existing slugs). Returns them."
  def seed_plans do
    for spec <- @default_plans do
      case get_plan_by_slug(spec.slug) do
        nil ->
          {:ok, plan} = create_plan(spec)
          plan

        %Plan{} = plan ->
          plan
      end
    end
  end

  defp log_plan(admin, plan, action) do
    Audit.log!(%{
      actor_type: :admin,
      actor_id: admin.id,
      tenant_id: nil,
      action: action,
      target_type: "plan",
      target_id: plan.id,
      metadata: %{"slug" => plan.slug}
    })
  end
end
