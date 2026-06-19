defmodule QuoteAssistWeb.Admin.Components do
  @moduledoc """
  Small presentational helpers shared across the admin console LiveViews (status
  badges, plan name, trial date, admin type/role badges). Pure functions of admin /
  tenant data, plus a template-friendly `can?/2` permission check.
  """
  use Phoenix.Component

  alias QuoteAssist.Accounts.Admin
  alias QuoteAssist.Authz.AdminPolicy

  @doc """
  Whether `admin` holds `permission` — a template-friendly delegate to
  `QuoteAssist.Authz.AdminPolicy.can?/2`, so views render only the actions the signed-in
  admin is allowed (a super_admin sees all; computed all-access).
  """
  def can?(admin, permission), do: AdminPolicy.can?(admin, permission)

  @doc "A badge for an admin's protected type (super_admin stands out)."
  attr :type, :atom, required: true

  def admin_type_badge(assigns) do
    ~H"""
    <span class={[
      "mtb-badge",
      if(@type == :super_admin, do: "mtb-badge-warning", else: "mtb-badge-neutral")
    ]}>
      {Admin.type_label(@type)}
    </span>
    """
  end

  @doc "A badge for an admin's active / inactive state."
  attr :active, :boolean, required: true

  def admin_active_badge(assigns) do
    ~H"""
    <span class={[
      "mtb-badge",
      if(@active, do: "mtb-badge-success", else: "mtb-badge-neutral")
    ]}>
      {if @active, do: "Active", else: "Inactive"}
    </span>
    """
  end

  @doc "An admin's role name, or an em dash (super_admins carry no role)."
  def admin_role_label(%{type: :super_admin}), do: "—"
  def admin_role_label(%{role: %{name: name}}), do: name
  def admin_role_label(_admin), do: "—"

  @doc "A status pill for a tenant status, using the design-system badge colours."
  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={["mtb-badge", status_class(@status)]}>{status_label(@status)}</span>
    """
  end

  @doc "The `mtb-badge-*` modifier for a tenant status."
  def status_class(:active), do: "mtb-badge-success"
  def status_class(:trial), do: "mtb-badge-warning"
  def status_class(:suspended), do: "mtb-badge-error"
  def status_class(:cancelled), do: "mtb-badge-neutral"
  def status_class(_status), do: "mtb-badge-neutral"

  @doc "Human label for a tenant status."
  def status_label(status), do: status |> to_string() |> String.capitalize()

  @doc "Plan name for a tenant (with `:plan` preloaded), or an em dash."
  def plan_name(%{plan: %{name: name}}), do: name
  def plan_name(_tenant), do: "—"

  @doc "Formatted trial-expiry date for a tenant, or an em dash."
  def trial_label(%{trial_expires_at: %DateTime{} = expires_at}) do
    Calendar.strftime(expires_at, "%d %b %Y")
  end

  def trial_label(_tenant), do: "—"

  @doc "A vertical timeline of audit-log rows (newest first). Shared by detail pages."
  attr :logs, :list, required: true
  attr :empty, :string, default: "No activity yet."

  def audit_timeline(assigns) do
    ~H"""
    <p :if={@logs == []} class="text-sm" style="color:var(--mc-text-3)">{@empty}</p>
    <ol :if={@logs != []} class="mtb-feed">
      <li :for={log <- @logs} class="relative pb-4 last:pb-0">
        <span class="mtb-feed-dot">
          <span class="block size-1.5 rounded-full" style="background:var(--mc-brand)"></span>
        </span>
        <div class="text-sm font-medium" style="color:var(--mc-text)">{action_label(log.action)}</div>
        <div class="text-xs" style="color:var(--mc-text-3)">
          {actor_label(log.actor_type)} ·
          <span class="font-mono">{format_datetime(log.inserted_at)}</span>
        </div>
      </li>
    </ol>
    """
  end

  @doc "Humanises an audit action key for display (tenant.status_changed -> Tenant status changed)."
  def action_label(action) when is_binary(action) do
    action |> String.replace(~r/[._]/, " ") |> String.capitalize()
  end

  def action_label(_action), do: "—"

  @doc "Human label for an audit actor type."
  def actor_label(:admin), do: "Admin"
  def actor_label(:user), do: "User"
  def actor_label(:system), do: "System"
  def actor_label(_actor), do: "—"

  @doc "Formats a datetime for display, or an em dash."
  def format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y, %H:%M")
  def format_datetime(_value), do: "—"
end
