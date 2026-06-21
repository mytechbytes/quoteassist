defmodule QuoteAssistWeb.App.SettingsLive.Domain do
  @moduledoc """
  Custom-domain settings (`/app/settings/domain`, R10-domain). An owner (or a role with
  `domain:*`) points their own domain at the workspace and proves ownership with a DNS
  TXT record; once verified the app serves on it with auto-TLS (Caddy on-demand, gated by
  the `/tls/check` endpoint). The platform subdomain always keeps working as a fallback.

  Page gate: `domain:read` (raise → branded 403). Per-action gates: `domain:update` (set /
  clear) and `domain:verify` (run the DNS check). The tenant is reloaded from the DB after
  each action so the displayed status never drifts.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Tenants
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(_params, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "domain:read")

    {:ok, socket |> assign(page_title: "Custom domain") |> load_tenant()}
  end

  defp load_tenant(socket) do
    tenant = Tenants.get_tenant_by_slug(socket.assigns.current_scope.tenant.slug)

    socket
    |> assign(tenant: tenant, subdomain: Tenants.custom_domain_cname_target(tenant))
    |> assign(:form, to_form(Tenants.change_custom_domain(tenant), as: :domain))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="settings"
      breadcrumb="Custom domain"
    >
      <div class="mb-7">
        <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
          Settings
        </div>
        <h1
          class="mt-1.5 text-3xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          Custom domain
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          Serve your workspace on your own domain. Your QuoteAssist subdomain always keeps working
          as a fallback.
        </p>
      </div>

      <div class="max-w-2xl space-y-5">
        <section class="mtb-card p-6">
          <div class="flex items-center justify-between gap-3">
            <div>
              <h2
                class="text-base font-bold"
                style="font-family:var(--font-display);color:var(--mc-text)"
              >
                Platform subdomain
              </h2>
              <p class="mt-1 font-mono text-sm" style="color:var(--mc-text-2)">{@subdomain}</p>
            </div>
            <span class="mtb-badge mtb-badge-success">Always active</span>
          </div>
        </section>

        <.none_state :if={@tenant.custom_domain_status == :none} form={@form} scope={@current_scope} />
        <.pending_state
          :if={@tenant.custom_domain_status == :pending}
          tenant={@tenant}
          subdomain={@subdomain}
          txt_value={Tenants.custom_domain_txt_value(@tenant)}
          scope={@current_scope}
        />
        <.verified_state
          :if={@tenant.custom_domain_status == :verified}
          tenant={@tenant}
          scope={@current_scope}
        />
      </div>
    </Layouts.workspace>
    """
  end

  attr :form, :any, required: true
  attr :scope, :map, required: true

  defp none_state(assigns) do
    ~H"""
    <section class="mtb-card p-6">
      <h2 class="text-base font-bold" style="font-family:var(--font-display);color:var(--mc-text)">
        Add a custom domain
      </h2>
      <p class="mb-4 mt-1 text-sm" style="color:var(--mc-text-2)">
        Enter the domain you'd like to use, e.g. <span class="font-mono">quotes.acme.com</span>.
        We'll give you the DNS records to add next.
      </p>
      <.form
        :if={can?(@scope, "domain:update")}
        for={@form}
        id="domain-form"
        phx-change="validate"
        phx-submit="save"
      >
        <div class="flex items-start gap-2">
          <div class="flex-1">
            <.input field={@form[:custom_domain]} type="text" placeholder="quotes.acme.com" />
          </div>
          <.button class="mtb-btn mtb-btn-primary mtb-btn-sm mt-1" phx-disable-with="Saving…">
            Add domain
          </.button>
        </div>
      </.form>
      <p :if={not can?(@scope, "domain:update")} class="text-sm" style="color:var(--mc-text-3)">
        You don't have permission to change the domain.
      </p>
    </section>
    """
  end

  attr :tenant, :any, required: true
  attr :subdomain, :string, required: true
  attr :txt_value, :string, required: true
  attr :scope, :map, required: true

  defp pending_state(assigns) do
    ~H"""
    <section class="mtb-card p-6">
      <div class="mb-4 flex items-center justify-between gap-3">
        <div>
          <h2 class="text-base font-bold" style="font-family:var(--font-display);color:var(--mc-text)">
            {@tenant.custom_domain}
          </h2>
          <p class="mt-0.5 text-sm" style="color:var(--mc-text-2)">Add these records, then verify.</p>
        </div>
        <span class="mtb-badge mtb-badge-warning">Pending</span>
      </div>

      <div class="space-y-3">
        <.dns_record kind="CNAME" host={@tenant.custom_domain} value={@subdomain} />
        <.dns_record kind="TXT" host={@tenant.custom_domain} value={@txt_value} />
      </div>

      <div class="mt-5 flex items-center gap-2">
        <button
          :if={can?(@scope, "domain:verify")}
          phx-click="verify"
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
          phx-disable-with="Checking…"
        >
          Verify domain
        </button>
        <button
          :if={can?(@scope, "domain:update")}
          phx-click="clear"
          data-confirm="Remove this custom domain?"
          class="mtb-btn mtb-btn-danger-outline mtb-btn-sm"
        >
          Remove
        </button>
      </div>
    </section>
    """
  end

  attr :tenant, :any, required: true
  attr :scope, :map, required: true

  defp verified_state(assigns) do
    ~H"""
    <section class="mtb-card p-6">
      <div class="flex items-center justify-between gap-3">
        <div>
          <h2 class="text-base font-bold" style="font-family:var(--font-display);color:var(--mc-text)">
            {@tenant.custom_domain}
          </h2>
          <p class="mt-0.5 text-sm" style="color:var(--mc-text-2)">
            Live with automatic TLS. Your subdomain still works too.
          </p>
        </div>
        <span class="mtb-badge mtb-badge-success">Verified</span>
      </div>
      <div class="mt-5">
        <button
          :if={can?(@scope, "domain:update")}
          phx-click="clear"
          data-confirm="Remove this custom domain? The workspace will fall back to the subdomain."
          class="mtb-btn mtb-btn-danger-outline mtb-btn-sm"
        >
          Remove domain
        </button>
      </div>
    </section>
    """
  end

  attr :kind, :string, required: true
  attr :host, :string, required: true
  attr :value, :string, required: true

  defp dns_record(assigns) do
    ~H"""
    <div class="rounded-lg p-3" style="background:var(--mc-surface-2)">
      <div class="mb-1 flex items-center gap-2">
        <span class="mtb-badge mtb-badge-neutral">{@kind}</span>
        <span class="font-mono text-xs" style="color:var(--mc-text-3)">{@host}</span>
      </div>
      <input
        type="text"
        readonly
        value={@value}
        class="mtb-input w-full font-mono text-xs"
        onclick="this.select()"
      />
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"domain" => params}, socket) do
    changeset =
      socket.assigns.tenant
      |> Tenants.change_custom_domain(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :domain))}
  end

  def handle_event("save", %{"domain" => params}, socket) do
    scope = socket.assigns.current_scope

    with true <- can?(scope, "domain:update"),
         {:ok, _tenant} <- Tenants.set_custom_domain(scope, socket.assigns.tenant, params) do
      {:noreply,
       socket
       |> put_flash(:info, "Domain saved. Add the DNS records, then verify.")
       |> load_tenant()}
    else
      false ->
        {:noreply, put_flash(socket, :error, "You don't have permission to do that.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :domain))}
    end
  end

  def handle_event("verify", _params, socket) do
    scope = socket.assigns.current_scope

    with true <- can?(scope, "domain:verify"),
         {:ok, _tenant} <- Tenants.verify_custom_domain(scope, socket.assigns.tenant) do
      {:noreply,
       socket |> put_flash(:info, "Domain verified — it's live with TLS.") |> load_tenant()}
    else
      false ->
        {:noreply, put_flash(socket, :error, "You don't have permission to do that.")}

      {:error, :no_domain} ->
        {:noreply, socket |> put_flash(:error, "Add a domain first.") |> load_tenant()}

      {:error, :not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "We couldn't find the TXT record yet. DNS changes can take a while — try again shortly."
         )}
    end
  end

  def handle_event("clear", _params, socket) do
    scope = socket.assigns.current_scope

    with true <- can?(scope, "domain:update"),
         {:ok, _tenant} <- Tenants.clear_custom_domain(scope, socket.assigns.tenant) do
      {:noreply, socket |> put_flash(:info, "Custom domain removed.") |> load_tenant()}
    else
      false ->
        {:noreply, put_flash(socket, :error, "You don't have permission to do that.")}

      {:error, _} ->
        {:noreply, socket |> put_flash(:error, "Couldn't update the domain.") |> load_tenant()}
    end
  end
end
