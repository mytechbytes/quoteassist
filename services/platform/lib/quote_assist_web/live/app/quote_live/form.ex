defmodule QuoteAssistWeb.App.QuoteLive.Form do
  @moduledoc """
  Capture / edit a quote request on a dedicated page (`/app/quotes/new`,
  `/app/quotes/:id/edit`) — ported from `designs/get-quote.html`: the customer's enquiry
  email up top, then the trip facts (route · dates · pax · total · currency) and customer
  details. (The AI extraction/pricing pipeline in the design has no backend; drafting a
  reply happens on the detail page via the AI stub.) Gated by `quote:create` (new) /
  `quote:update` (edit); saves are audited.
  """
  use QuoteAssistWeb, :live_view

  alias QuoteAssist.Quotes
  alias QuoteAssist.Quotes.QuoteRequest
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "quote:update")

    case Quotes.get_quote_request(socket.assigns.current_scope, id) do
      %QuoteRequest{} = quote ->
        {:ok, prepare(socket, :edit, quote)}

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "That quote no longer exists.")
         |> push_navigate(to: ~p"/app/quotes")}
    end
  end

  def mount(_params, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "quote:create")
    {:ok, prepare(socket, :new, %QuoteRequest{})}
  end

  defp prepare(socket, action, quote) do
    socket
    |> assign(action: action, quote: quote, page_title: page_title(action))
    |> assign_form(Quotes.change_quote_request(socket.assigns.current_scope, quote))
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp page_title(:new), do: "Get a quote"
  defp page_title(:edit), do: "Edit quote"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="quotes"
      breadcrumb={@page_title}
    >
      <.link
        navigate={back_path(@action, @quote)}
        class="mb-4 inline-flex items-center gap-1.5 text-sm"
        style="color:var(--mc-text-2)"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back
      </.link>

      <div class="mb-6">
        <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
          Workspace · {if @action == :new, do: "New quotation", else: "Edit"}
        </div>
        <h1
          class="mt-1.5 text-3xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          {@page_title}
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          Capture the customer's enquiry and the trip facts. You can draft a reply (with AI) once it's saved.
        </p>
      </div>

      <.form
        for={@form}
        id="quote-form"
        phx-change="validate"
        phx-submit="save"
        class="max-w-3xl space-y-5"
      >
        <%!-- Enquiry --%>
        <section class="mtb-card p-6">
          <label class="mtb-label">Customer email / enquiry</label>
          <.input
            field={@form[:body]}
            type="textarea"
            rows="7"
            placeholder="Paste the customer's email here — e.g. 'Hi, we're 2 adults flying London to Rome on 12 Sept returning 19 Sept, economy…'"
          />
          <div class="mt-2 grid grid-cols-1 gap-x-4 sm:grid-cols-2">
            <.input field={@form[:customer_name]} type="text" label="Customer name" />
            <.input field={@form[:customer_email]} type="email" label="Customer email" />
          </div>
          <.input
            field={@form[:subject]}
            type="text"
            label="Subject"
            placeholder="LHR → JFK, business"
          />
        </section>

        <%!-- Trip facts --%>
        <section class="mtb-card p-6">
          <h2
            class="mb-3 text-base font-bold"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Trip facts
          </h2>
          <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
            <.input field={@form[:route]} type="text" label="Route" placeholder="LHR–HND" />
            <.input
              field={@form[:travel_dates]}
              type="text"
              label="Travel dates"
              placeholder="14–28 Aug"
            />
            <.input field={@form[:pax]} type="text" label="Passengers" placeholder="2A · 2C" />
            <div class="grid grid-cols-[1fr_120px] gap-3">
              <.input field={@form[:total]} type="number" label="Total" placeholder="6150" />
              <.input
                field={@form[:currency]}
                type="select"
                label="Currency"
                options={[{"GBP · £", "GBP"}, {"EUR · €", "EUR"}, {"USD · $", "USD"}]}
              />
            </div>
          </div>
        </section>

        <div class="flex items-center gap-2">
          <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
            {if @action == :new, do: "Create quote", else: "Save changes"}
          </.button>
          <.link navigate={back_path(@action, @quote)} class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            Cancel
          </.link>
        </div>
      </.form>
    </Layouts.workspace>
    """
  end

  defp back_path(:edit, %QuoteRequest{id: id}) when is_binary(id), do: ~p"/app/quotes/#{id}"
  defp back_path(_action, _quote), do: ~p"/app/quotes"

  @impl true
  def handle_event("validate", %{"quote_request" => params}, socket) do
    changeset =
      socket.assigns.current_scope
      |> Quotes.change_quote_request(socket.assigns.quote, params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"quote_request" => params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.action do
        :new -> Quotes.create_quote_request(scope, params)
        :edit -> Quotes.update_quote_request(scope, socket.assigns.quote, params)
      end

    case result do
      {:ok, quote} ->
        {:noreply,
         socket
         |> put_flash(:info, "Quote saved.")
         |> push_navigate(to: ~p"/app/quotes/#{quote.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end
end
