defmodule QuoteAssistWeb.App.Components do
  @moduledoc """
  Small presentational helpers shared across the tenant workspace LiveViews (R7-rbac):
  a template-friendly `can?/2` permission check and membership/role/status badges.
  Pure functions of scope + tenant data — the mirror of `QuoteAssistWeb.Admin.Components`.
  """
  use Phoenix.Component

  alias QuoteAssist.Authz.Policy
  alias QuoteAssist.Tenants.{Membership, Request}

  @doc """
  Whether `scope` holds `permission` — a template-friendly delegate to
  `QuoteAssist.Authz.Policy.can?/2`, so views render only the actions the signed-in
  member is allowed (an owner sees all; computed all-access).
  """
  def can?(scope, permission), do: Policy.can?(scope, permission)

  @doc "A badge for a membership's type (the protected owner stands out)."
  attr :type, :atom, required: true

  def member_type_badge(assigns) do
    ~H"""
    <span class={[
      "mtb-badge",
      if(@type == :owner, do: "mtb-badge-warning", else: "mtb-badge-neutral")
    ]}>
      {if @type == :owner, do: "Owner", else: "Member"}
    </span>
    """
  end

  @doc "A badge for a membership's active / inactive state."
  attr :active, :boolean, required: true

  def member_active_badge(assigns) do
    ~H"""
    <span class={["mtb-badge", if(@active, do: "mtb-badge-success", else: "mtb-badge-neutral")]}>
      {if @active, do: "Active", else: "Inactive"}
    </span>
    """
  end

  @doc "A badge for a request status, using the design-system colours."
  attr :status, :atom, required: true

  def request_status_badge(assigns) do
    ~H"""
    <span class={["mtb-badge", request_status_class(@status)]}>{Request.status_label(@status)}</span>
    """
  end

  defp request_status_class(:open), do: "mtb-badge-warning"
  defp request_status_class(:approved), do: "mtb-badge-success"
  defp request_status_class(:declined), do: "mtb-badge-error"
  defp request_status_class(:cancelled), do: "mtb-badge-neutral"
  defp request_status_class(_status), do: "mtb-badge-neutral"

  @doc "A member's display name (falls back to the email local part)."
  def member_name(%Membership{user: %{display_name: name}}) when is_binary(name) and name != "",
    do: name

  def member_name(%Membership{user: %{email: email}}), do: name_from_email(email)
  def member_name(_membership), do: "—"

  @doc "A member's role label (owner stands alone; member shows its role name)."
  def member_role_label(%Membership{} = membership), do: Membership.role_label(membership)

  defp name_from_email(email) when is_binary(email),
    do: email |> String.split("@") |> List.first()

  defp name_from_email(_), do: "—"

  @doc "Formats a datetime for display, or an em dash."
  def format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y, %H:%M")
  def format_datetime(_value), do: "—"

  @doc "A vertical timeline of audit-log rows (newest first) — the activity feed on detail pages."
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

  @doc "Humanises an audit action key for display (user.role_changed → User role changed)."
  def action_label(action) when is_binary(action) do
    action |> String.replace(~r/[._]/, " ") |> String.capitalize()
  end

  def action_label(_action), do: "—"

  @doc "Human label for an audit actor type."
  def actor_label(:user), do: "Member"
  def actor_label(:admin), do: "Admin"
  def actor_label(:system), do: "System"
  def actor_label(_actor), do: "—"
end
