defmodule QuoteAssist.Authz.AdminPermissions do
  @moduledoc """
  The code-owned **admin** permission catalog — the platform-side mirror of
  `QuoteAssist.Authz.Permissions` (RELEASE_PLAN.md, R4-retrofit). This is the single
  home for what admin permissions exist; `QuoteAssist.Authz.AdminPolicy` checks
  against these keys, `QuoteAssist.Accounts.AdminRole` stores subsets of them, and the
  admin roles UI renders these groups read-only (admins compose roles, they never
  invent permissions).

  ## Convention — `resource:action`

  Same convention as the tenant catalog: collection resources get the five base
  actions (`list` · `create` · `read` · `update` · `delete`); `list` and `read` are
  distinct. Lifecycle/state-machine verbs (`activate`, `deactivate`, `suspend`,
  `cancel`, `purge`) are separate permissions, never folded into `update`. The
  append-only `audit` resource gets only `list`/`read`.

  ## `self:*` — fixed baseline, not role-composable

  Every authenticated admin implicitly holds the same `self:*` baseline as tenant
  members, scoped to their own row. It is therefore **not** part of `catalog/0` /
  `keys/0` — see `baseline/0` and `baseline?/1`, consumed by
  `QuoteAssist.Authz.AdminPolicy`.
  """

  @catalog [
    %{
      group: "Agencies",
      resource: "tenant",
      permissions: [
        %{key: "tenant:list", label: "View agency list"},
        %{key: "tenant:create", label: "Create agencies"},
        %{key: "tenant:read", label: "Open an agency"},
        %{key: "tenant:update", label: "Edit agencies"},
        %{key: "tenant:delete", label: "Remove agencies"},
        %{key: "tenant:activate", label: "Reactivate agencies"},
        %{key: "tenant:deactivate", label: "Deactivate agencies"},
        %{key: "tenant:suspend", label: "Suspend agencies"},
        %{key: "tenant:cancel", label: "Cancel agencies"},
        %{key: "tenant:purge", label: "Purge agencies"}
      ]
    },
    %{
      group: "Plans",
      resource: "plan",
      permissions: [
        %{key: "plan:list", label: "View plans"},
        %{key: "plan:create", label: "Create plans"},
        %{key: "plan:read", label: "Open a plan"},
        %{key: "plan:update", label: "Edit plans"},
        %{key: "plan:delete", label: "Delete plans"}
      ]
    },
    %{
      group: "Administrators",
      resource: "admin",
      permissions: [
        %{key: "admin:list", label: "View admin list"},
        %{key: "admin:create", label: "Create admins"},
        %{key: "admin:read", label: "Open an admin"},
        %{key: "admin:update", label: "Edit admins"},
        %{key: "admin:delete", label: "Remove admins"},
        %{key: "admin:activate", label: "Reactivate admins"},
        %{key: "admin:deactivate", label: "Deactivate admins"}
      ]
    },
    %{
      group: "Admin roles",
      resource: "admin_role",
      permissions: [
        %{key: "admin_role:list", label: "View admin roles"},
        %{key: "admin_role:create", label: "Create admin roles"},
        %{key: "admin_role:read", label: "Open an admin role"},
        %{key: "admin_role:update", label: "Edit admin roles"},
        %{key: "admin_role:delete", label: "Delete admin roles"}
      ]
    },
    %{
      group: "Audit",
      resource: "audit",
      permissions: [
        %{key: "audit:list", label: "View activity"},
        %{key: "audit:read", label: "Open an activity entry"}
      ]
    }
  ]

  # `self:*` — implicit baseline, scoped to the actor's own row. Identical to the
  # tenant baseline; never role-composable, so it lives outside the catalog.
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

  @doc "The full admin catalog, grouped for display (the admin roles UI renders this)."
  def catalog, do: @catalog

  @doc "Every role-composable admin permission key, flat (excludes the `self:*` baseline)."
  def keys, do: @keys

  @doc "The fixed `self:*` baseline keys, held implicitly by every admin."
  def baseline, do: @baseline

  @doc "Whether `key` is part of the implicit `self:*` baseline."
  def baseline?(key) when is_binary(key), do: key in @baseline
  def baseline?(_), do: false

  @doc "Whether `key` is a known, role-composable admin permission (the baseline is not)."
  def valid?(key) when is_binary(key), do: key in @keys
  def valid?(_), do: false

  @doc "Human label for an admin permission key — catalog or baseline (falls back to the key)."
  def label(key) do
    Map.get(@labels, key) || Map.get(@baseline_labels, key) || key
  end
end
