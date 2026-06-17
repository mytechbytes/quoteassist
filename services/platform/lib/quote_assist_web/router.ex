defmodule QuoteAssistWeb.Router do
  use QuoteAssistWeb, :router

  import QuoteAssistWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    # Resolve the tenant from the host before anything else touches it: assigns
    # :current_tenant, writes the tenant id into the host-scoped session, and 404s
    # unknown/suspended/deleted tenant hosts. Never reads params.
    plug QuoteAssistWeb.Plugs.TenantResolver
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuoteAssistWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Throttles the login POST (per-IP + per-email) via QuoteAssist.RateLimiter.
  # Reused for /admin/login and /register in later releases.
  pipeline :login_throttle do
    plug QuoteAssistWeb.Plugs.LoginThrottle
  end

  # Tenant login lives only on a resolved tenant host. On the platform host this
  # redirects to the public directory (no tenant login there; admins use /admin/login).
  pipeline :require_tenant do
    plug QuoteAssistWeb.Plugs.RequireTenant
  end

  scope "/", QuoteAssistWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Public tenant directory — links out to each tenant's subdomain login.
    # Tenant subdomains aren't resolved until R2 (TenantResolver), so those
    # links 404 gracefully for now.
    live "/tenants", TenantListLive
  end

  # Health probes — no auth, no CSRF, no session overhead.
  # GET /health       → liveness  (200 if process alive)
  # GET /health/ready → readiness (200 if DB reachable, 503 otherwise)
  scope "/", QuoteAssistWeb do
    pipe_through :api

    get "/health", HealthController, :liveness
    get "/health/ready", HealthController, :readiness
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:quote_assist, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: QuoteAssistWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", QuoteAssistWeb do
    pipe_through [:browser, :require_authenticated_user]

    # /app/* is the tenant workspace: requires a logged-in user with a live
    # membership for the tenant resolved from the host. The on_mount reloads the
    # tenant from the session each mount, so suspended/deleted tenants are caught.
    live_session :require_tenant_member,
      on_mount: [{QuoteAssistWeb.UserAuth, :require_tenant_member}] do
      live "/app", AppHomeLive, :index
    end
  end

  # Tenant login — only on a resolved tenant host (:require_tenant bounces the
  # platform host to the directory).
  scope "/", QuoteAssistWeb do
    pipe_through [:browser, :require_tenant]

    live_session :current_user,
      on_mount: [{QuoteAssistWeb.UserAuth, :mount_current_scope}] do
      live "/login", UserLive.Login, :new
      live "/login/:token", UserLive.Confirmation, :new
    end
  end

  # Logout is host-agnostic — it only clears the current session.
  scope "/", QuoteAssistWeb do
    pipe_through [:browser]

    delete "/logout", UserSessionController, :delete
  end

  # The credential POST: tenant host + login throttle.
  scope "/", QuoteAssistWeb do
    pipe_through [:browser, :require_tenant, :login_throttle]

    post "/login", UserSessionController, :create
  end

  # NOTE: self-registration (/register) lands in R4; the settings screen and
  # password change land in R6. Their generated routes/LiveViews/tests were
  # removed to keep R1 to sign in / out only (see RELEASE_PLAN.md).
end
