defmodule QuoteAssistWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use QuoteAssistWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint QuoteAssistWeb.Endpoint

      use QuoteAssistWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import QuoteAssistWeb.ConnCase
    end
  end

  setup tags do
    QuoteAssist.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    user = QuoteAssist.AccountsFixtures.user_fixture()
    scope = QuoteAssist.Accounts.Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = QuoteAssist.Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  @doc """
  Setup helper that creates an active tenant (built-in roles seeded), a member with
  the given role (`:role` tag, default `"owner"`), logs them in, and points the conn
  at the tenant's subdomain host.

      setup :register_and_log_in_member

  Stores `:conn`, `:user`, `:tenant`, and `:membership` in the test context.
  """
  def register_and_log_in_member(%{conn: conn} = context) do
    tenant = QuoteAssist.TenantsFixtures.active_tenant_fixture(%{name: "Acme", slug: "acme"})

    {user, membership} =
      QuoteAssist.TenantsFixtures.member_fixture(tenant, context[:role] || "owner")

    %{
      conn: log_in_member(conn, user, tenant),
      user: user,
      tenant: tenant,
      membership: membership
    }
  end

  @doc """
  Logs `user` into `conn` and scopes the request to `tenant`: writes the session
  token + resolved tenant id and sets the conn host to the tenant's subdomain so the
  `TenantResolver` plug resolves the same tenant.
  """
  def log_in_member(conn, user, tenant) do
    token = QuoteAssist.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
    |> Plug.Conn.put_session(:tenant_id, tenant.id)
    |> put_tenant_host(tenant)
  end

  @doc "Sets the conn host to the tenant's subdomain under the test base domain."
  def put_tenant_host(conn, tenant), do: %{conn | host: "#{tenant.slug}.example.com"}

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    QuoteAssist.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end
end
