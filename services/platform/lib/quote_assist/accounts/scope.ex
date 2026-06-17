defmodule QuoteAssist.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `QuoteAssist.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias QuoteAssist.Accounts.User

  # `user` is the authenticated identity. The tenant fields are layered on top in
  # tenant-scoped contexts (R2): `tenant` is the resolved tenant, `membership` the
  # user's membership for it, and `permissions` the keys granted by that membership's
  # role (consumed by `QuoteAssist.Authz.Policy`).
  defstruct user: nil, tenant: nil, membership: nil, permissions: []

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Layers a resolved tenant, the user's membership, and that membership's permission
  keys onto an existing scope. Set by `on_mount :require_tenant_member` once the host
  has resolved a tenant and a live membership has been verified.
  """
  def put_tenant(%__MODULE__{} = scope, tenant, membership, permissions)
      when is_list(permissions) do
    %{scope | tenant: tenant, membership: membership, permissions: permissions}
  end
end
