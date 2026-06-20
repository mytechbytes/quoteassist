defmodule QuoteAssist.Authz.PermissionsTest do
  use ExUnit.Case, async: true

  alias QuoteAssist.Authz.Permissions

  test "action_columns/0 lists base actions first, only those present in the catalog" do
    actions = Enum.map(Permissions.action_columns(), & &1.action)
    assert Enum.take(actions, 5) == ~w(list create read update delete)
    # extras that exist somewhere in the tenant catalog
    assert "status" in actions
    assert "manage" in actions
    assert "verify" in actions
    # nothing the catalog never uses
    refute "purge" in actions
  end

  test "base_action_columns/0 is only the five CRUD actions" do
    assert Enum.map(Permissions.base_action_columns(), & &1.action) ==
             ~w(list create read update delete)
  end

  test "special_permissions/1 returns a resource's non-CRUD permissions as chips" do
    assert Enum.map(Permissions.special_permissions("quote"), & &1.action) ==
             ~w(status reply ai_generate)

    assert Enum.map(Permissions.special_permissions("user"), & &1.action) ==
             ~w(activate deactivate)

    # CRUD-only / unknown resources have no chips
    assert Permissions.special_permissions("role") == []
    assert Permissions.special_permissions("nope") == []
  end

  test "special_keys/0 is every non-CRUD key, and no CRUD key" do
    keys = Permissions.special_keys()
    assert "quote:status" in keys
    assert "user:activate" in keys
    assert "request:manage" in keys
    assert "domain:verify" in keys
    refute "quote:create" in keys
    refute "settings:read" in keys
    # the matrix is exhaustive: base columns + specials cover the whole catalog
    base =
      for c <- Permissions.base_action_columns(),
          g <- Permissions.catalog(),
          do: Permissions.key_for(g.resource, c.action)

    covered = Enum.filter(base, &Permissions.valid?/1) ++ keys
    assert Enum.sort(covered) == Enum.sort(Permissions.keys())
  end

  test "key_for/2 and action_label/1" do
    assert Permissions.key_for("quote", "create") == "quote:create"
    assert Permissions.action_label("ai_generate") == "AI"
    assert Permissions.action_label("create") == "Create"
    assert Permissions.action_label("mystery") == "Mystery"
  end

  test "every matrix cell that is valid maps to a real catalog key" do
    columns = Enum.map(Permissions.action_columns(), & &1.action)

    valid_keys =
      for group <- Permissions.catalog(),
          action <- columns,
          key = Permissions.key_for(group.resource, action),
          Permissions.valid?(key),
          do: key

    assert Enum.sort(valid_keys) == Enum.sort(Permissions.keys())
  end
end
