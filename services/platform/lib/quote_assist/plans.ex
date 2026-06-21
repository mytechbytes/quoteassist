defmodule QuoteAssist.Plans do
  @moduledoc """
  The subscription plan catalog. Plans are platform-level (not tenant-scoped): the
  admin picks one when creating a tenant, and `tenant.plan_id` references it. Seeded
  with Starter / Growth / Scale via `seed_plans/0` (idempotent, called from
  `priv/repo/seeds.exs`).
  """
  import Ecto.Query

  alias QuoteAssist.Accounts.Admin
  alias QuoteAssist.Audit
  alias QuoteAssist.Plans.Plan
  alias QuoteAssist.Repo

  # Seeded set — "seed exactly three" with ascending limits (RELEASE_PLAN.md). Prices
  # are in the smallest currency unit (paise); 0 = free. `limits` are the entitlement
  # dimensions read by future enforcement.
  @default_plans [
    %{
      slug: "starter",
      name: "Starter",
      price: 0,
      interval: :monthly,
      active: true,
      limits: %{
        "quotes_per_month" => 50,
        "seats" => 3,
        "ai_generations_per_month" => 50,
        "custom_domain" => false
      }
    },
    %{
      slug: "growth",
      name: "Growth",
      price: 149_900,
      interval: :monthly,
      active: true,
      limits: %{
        "quotes_per_month" => 500,
        "seats" => 10,
        "ai_generations_per_month" => 500,
        "custom_domain" => true
      }
    },
    %{
      slug: "scale",
      name: "Scale",
      price: 499_900,
      interval: :monthly,
      active: true,
      limits: %{
        "quotes_per_month" => 5000,
        "seats" => 50,
        "ai_generations_per_month" => 5000,
        "custom_domain" => true
      }
    }
  ]

  @doc "Live plans, ordered by price then name."
  def list_plans do
    Repo.all(
      from p in Plan,
        where: is_nil(p.deleted_at),
        order_by: [asc: p.price, asc: p.name]
    )
  end

  @doc """
  Live, **active** plans (offerable to new tenants), ordered by price — the public
  pricing shown on the marketing home page. Admin CRUD over `plans` flows straight
  through here, so editing/deactivating a plan updates the landing.
  """
  def list_active_plans do
    Repo.all(
      from p in Plan,
        where: is_nil(p.deleted_at) and p.active == true,
        order_by: [asc: p.price, asc: p.name]
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

  @doc "The built-in plan specs (Starter / Growth / Scale)."
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
