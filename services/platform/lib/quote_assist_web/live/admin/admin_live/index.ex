defmodule QuoteAssistWeb.Admin.AdminLive.Index do
  @moduledoc """
  Site administrators (`/admin/admins`) — read-only. Admins are created only via
  `mix qa.create_admin` (no HTTP surface, by design), so this page lists them and
  links to each one's activity; it never creates, edits, or deletes admins.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.Admin.Components

  alias QuoteAssist.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admins", admins: Accounts.list_admins())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_admin={@current_admin} active="admins" breadcrumb="Admins">
      <div class="mb-6">
        <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
          Platform
        </div>
        <h1
          class="mt-1.5 text-3xl font-bold tracking-tight"
          style="font-family:var(--font-display);color:var(--mc-text)"
        >
          Administrators
        </h1>
        <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
          Staff with platform access. Admins are created from the command line
          (<span class="font-mono">mix qa.create_admin</span>) — there is no sign-up here by design.
        </p>
      </div>

      <div class="mtb-card overflow-hidden">
        <table class="mtb-table">
          <thead>
            <tr style="border-bottom:1px solid var(--mc-border)">
              <th class="px-5 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Administrator
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Last sign-in
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold" style="color:var(--mc-text-3)">
                Added
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={admin <- @admins} style="border-top:1px solid var(--mc-border)">
              <td class="px-5 py-3 align-middle">
                <.link
                  navigate={~p"/admin/admins/#{admin.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {admin.email}
                </.link>
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {format_datetime(admin.last_sign_in_at)}
              </td>
              <td class="px-4 py-3 align-middle font-mono text-xs" style="color:var(--mc-text-2)">
                {format_datetime(admin.inserted_at)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.admin>
    """
  end
end
