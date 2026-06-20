defmodule QuoteAssist.Authz.AdminPermissionsTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.Authz.AdminPermissions

  test "base_action_columns/0 is only the five CRUD actions" do
    assert Enum.map(AdminPermissions.base_action_columns(), & &1.action) ==
             ~w(list create read update delete)
  end

  test "special_permissions/1 returns admin-side extras as chips" do
    assert Enum.map(AdminPermissions.special_permissions("tenant"), & &1.action) ==
             ~w(activate deactivate suspend cancel purge)

    assert Enum.map(AdminPermissions.special_permissions("admin"), & &1.action) ==
             ~w(activate deactivate)

    # CRUD-only / append-only resources have no chips
    assert AdminPermissions.special_permissions("plan") == []
    assert AdminPermissions.special_permissions("audit") == []
    assert AdminPermissions.special_permissions("nope") == []
  end

  test "special_keys/0 + base columns exhaustively cover the catalog" do
    keys = AdminPermissions.special_keys()
    assert "tenant:suspend" in keys
    assert "tenant:purge" in keys
    assert "admin:activate" in keys
    refute "tenant:create" in keys

    base =
      for c <- AdminPermissions.base_action_columns(),
          g <- AdminPermissions.catalog(),
          do: AdminPermissions.key_for(g.resource, c.action)

    covered = Enum.filter(base, &AdminPermissions.valid?/1) ++ keys
    assert Enum.sort(covered) == Enum.sort(AdminPermissions.keys())
  end

  test "action_label/1 covers the admin lifecycle verbs" do
    assert AdminPermissions.action_label("suspend") == "Suspend"
    assert AdminPermissions.action_label("purge") == "Purge"
    assert AdminPermissions.action_label("mystery") == "Mystery"
  end
end
