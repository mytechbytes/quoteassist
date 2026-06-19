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

  @doc "The full catalog, grouped for display (the R7-rbac roles UI renders this)."
  def catalog, do: @catalog

  @doc "Every role-composable permission key, flat (excludes the `self:*` baseline)."
  def keys, do: @keys

  @doc "The fixed `self:*` baseline keys, held implicitly by every member."
  def baseline, do: @baseline

  @doc "Whether `key` is part of the implicit `self:*` baseline."
  def baseline?(key) when is_binary(key), do: key in @baseline
  def baseline?(_), do: false

  @doc "Whether `key` is a known, role-composable permission (the `self:*` baseline is not)."
  def valid?(key) when is_binary(key), do: key in @keys
  def valid?(_), do: false

  @doc "Human label for a permission key — catalog or baseline (falls back to the key)."
  def label(key) do
    Map.get(@labels, key) || Map.get(@baseline_labels, key) || key
  end
end
