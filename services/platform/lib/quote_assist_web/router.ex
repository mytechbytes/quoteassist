defmodule QuoteAssistWeb.Router do
  use QuoteAssistWeb, :router

  import QuoteAssistWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {QuoteAssistWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
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

    live_session :require_authenticated_user,
      on_mount: [{QuoteAssistWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", QuoteAssistWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{QuoteAssistWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
