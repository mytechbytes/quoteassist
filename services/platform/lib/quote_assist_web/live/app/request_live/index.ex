defmodule QuoteAssistWeb.App.RequestLive.Index do
  @moduledoc """
  Tenant requests (`/app/requests`) — the generic member→owner inbox (R7-rbac), with
  `:leave` as the first type. Every member can raise a request (`request:create`,
  baseline) and cancel their own open one; a `request:manage` holder approves /
  declines, and approving a `:leave` removes the requester's membership. The "all
  requests" inbox is shown only to `request:list` holders; raising + own requests are
  available to everyone. No page-level gate — the baseline lets any member in.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Requests
  alias QuoteAssist.Tenants.Request

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Requests", modal: nil, form: nil) |> load()}
  end

  defp load(socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:my_requests, Requests.list_requests_for_member(scope.membership))
    |> assign(:has_open_leave, Requests.has_open_request?(scope.membership, :leave))
    |> assign(
      :inbox,
      if(can?(scope, "request:list"), do: Requests.list_requests(scope.tenant), else: nil)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="requests"
      breadcrumb="Requests"
    >
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Account
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Requests
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Ask an owner to action something. Leaving the workspace is owner-mediated — raise a
            request and an owner approves it.
          </p>
        </div>
        <button
          :if={not @has_open_leave}
          id="raise-leave"
          phx-click="raise"
          class="mtb-btn mtb-btn-secondary mtb-btn-sm"
        >
          <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Request to leave
        </button>
      </div>

      <section class="mb-8">
        <h2 class="mb-3 text-sm font-bold uppercase tracking-wide" style="color:var(--mc-text-3)">
          Your requests
        </h2>
        <p :if={@my_requests == []} class="text-sm" style="color:var(--mc-text-3)">
          You haven't raised any requests.
        </p>
        <div :if={@my_requests != []} class="mtb-card overflow-hidden">
          <table class="mtb-table">
            <tbody>
              <tr
                :for={req <- @my_requests}
                id={"my-request-#{req.id}"}
                style="border-top:1px solid var(--mc-border)"
              >
                <td class="px-5 py-3 align-middle">
                  <div class="text-sm font-semibold" style="color:var(--mc-text)">
                    {Request.type_label(req.type)}
                  </div>
                  <div :if={req.note} class="text-[11px]" style="color:var(--mc-text-3)">
                    {req.note}
                  </div>
                </td>
                <td class="px-4 py-3 align-middle"><.request_status_badge status={req.status} /></td>
                <td class="px-4 py-3 align-middle text-right">
                  <div class="flex items-center justify-end gap-1.5">
                    <.link
                      :if={can?(@current_scope, "request:read")}
                      navigate={~p"/app/requests/#{req.id}"}
                      class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                    >
                      View
                    </.link>
                    <button
                      :if={req.status == :open}
                      phx-click="cancel"
                      phx-value-id={req.id}
                      class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                    >
                      Cancel
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section :if={@inbox} id="request-inbox">
        <h2 class="mb-3 text-sm font-bold uppercase tracking-wide" style="color:var(--mc-text-3)">
          All requests
        </h2>
        <p :if={@inbox == []} class="text-sm" style="color:var(--mc-text-3)">No requests yet.</p>
        <div :if={@inbox != []} class="mtb-card overflow-hidden">
          <table class="mtb-table">
            <thead>
              <tr style="border-bottom:1px solid var(--mc-border)">
                <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                  Member
                </th>
                <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                  Type
                </th>
                <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                  Status
                </th>
                <th class="px-4 py-3 text-right text-xs font-semibold" style="color:var(--mc-text-3)">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                :for={req <- @inbox}
                id={"inbox-request-#{req.id}"}
                style="border-top:1px solid var(--mc-border)"
              >
                <td class="px-5 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                  {requester_email(req)}
                </td>
                <td class="px-4 py-3 align-middle text-sm" style="color:var(--mc-text-2)">
                  {Request.type_label(req.type)}
                </td>
                <td class="px-4 py-3 align-middle"><.request_status_badge status={req.status} /></td>
                <td class="px-4 py-3 align-middle">
                  <div class="flex items-center justify-end gap-1.5">
                    <.link
                      :if={can?(@current_scope, "request:read")}
                      navigate={~p"/app/requests/#{req.id}"}
                      class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                    >
                      View
                    </.link>
                    <button
                      :if={req.status == :open and can?(@current_scope, "request:manage")}
                      phx-click="approve"
                      phx-value-id={req.id}
                      class="mtb-btn mtb-btn-primary mtb-btn-sm"
                    >
                      Approve
                    </button>
                    <button
                      :if={req.status == :open and can?(@current_scope, "request:manage")}
                      phx-click="decline"
                      phx-value-id={req.id}
                      class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                    >
                      Decline
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <.raise_modal :if={@modal == :raise} form={@form} />
      <.resolve_modal :if={match?({:resolve, _, _}, @modal)} modal={@modal} />
    </Layouts.workspace>
    """
  end

  attr :form, :any, required: true

  defp raise_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:520px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            Request to leave
          </div>
          <button
            type="button"
            phx-click="close_modal"
            class="mtb-btn mtb-btn-sm mtb-btn-icon mtb-btn-ghost"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
        <.form for={@form} id="request-form" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <p class="mb-2 text-sm" style="color:var(--mc-text-2)">
              An owner will review this. They'll remove you from the workspace if approved.
            </p>
            <.input field={@form[:note]} type="textarea" label="Note (optional)" />
          </div>
          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Sending…">
              Raise request
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :modal, :any, required: true

  defp resolve_modal(assigns) do
    {:resolve, action, request} = assigns.modal
    assigns = assign(assigns, action: action, request: request)

    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:480px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            {if @action == :approve, do: "Approve request", else: "Decline request"}
          </div>
          <button
            type="button"
            phx-click="close_modal"
            class="mtb-btn mtb-btn-sm mtb-btn-icon mtb-btn-ghost"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
        <form id="resolve-form" phx-submit="confirm_resolve">
          <input type="hidden" name="request_id" value={@request.id} />
          <input type="hidden" name="action" value={@action} />
          <div class="mtb-modal-body space-y-2">
            <p :if={@action == :approve} class="text-sm" style="color:var(--mc-text-2)">
              Approving removes {requester_email(@request)} from this workspace.
            </p>
            <label class="mtb-label">Resolution note (optional)</label>
            <textarea name="resolution" class="mtb-input" rows="3"></textarea>
          </div>
          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <button
              type="submit"
              class={[
                "mtb-btn mtb-btn-sm",
                if(@action == :approve, do: "mtb-btn-primary", else: "mtb-btn-danger")
              ]}
            >
              {if @action == :approve, do: "Approve & remove", else: "Decline"}
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("raise", _params, socket) do
    if can?(socket.assigns.current_scope, "request:create") do
      {:noreply,
       assign(socket, modal: :raise, form: to_form(Requests.change_request(), as: :request))}
    else
      {:noreply, put_flash(socket, :error, "You can't raise requests.")}
    end
  end

  def handle_event("save", %{"request" => params}, socket) do
    params = Map.put(params, "type", "leave")

    case Requests.create_request(socket.assigns.current_scope, params) do
      {:ok, _request} ->
        {:noreply,
         socket |> put_flash(:info, "Request raised.") |> assign(modal: nil, form: nil) |> load()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :request))}
    end
  end

  def handle_event("cancel", %{"id" => id}, socket) do
    with %Request{} = request <- fetch(socket, id),
         {:ok, _} <- Requests.cancel_request(socket.assigns.current_scope, request) do
      {:noreply, socket |> put_flash(:info, "Request cancelled.") |> load()}
    else
      nil -> {:noreply, missing(socket)}
      {:error, _} -> {:noreply, flash_reload(socket, "Couldn't cancel that request.")}
    end
  end

  def handle_event("approve", %{"id" => id}, socket), do: open_resolve(socket, id, :approve)
  def handle_event("decline", %{"id" => id}, socket), do: open_resolve(socket, id, :decline)

  def handle_event("confirm_resolve", %{"request_id" => id, "action" => action} = params, socket) do
    resolution = params["resolution"] || ""

    with true <- can?(socket.assigns.current_scope, "request:manage"),
         %Request{} = request <- fetch(socket, id),
         {:ok, _} <- resolve(socket.assigns.current_scope, request, action, resolution) do
      {:noreply,
       socket
       |> put_flash(:info, "Request #{past_tense(action)}.")
       |> assign(modal: nil)
       |> load()}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
      {:error, _} -> {:noreply, flash_reload(socket, "Couldn't update that request.")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  defp open_resolve(socket, id, action) do
    with true <- can?(socket.assigns.current_scope, "request:manage"),
         %Request{status: :open} = request <- fetch(socket, id) do
      {:noreply, assign(socket, modal: {:resolve, action, request})}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, missing(socket)}
    end
  end

  defp resolve(scope, request, "approve", resolution),
    do: Requests.approve_request(scope, request, resolution)

  defp resolve(scope, request, "decline", resolution),
    do: Requests.decline_request(scope, request, resolution)

  defp past_tense("approve"), do: "approved"
  defp past_tense("decline"), do: "declined"

  defp fetch(socket, id), do: Requests.get_request(socket.assigns.current_scope.tenant, id)

  defp requester_email(%Request{requested_by_membership: %{user: %{email: email}}}), do: email
  defp requester_email(_request), do: "—"

  defp denied(socket) do
    socket |> put_flash(:error, "You don't have permission to do that.") |> assign(modal: nil)
  end

  defp missing(socket) do
    socket |> put_flash(:error, "That request no longer exists.") |> assign(modal: nil) |> load()
  end

  defp flash_reload(socket, message),
    do: socket |> put_flash(:error, message) |> assign(modal: nil) |> load()
end
