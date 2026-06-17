defmodule QuoteAssist.Authz.Permissions do
  @moduledoc """
  The code-owned permission catalog — the single home for what permissions exist
  (RELEASE_PLAN.md). `QuoteAssist.Authz.Policy` checks against these keys, roles
  store subsets of them, and R5's roles UI renders these groups read-only (admins
  compose roles, they never invent permissions). Keys mirror the design catalog in
  `designs/quoteassist/` (qa-team.js).
  """

  @catalog [
    %{
      group: "Quotes",
      permissions: [
        %{key: "quotes.view", label: "View quotes"},
        %{key: "quotes.create", label: "Create quotes"},
        %{key: "quotes.edit", label: "Edit quotes"},
        %{key: "quotes.send", label: "Send to customer"},
        %{key: "quotes.export", label: "Export CSV"},
        %{key: "quotes.delete", label: "Delete quotes"}
      ]
    },
    %{
      group: "Pricing",
      permissions: [
        %{key: "pricing.view", label: "View pricing sources"},
        %{key: "pricing.policy", label: "Edit fare policy"},
        %{key: "pricing.sources", label: "Manage pricing sources"}
      ]
    },
    %{
      group: "Team & access",
      permissions: [
        %{key: "team.view", label: "View team"},
        %{key: "team.invite", label: "Invite members"},
        %{key: "team.roles", label: "Manage roles & permissions"},
        %{key: "team.remove", label: "Remove members"}
      ]
    },
    %{
      group: "Settings",
      permissions: [
        %{key: "settings.view", label: "View settings"},
        %{key: "settings.edit", label: "Edit settings"},
        %{key: "settings.billing", label: "Manage billing"}
      ]
    }
  ]

  @keys for group <- @catalog, permission <- group.permissions, do: permission.key
  @labels (for group <- @catalog, permission <- group.permissions, into: %{} do
             {permission.key, permission.label}
           end)

  @doc "The full catalog, grouped for display (the R5 roles UI renders this)."
  def catalog, do: @catalog

  @doc "Every permission key, flat."
  def keys, do: @keys

  @doc "Whether `key` is a known permission."
  def valid?(key) when is_binary(key), do: key in @keys
  def valid?(_), do: false

  @doc "Human label for a permission key (falls back to the key itself)."
  def label(key), do: Map.get(@labels, key, key)
end
