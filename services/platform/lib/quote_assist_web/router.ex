defmodule QuoteAssistWeb.Router do
  use QuoteAssistWeb, :router

  import QuoteAssistWeb.UserAuth
  import QuoteAssistWeb.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    # Maintenance gate (R6-errors): when :maintenance_mode is on, every browser
    # request short-circuits to the branded 503. Runs first, before sessions/tenant
    # resolution. Health probes live on the :api pipeline, so they stay up.
    plug QuoteAssistWeb.Plugs.Maintenance
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

  # Admin lives only on the platform host. RequirePlatform is the inverse of
  # RequireTenant — it 404s tenant hosts, so /admin is invisible on subdomains /
  # custom domains. `:admin` loads current_admin; `:require_admin_session` gates the
  # authenticated console. Admin auth is a fully separate identity from UserAuth.
  pipeline :require_platform do
    plug QuoteAssistWeb.Plugs.RequirePlatform
  end

  pipeline :admin do
    plug :fetch_current_admin
  end

  pipeline :require_admin_session do
    plug :require_authenticated_admin
  end

  # Reuses the R1 throttle, but bounces back to the admin login on the limit.
  pipeline :admin_login_throttle do
    plug QuoteAssistWeb.Plugs.LoginThrottle, redirect_to: "/admin/login"
  end

  # The build-status home is platform content. On the platform host it renders; on a
  # tenant host there is no platform home, so the controller redirects into the
  # workspace (or its login) instead of showing platform chrome. `/` stays reachable
  # (not RequirePlatform-gated) so the tenant root — e.g. the post-logout redirect
  # target — never 404s.
  scope "/", QuoteAssistWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Platform-host-only: the tenant directory and the "Admin login" link in its shared
  # `Layouts.app` chrome live solely on the primary domain. RequirePlatform 404s this
  # on any tenant subdomain / custom domain.
  scope "/", QuoteAssistWeb do
    pipe_through [:browser, :require_platform]

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
      # Owner onboarding (set name + password) after accepting the invite.
      live "/app/welcome", OnboardingLive, :index
      # R7-rbac · tenant users, roles, self-service, and the requests inbox. Page-level
      # gates raise → branded 403 (UserAuth.permit!); per-action gates hide/deny.
      live "/app/team", App.TeamLive.Index, :index
      live "/app/roles", App.RoleLive.Index, :index
      live "/app/roles/new", App.RoleLive.Form, :new
      live "/app/roles/:id/edit", App.RoleLive.Form, :edit
      live "/app/account", App.AccountLive, :index
      live "/app/requests", App.RequestLive.Index, :index
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

  # ── Self-registration + onboarding (R5-selfreg) — platform host only ──────────────
  # Public pages: a company self-registers at /register (tenant created directly on a
  # 15-day trial), then the owner sets a password on the platform-host onboarding link
  # (/onboarding/:token) and is sent to their tenant's own-host login. RequirePlatform
  # 404s these on tenant hosts so onboarding always lives on the apex.
  scope "/", QuoteAssistWeb do
    pipe_through [:browser, :require_platform]

    live_session :public_onboarding,
      on_mount: [{QuoteAssistWeb.UserAuth, :mount_current_scope}] do
      live "/register", RegistrationLive, :new
      live "/onboarding/:token", OnboardingSetupLive, :new
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

  # ── Site admin (R3) — platform host only ──────────────────────────────────────
  # RequirePlatform 404s these on tenant hosts. Admin auth is a separate identity
  # (admin_token session); :require_admin guards every authenticated route + LiveView.
  scope "/admin", QuoteAssistWeb do
    pipe_through [:browser, :require_platform, :admin]

    # Logout clears only the admin session.
    delete "/logout", AdminSessionController, :delete

    live_session :admin_unauthenticated,
      on_mount: [{QuoteAssistWeb.AdminAuth, :mount_current_admin}] do
      live "/login", Admin.LoginLive, :new
    end
  end

  # Admin credential POST — platform host + throttle (bounces to /admin/login).
  scope "/admin", QuoteAssistWeb do
    pipe_through [:browser, :require_platform, :admin, :admin_login_throttle]

    post "/login", AdminSessionController, :create
  end

  # Authenticated admin console.
  scope "/admin", QuoteAssistWeb do
    pipe_through [:browser, :require_platform, :admin, :require_admin_session]

    live_session :admin_authenticated,
      on_mount: [{QuoteAssistWeb.AdminAuth, :require_admin}] do
      live "/", Admin.DashboardLive, :index
      live "/tenants", Admin.TenantLive.Index, :index
      live "/tenants/:id", Admin.TenantLive.Show, :show
      live "/plans", Admin.PlanLive.Index, :index
      live "/plans/:id", Admin.PlanLive.Show, :show
      live "/admins", Admin.AdminLive.Index, :index
      live "/admins/:id", Admin.AdminLive.Show, :show
      live "/roles", Admin.AdminRoleLive.Index, :index
      live "/roles/new", Admin.AdminRoleLive.Form, :new
      live "/roles/:id/edit", Admin.AdminRoleLive.Form, :edit
      live "/roles/:id", Admin.AdminRoleLive.Show, :show
      live "/activity", Admin.ActivityLive, :index
    end
  end

  # NOTE: self-registration (/register + /onboarding/:token) shipped in R5-selfreg
  # above. The profile/settings and password-change surface lands in R7-rbac, and
  # account recovery (forgot/reset) in R9-recovery (see RELEASE_PLAN.md).

  # Catch-all — MUST stay the last route. Any path no route above matched renders the
  # branded, themed 404 through the :browser pipeline. TenantResolver runs first, so an
  # unknown host still shows "workspace not found", a suspended tenant its 403, and
  # maintenance mode its 503; a known tenant host or the platform host falls through to
  # here. Matching a real route — instead of letting the request raise
  # Phoenix.Router.NoRouteError — is deliberate: it keeps the branded page consistent in
  # every environment, since in dev `debug_errors` would otherwise replace an unmatched
  # route with an unstyled debug page.
  scope "/", QuoteAssistWeb do
    pipe_through :browser

    get "/*path", PageController, :not_found
  end
end
