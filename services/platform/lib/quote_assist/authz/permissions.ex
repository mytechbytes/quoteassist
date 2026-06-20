defmodule QuoteAssist.Authz.Permissions do
  @moduledoc """
  The code-owned tenant permission catalog — the single home for what permissions
  exist (RELEASE_PLAN.md, R2). `QuoteAssist.Authz.Policy` checks against these keys,
  roles store subsets of them, and the R7-rbac roles UI renders these groups
  read-only (admins compose roles, they never invent permissions).

  ## Convention — `resource:action`

  Every permission is a `resource:action` key. Collection resources get the five base
  actions (`list` · `create` · `read` · `update` · `delete`); `list` and `read` are
  deliberately distinct (seeing a table vs. opening a record). Lifecycle/state-machine
  verbs (`activate`, `deactivate`, `status`, `reply`, `ai_generate`, `verify`,
  `manage`) are separate permissions, never folded into `update`. Singleton resources
  (`settings`, `domain`, `billing`) get only `read`/`update` (+ extras); the
  append-only nature of audit is admin-side (R4-retrofit), not here.

  ## `self:*` — fixed baseline, not role-composable

  Acting on your *own* record is distinct from acting on the collection. Every
  authenticated member implicitly holds the `self:*` baseline regardless of role; it
  is scoped to the actor's own row, never appears as a role checkbox, and cannot be
  removed. It is therefore **not** part of `catalog/0`/`keys/0` — see `baseline/0`
  and `baseline?/1`, consumed by `QuoteAssist.Authz.Policy`.
  """

  @catalog [
    %{
      group: "Quotes",
      resource: "quote",
      permissions: [
        %{key: "quote:list", label: "View quote list"},
        %{key: "quote:create", label: "Create quotes"},
        %{key: "quote:read", label: "Open a quote"},
        %{key: "quote:update", label: "Edit quotes"},
        %{key: "quote:delete", label: "Delete quotes"},
        %{key: "quote:status", label: "Change quote status"},
        %{key: "quote:reply", label: "Reply to a quote"},
        %{key: "quote:ai_generate", label: "Generate with AI"}
      ]
    },
    %{
      group: "Users",
      resource: "user",
      permissions: [
        %{key: "user:list", label: "View member list"},
        %{key: "user:create", label: "Invite members"},
        %{key: "user:read", label: "Open a member"},
        %{key: "user:update", label: "Edit members"},
        %{key: "user:delete", label: "Remove members"},
        %{key: "user:activate", label: "Reactivate members"},
        %{key: "user:deactivate", label: "Deactivate members"}
      ]
    },
    %{
      group: "Roles",
      resource: "role",
      permissions: [
        %{key: "role:list", label: "View roles"},
        %{key: "role:create", label: "Create roles"},
        %{key: "role:read", label: "Open a role"},
        %{key: "role:update", label: "Edit roles"},
        %{key: "role:delete", label: "Delete roles"}
      ]
    },
    %{
      group: "Requests",
      resource: "request",
      permissions: [
        %{key: "request:list", label: "View requests"},
        %{key: "request:create", label: "Raise a request"},
        %{key: "request:read", label: "Open a request"},
        %{key: "request:update", label: "Edit a request"},
        %{key: "request:delete", label: "Delete a request"},
        %{key: "request:manage", label: "Approve / decline requests"}
      ]
    },
    %{
      group: "Settings",
      resource: "settings",
      permissions: [
        %{key: "settings:read", label: "View settings"},
        %{key: "settings:update", label: "Edit settings"}
      ]
    },
    %{
      group: "Domain",
      resource: "domain",
      permissions: [
        %{key: "domain:read", label: "View custom domain"},
        %{key: "domain:update", label: "Edit custom domain"},
        %{key: "domain:verify", label: "Verify custom domain"}
      ]
    },
    %{
      group: "Billing",
      resource: "billing",
      permissions: [
        %{key: "billing:read", label: "View billing"},
        %{key: "billing:update", label: "Manage billing"}
      ]
    }
  ]

  # `self:*` — implicit baseline, scoped to the actor's own row. Never role-composable,
  # so it lives outside the catalog. `request:create` is NOT here: raising a leave/other
  # request is `request:create` in the catalog above (also baseline-granted in R7), not
  # a `self:*` key.
  @baseline ~w(self:read self:update self:password self:email self:sessions)

  # Catalog permissions implicitly granted to EVERY member, regardless of role
  # (RELEASE_PLAN.md, R7-rbac): raising a request (`request:create`) is something any
  # member can do. Unlike `self:*` these DO live in the catalog (so owners can also
  # compose them into roles), but they're also baseline so an empty-role member can
  # still raise a leave request. Consumed by `QuoteAssist.Authz.Policy`.
  @member_baseline ~w(request:create)

  @baseline_labels %{
    "self:read" => "View own profile",
    "self:update" => "Edit own profile",
    "self:password" => "Change own password",
    "self:email" => "Change own email",
    "self:sessions" => "Manage own sessions"
  }

  @keys for group <- @catalog, permission <- group.permissions, do: permission.key
  @labels (for group <- @catalog, permission <- group.permissions, into: %{} do
             {permission.key, permission.label}
           end)

  # Canonical column order for the role-editor permission matrix (R7-rbac): the five
  # base actions first, then the lifecycle / state-machine extras. Only actions that
  # actually appear in the catalog become columns (the grid is ragged — a resource
  # gets a checkbox only where `resource:action` is a real permission).
  @action_order ~w(list create read update delete activate deactivate status reply ai_generate manage verify)

  # The CRUD actions get their own matrix columns; everything else is a "special"
  # permission shown as a chip in the row's Special column (R7-rbac role editor).
  @base_actions ~w(list create read update delete)

  @action_labels %{
    "list" => "List",
    "create" => "Create",
    "read" => "Read",
    "update" => "Update",
    "delete" => "Delete",
    "activate" => "Activate",
    "deactivate" => "Deactivate",
    "status" => "Status",
    "reply" => "Reply",
    "ai_generate" => "AI",
    "manage" => "Manage",
    "verify" => "Verify"
  }

  @doc "The full catalog, grouped for display (the R7-rbac roles UI renders this)."
  def catalog, do: @catalog

  @doc """
  The action columns for the role-editor matrix — `[%{action: "create", label: "Create"}, …]`,
  in canonical order, restricted to actions that appear somewhere in the catalog.
  """
  def action_columns do
    present =
      for group <- @catalog,
          permission <- group.permissions,
          uniq: true,
          do: action_of(permission.key)

    for action <- @action_order,
        action in present,
        do: %{action: action, label: action_label(action)}
  end

  @doc "The base (CRUD) action columns for the matrix, in canonical order, present-only."
  def base_action_columns, do: Enum.filter(action_columns(), &(&1.action in @base_actions))

  @doc """
  The non-CRUD ("special") permissions of a `resource` — `[%{key:, action:, label:}, …]`,
  rendered as chips in the role editor's Special column. Empty for a CRUD-only resource.
  """
  def special_permissions(resource) do
    case Enum.find(@catalog, &(&1.resource == resource)) do
      nil ->
        []

      group ->
        for permission <- group.permissions,
            action = action_of(permission.key),
            action not in @base_actions,
            do: %{key: permission.key, action: action, label: action_label(action)}
    end
  end

  @doc "Every special (non-CRUD) permission key, flat — backs the Special column's select-all."
  def special_keys do
    for group <- @catalog,
        permission <- group.permissions,
        action_of(permission.key) not in @base_actions,
        do: permission.key
  end

  @doc "The permission key for a `resource`/`action` pair, e.g. `\"quote:create\"`."
  def key_for(resource, action), do: "#{resource}:#{action}"

  @doc "Human label for an action suffix (the matrix column header)."
  def action_label(action), do: Map.get(@action_labels, action, String.capitalize(action))

  defp action_of(key), do: key |> String.split(":") |> List.last()

  @doc "Every role-composable permission key, flat (excludes the `self:*` baseline)."
  def keys, do: @keys

  @doc "The fixed `self:*` baseline keys, held implicitly by every member."
  def baseline, do: @baseline

  @doc "Whether `key` is part of the implicit `self:*` baseline."
  def baseline?(key) when is_binary(key), do: key in @baseline
  def baseline?(_), do: false

  @doc "Catalog keys every member holds implicitly regardless of role (e.g. `request:create`)."
  def member_baseline, do: @member_baseline

  @doc "Whether `key` is granted to every member by baseline (the `self:*` or member baseline)."
  def member_baseline?(key) when is_binary(key), do: key in @baseline or key in @member_baseline
  def member_baseline?(_), do: false

  @doc "Whether `key` is a known, role-composable permission (the `self:*` baseline is not)."
  def valid?(key) when is_binary(key), do: key in @keys
  def valid?(_), do: false

  @doc "Human label for a permission key — catalog or baseline (falls back to the key)."
  def label(key) do
    Map.get(@labels, key) || Map.get(@baseline_labels, key) || key
  end
end
