defmodule QuoteAssistWeb.RegistrationLive do
  @moduledoc """
  Public self-registration (`/register`, platform host only — gated by
  `RequirePlatform`). A company enters its name, a desired subdomain slug, and the
  owner's name + email; `Tenants.register_self_service/1` creates the tenant directly
  on a 15-day trial (no admin approval, RELEASE_PLAN.md R5-selfreg) and emails the
  owner a platform-host onboarding link.

  No password is collected here — the owner sets one (and confirms their email) on the
  onboarding link. The submit is throttled per-email via the R1 rate limiter. Ported
  from `designs/quoteassist/register.html` (`mc-*`/`qa-*` → `mtb-*`).
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Tenants
  alias QuoteAssistWeb.Plugs.LoginThrottle

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Create your account",
       state: :form,
       base_domain: base_domain(),
       owner_email: nil
     )
     |> assign_form(Tenants.change_self_registration())}
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  @impl true
  def render(assigns) do
    ~H"""
    <div class="grid min-h-screen lg:grid-cols-2">
      <%!-- Brand panel (hidden below lg, per the design) --%>
      <aside class="mtb-auth-aside hidden flex-col p-14 lg:flex">
        <a href="/" class="relative flex items-center gap-2.5 no-underline" style="color:inherit">
          <span class="mtb-logo" style="width:36px;height:36px;font-size:15px">QA</span>
          <span style="font-family:var(--font-display);font-weight:700;font-size:1.125rem">
            QuoteAssist
          </span>
        </a>

        <div class="relative flex flex-1 items-center">
          <div>
            <div class="mb-5 text-sm font-semibold uppercase tracking-widest opacity-80">
              Free 15-day trial
            </div>
            <h1
              class="font-bold tracking-tight"
              style="font-family:var(--font-display);font-size:3rem;line-height:1.03"
            >
              Set up your<br />quoting desk<br />in two minutes.
            </h1>
            <ul class="mt-8 space-y-3.5" style="max-width:28rem">
              <li :for={point <- value_points()} class="flex items-start gap-3 opacity-90">
                <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0" />
                <span>{point}</span>
              </li>
            </ul>
          </div>
        </div>

        <div class="relative text-sm opacity-80">
          Your subdomain is yours forever — add a custom domain later.
        </div>
      </aside>

      <%!-- Form panel --%>
      <main
        class="relative flex items-center justify-center p-6 sm:p-10"
        style="background:var(--mc-bg)"
      >
        <div class="absolute right-6 top-6 flex items-center gap-3 text-sm">
          <span style="color:var(--mc-text-2)">Have an account?</span>
          <a href="/login" class="font-semibold no-underline" style="color:var(--mc-brand)">
            Sign in →
          </a>
          <Layouts.theme_toggle />
        </div>

        <div class="mtb-auth-card">
          <a
            href="/"
            class="mb-8 flex items-center gap-2 no-underline lg:hidden"
            style="color:var(--mc-text)"
          >
            <span class="mtb-logo" style="width:28px;height:28px;font-size:12px">QA</span>
            <span style="font-family:var(--font-display);font-weight:700">QuoteAssist</span>
          </a>

          <.registration_form :if={@state == :form} form={@form} base_domain={@base_domain} />
          <.sent_panel :if={@state == :sent} owner_email={@owner_email} />
        </div>
      </main>
    </div>

    <Layouts.flash_group flash={@flash} />
    """
  end

  attr :form, :any, required: true
  attr :base_domain, :string, required: true

  defp registration_form(assigns) do
    ~H"""
    <h1
      class="text-3xl font-bold tracking-tight"
      style="font-family:var(--font-display);color:var(--mc-text)"
    >
      Create your account
    </h1>
    <p class="mt-2 text-sm" style="color:var(--mc-text-2)">
      Start free — no card needed. You'll set a password from the email we send.
    </p>

    <.form
      for={@form}
      id="registration-form"
      phx-change="validate"
      phx-submit="save"
      class="mt-7 space-y-4"
    >
      <.input
        field={@form[:name]}
        type="text"
        label="Company name"
        placeholder="Skyline Travel"
        class="mtb-input mtb-input-lg"
        required
      />

      <div>
        <.input
          field={@form[:slug]}
          type="text"
          label="Workspace address"
          placeholder="skyline"
          class="mtb-input mtb-input-lg"
          required
        />
        <p class="mt-1.5 text-xs" style="color:var(--mc-text-3)">
          Your workspace will live at
          <span class="font-mono font-semibold" style="color:var(--mc-text-2)">
            {slug_preview(@form[:slug].value)}.{@base_domain}
          </span>
        </p>
      </div>

      <.input
        field={@form[:owner_name]}
        type="text"
        label="Your name"
        placeholder="Rana Aziz"
        class="mtb-input mtb-input-lg"
        required
      />

      <.input
        field={@form[:owner_email]}
        type="email"
        label="Work email"
        autocomplete="username"
        spellcheck="false"
        placeholder="rana@skylinetravel.com"
        class="mtb-input mtb-input-lg"
        required
      />

      <.button class="mtb-btn mtb-btn-lg mtb-btn-primary w-full" phx-disable-with="Creating…">
        Create account <span aria-hidden="true">→</span>
      </.button>
    </.form>

    <p class="mt-6 text-center text-xs" style="color:var(--mc-text-3)">
      We'll email a setup link to confirm your address.
    </p>
    """
  end

  attr :owner_email, :string, required: true

  defp sent_panel(assigns) do
    ~H"""
    <div
      class="mb-5 grid h-12 w-12 place-items-center rounded-2xl"
      style="background:var(--mc-brand-soft);color:var(--mc-brand)"
    >
      <.icon name="hero-envelope" class="size-6" />
    </div>
    <h1
      class="text-2xl font-bold tracking-tight"
      style="font-family:var(--font-display);color:var(--mc-text)"
    >
      Check your inbox
    </h1>
    <p class="mt-2 text-sm" style="color:var(--mc-text-2);line-height:1.6">
      Your workspace is ready. We emailed a setup link to <span
        class="font-semibold"
        style="color:var(--mc-text)"
      >{@owner_email}</span>.
      Open it to set a password and confirm your email, then you'll be signed in.
    </p>

    <div
      :if={local_mail_adapter?()}
      class="mtb-card mt-6 flex items-start gap-3 p-3 text-xs"
      style="background:var(--mc-surface-2)"
    >
      <.icon
        name="hero-information-circle"
        class="mt-0.5 size-4 shrink-0"
        style="color:var(--mc-text-3)"
      />
      <div style="color:var(--mc-text-2);line-height:1.5">
        Local mail adapter is on — open your setup link at <.link
          href="/dev/mailbox"
          class="font-semibold"
          style="color:var(--mc-brand)"
        >
          /dev/mailbox
        </.link>.
      </div>
    </div>

    <p class="mt-6 text-sm" style="color:var(--mc-text-3)">
      Didn't get it? Check spam, or <a
        href="/register"
        class="font-semibold no-underline"
        style="color:var(--mc-brand)"
      >
        start over
      </a>.
    </p>
    """
  end

  @impl true
  def handle_event("validate", %{"tenant" => params}, socket) do
    changeset =
      params
      |> Tenants.change_self_registration()
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"tenant" => params}, socket) do
    email = params |> Map.get("owner_email", "") |> String.trim()

    if LoginThrottle.registration_throttled?(email) do
      {:noreply,
       put_flash(socket, :error, "Too many attempts. Please wait a minute and try again.")}
    else
      case Tenants.register_self_service(params) do
        {:ok, %{owner: owner}} ->
          {:noreply, assign(socket, state: :sent, owner_email: owner.email)}

        {:error, changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    end
  end

  defp value_points do
    [
      "Paste any enquiry email — no customer forms",
      "Your fare policy applied to every quote",
      "Agents always approve before anything sends",
      "Invite your whole team once you're in"
    ]
  end

  # Live preview of the chosen slug; falls back to a placeholder so the URL line
  # never reads "<empty>.domain".
  defp slug_preview(slug) when is_binary(slug) do
    case slug |> String.trim() |> String.downcase() do
      "" -> "your-workspace"
      value -> value
    end
  end

  defp slug_preview(_slug), do: "your-workspace"

  defp base_domain do
    Application.get_env(:quote_assist, :tenant_base_domain, "quoteassist.mytechbytes.in")
  end

  defp local_mail_adapter? do
    Application.get_env(:quote_assist, QuoteAssist.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
