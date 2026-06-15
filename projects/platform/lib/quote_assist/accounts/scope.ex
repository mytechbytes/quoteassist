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

  alias QuoteAssist.Accounts.Membership
  alias QuoteAssist.Accounts.User

  defstruct user: nil, membership: nil, tenant: nil, persona: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Activates a persona on the scope from a membership (its `tenant` and `role`
  should be preloaded). Sets the active persona and tenant used for authorization
  (`QuoteAssist.Policy`) and tenant scoping (`QuoteAssist.Tenancy.scope/2`).
  """
  def put_active(%__MODULE__{} = scope, %Membership{} = membership) do
    %{scope | membership: membership, persona: membership.persona, tenant: membership.tenant}
  end
end
