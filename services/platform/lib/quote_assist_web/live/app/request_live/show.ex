defmodule QuoteAssistWeb.App.RequestLive.Show do
  @moduledoc """
  Request detail (`/app/requests/:id`): a request's type, status, the requester's note,
  the owner's resolution, and the request's activity feed. Gated by `request:read`.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Audit
  alias QuoteAssist.Requests
  alias QuoteAssist.Tenants.Request
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "request:read")
    {:ok, load(socket, id)}
  end

  defp load(socket, id) do
    case Requests.get_request(socket.assigns.current_scope.tenant, id) do
      %Request{} = request ->
        assign(socket,
          page_title: Request.type_label(request.type),
          request: request,
          logs: Audit.list_for_target("request", request.id)
        )

      nil ->
        socket
        |> put_flash(:error, "That request no longer exists.")
        |> push_navigate(to: ~p"/app/requests")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      flash={@flash}
      current_scope={@current_scope}
      active="requests"
      breadcrumb={Request.type_label(@request.type)}
    >
      <div class="mb-6">
        <.link
          navigate={~p"/app/requests"}
          class="text-xs font-semibold"
          style="color:var(--mc-text-3)"
        >
          ← Requests
        </.link>
        <div class="mt-1.5 flex items-center gap-3">
          <h1
            class="text-2xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            {Request.type_label(@request.type)}
          </h1>
          <.request_status_badge status={@request.status} />
        </div>
        <div class="mt-1 text-sm" style="color:var(--mc-text-3)">
          Raised by <span class="font-mono">{requester_email(@request)}</span>
        </div>
      </div>

      <div class="grid gap-6 lg:grid-cols-[1.2fr_1fr]">
        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Details</div>
          <dl class="space-y-3">
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Requester's note
              </dt>
              <dd class="mt-0.5 text-sm" style="color:var(--mc-text)">{@request.note || "—"}</dd>
            </div>
            <div>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Resolution
              </dt>
              <dd class="mt-0.5 text-sm" style="color:var(--mc-text)">
                {@request.resolution || "—"}
              </dd>
            </div>
            <div :if={@request.resolved_at}>
              <dt class="text-xs font-semibold uppercase tracking-wide" style="color:var(--mc-text-3)">
                Resolved
              </dt>
              <dd class="mt-0.5 font-mono text-sm" style="color:var(--mc-text)">
                {format_datetime(@request.resolved_at)}
              </dd>
            </div>
          </dl>
        </div>

        <div class="mtb-card p-6">
          <div class="mb-4 font-semibold" style="font-family:var(--font-display)">Activity</div>
          <.audit_timeline logs={@logs} empty="No activity for this request yet." />
        </div>
      </div>
    </Layouts.workspace>
    """
  end

  defp requester_email(%Request{requested_by_membership: %{user: %{email: email}}}), do: email
  defp requester_email(_request), do: "—"
end
