defmodule QuoteAssistWeb.App.TeamLive.Index do
  @moduledoc """
  Team & access (`/app/team`): invite members, assign roles, activate / deactivate /
  remove, and (owner-only) promote to or demote from the protected `owner` type. Gated
  by the `user:*` permissions. The `owner` type is enforced at the **query layer**
  (`Tenants.list_members_visible_to/1` excludes owners from a member), so a member —
  even one with `user:update` — can't see, edit, or act on an owner by any path. The
  last-active-owner guard and session revocation run in the context's transaction; every
  mutation is audited.
  """
  use QuoteAssistWeb, :live_view

  import QuoteAssistWeb.App.Components

  alias QuoteAssist.Tenancy
  alias QuoteAssist.Tenants
  alias QuoteAssistWeb.UserAuth

  @impl true
  def mount(_params, _session, socket) do
    UserAuth.permit!(socket.assigns.current_scope, "user:list")

    {:ok,
     socket
     |> assign(page_title: "Team", modal: nil, form: nil)
     |> load_members()}
  end

  defp load_members(socket) do
    scope = socket.assigns.current_scope

    assign(socket,
      members: Tenants.list_members_visible_to(scope),
      roles: Tenants.list_roles(scope.tenant),
      can_assign_owner: :owner in Tenancy.assignable_types_for(scope)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace flash={@flash} current_scope={@current_scope} active="team" breadcrumb="Team">
      <div class="mb-6 flex items-end justify-between gap-4">
        <div>
          <div class="text-xs font-bold uppercase tracking-widest" style="color:var(--mc-text-3)">
            Account
          </div>
          <h1
            class="mt-1.5 text-3xl font-bold tracking-tight"
            style="font-family:var(--font-display);color:var(--mc-text)"
          >
            Team &amp; access
          </h1>
          <p class="mt-1.5 text-sm" style="color:var(--mc-text-2)">
            Who can draft quotes, the role they hold, and exactly what each can do. Owners hold
            every permission and need no role.
          </p>
        </div>
        <button
          :if={can?(@current_scope, "user:create")}
          id="invite-member"
          phx-click="invite"
          class="mtb-btn mtb-btn-primary mtb-btn-sm"
        >
          <.icon name="hero-plus" class="size-4" /> Invite member
        </button>
      </div>

      <div class="mtb-card overflow-hidden">
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
                Role
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
              :for={member <- @members}
              id={"member-#{member.id}"}
              style="border-top:1px solid var(--mc-border)"
            >
              <td class="px-5 py-3 align-middle">
                <.link
                  :if={can?(@current_scope, "user:read")}
                  navigate={~p"/app/team/#{member.id}"}
                  class="text-sm font-semibold no-underline hover:underline"
                  style="color:var(--mc-text)"
                >
                  {member_name(member)}
                </.link>
                <div
                  :if={not can?(@current_scope, "user:read")}
                  class="text-sm font-semibold"
                  style="color:var(--mc-text)"
                >
                  {member_name(member)}
                </div>
                <div class="text-[11px]" style="color:var(--mc-text-3)">
                  <span class="font-mono">{member.user.email}</span>
                </div>
              </td>
              <td class="px-4 py-3 align-middle">
                <.member_type_badge type={member.type} />
              </td>
              <td class="px-4 py-3 align-middle text-sm" style="color:var(--mc-text-2)">
                {member_role_label(member)}
              </td>
              <td class="px-4 py-3 align-middle">
                <.member_active_badge active={member.active} />
              </td>
              <td class="px-4 py-3 align-middle">
                <div class="flex flex-wrap items-center justify-end gap-1.5">
                  <button
                    :if={show_edit_role?(@current_scope, member)}
                    phx-click="edit_role"
                    phx-value-id={member.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Edit role
                  </button>
                  <button
                    :if={@can_assign_owner and member.type == :member and member.active}
                    phx-click="promote"
                    phx-value-id={member.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Make owner
                  </button>
                  <button
                    :if={show_demote?(@current_scope, member)}
                    phx-click="demote"
                    phx-value-id={member.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Demote
                  </button>
                  <button
                    :if={not member.active and can?(@current_scope, "user:activate")}
                    phx-click="activate"
                    phx-value-id={member.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Reactivate
                  </button>
                  <button
                    :if={show_deactivate?(@current_scope, member)}
                    phx-click="deactivate"
                    phx-value-id={member.id}
                    class="mtb-btn mtb-btn-ghost mtb-btn-sm"
                  >
                    Deactivate
                  </button>
                  <button
                    :if={show_remove?(@current_scope, member)}
                    phx-click="remove"
                    phx-value-id={member.id}
                    class="mtb-btn mtb-btn-danger-outline mtb-btn-sm"
                  >
                    Remove
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.invite_modal :if={@modal == :invite} form={@form} roles={@roles} />
      <.role_modal
        :if={match?({:edit_role, _}, @modal) or match?({:demote, _}, @modal)}
        form={@form}
        roles={@roles}
        member={elem(@modal, 1)}
        demote={match?({:demote, _}, @modal)}
      />
      <.remove_modal :if={match?({:remove, _}, @modal)} member={elem(@modal, 1)} />
    </Layouts.workspace>
    """
  end

  attr :form, :any, required: true
  attr :roles, :list, required: true

  defp invite_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:520px">
        <div class="mtb-modal-head">
          <div>
            <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
              Invite member
            </div>
            <div class="mt-0.5 text-xs" style="color:var(--mc-text-3)">
              They'll get a link to set up their account and join this workspace.
            </div>
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

        <.form for={@form} id="invite-form" phx-change="validate" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <.input field={@form[:email]} type="email" label="Email" placeholder="agent@acme.com" />
            <.input
              field={@form[:role_id]}
              type="select"
              label="Role"
              prompt={if @roles == [], do: "Create a role first", else: "Select a role"}
              options={role_options(@roles)}
            />
          </div>
          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Sending…">
              Send invite
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :roles, :list, required: true
  attr :member, :any, required: true
  attr :demote, :boolean, required: true

  defp role_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:480px">
        <div class="mtb-modal-head">
          <div>
            <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
              {if @demote, do: "Demote to member", else: "Edit role"}
            </div>
            <div class="mt-0.5 text-xs" style="color:var(--mc-text-3)">{@member.user.email}</div>
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

        <.form for={@form} id="role-assign-form" phx-submit="save">
          <div class="mtb-modal-body space-y-1">
            <p :if={@demote} class="mb-2 text-sm" style="color:var(--mc-text-2)">
              This owner loses computed all-access and takes the role you pick.
            </p>
            <.input
              field={@form[:role_id]}
              type="select"
              label="Role"
              prompt="Select a role"
              options={role_options(@roles)}
            />
          </div>
          <div class="mtb-modal-foot">
            <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
              Cancel
            </button>
            <.button class="mtb-btn mtb-btn-primary mtb-btn-sm" phx-disable-with="Saving…">
              {if @demote, do: "Demote", else: "Save role"}
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :member, :any, required: true

  defp remove_modal(assigns) do
    ~H"""
    <div class="mtb-modal-backdrop" phx-window-keydown="close_modal" phx-key="Escape">
      <div class="mtb-modal" style="max-width:460px">
        <div class="mtb-modal-head">
          <div class="font-semibold" style="font-family:var(--font-display);font-size:1.05rem">
            Remove {@member.user.email}?
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
        <div class="mtb-modal-body">
          <p class="text-sm" style="color:var(--mc-text-2);line-height:1.55">
            This removes them from this workspace and revokes their sessions immediately. The
            record is kept (a soft delete) for the audit trail; they can be invited back later.
          </p>
        </div>
        <div class="mtb-modal-foot">
          <button type="button" phx-click="close_modal" class="mtb-btn mtb-btn-ghost mtb-btn-sm">
            Cancel
          </button>
          <button
            phx-click="confirm_remove"
            phx-value-id={@member.id}
            class="mtb-btn mtb-btn-danger mtb-btn-sm"
          >
            Remove member
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("invite", _params, socket) do
    if can?(socket.assigns.current_scope, "user:create") do
      {:noreply,
       assign(socket, modal: :invite, form: to_form(Tenants.change_member_invite(), as: :invite))}
    else
      {:noreply, denied(socket)}
    end
  end

  def handle_event("validate", %{"invite" => params}, socket) do
    changeset = Map.put(Tenants.change_member_invite(params), :action, :validate)
    {:noreply, assign(socket, form: to_form(changeset, as: :invite))}
  end

  def handle_event("edit_role", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_scope, "user:update"),
         %{type: :member} = member <- fetch(socket, id) do
      {:noreply, assign(socket, modal: {:edit_role, member}, form: role_form(member))}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, missing(socket)}
    end
  end

  def handle_event("demote", %{"id" => id}, socket) do
    with true <- socket.assigns.can_assign_owner,
         %{type: :owner} = member <- fetch(socket, id) do
      {:noreply, assign(socket, modal: {:demote, member}, form: role_form(member))}
    else
      false -> {:noreply, denied(socket)}
      _ -> {:noreply, missing(socket)}
    end
  end

  def handle_event("save", %{"invite" => params}, socket) do
    case Tenants.invite_member(socket.assigns.current_scope, params) do
      {:ok, membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invite sent to #{membership_email(socket, membership)}.")
         |> assign(modal: nil, form: nil)
         |> load_members()}

      {:error, :already_member} ->
        {:noreply, close_with_error(socket, "That person is already a member of this workspace.")}

      {:error, :role_not_found} ->
        {:noreply, close_with_error(socket, "Pick a role for the new member.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :invite))}
    end
  end

  def handle_event("save", %{"membership" => %{"role_id" => role_id}}, socket) do
    case socket.assigns.modal do
      {:edit_role, member} -> assign_role(socket, member, role_id)
      {:demote, member} -> do_demote(socket, member, role_id)
      _ -> {:noreply, socket}
    end
  end

  def handle_event("promote", %{"id" => id}, socket) do
    with true <- socket.assigns.can_assign_owner,
         %{type: :member} = member <- fetch(socket, id),
         {:ok, _} <- Tenants.promote_member(socket.assigns.current_scope, member) do
      {:noreply,
       socket |> put_flash(:info, "#{member.user.email} is now an owner.") |> load_members()}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
      _ -> {:noreply, flash_reload(socket, "Couldn't update that member.")}
    end
  end

  def handle_event("activate", %{"id" => id}, socket) do
    act(socket, id, "user:activate", &Tenants.activate_member/2, "reactivated")
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    act(socket, id, "user:deactivate", &Tenants.deactivate_member/2, "deactivated")
  end

  def handle_event("remove", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_scope, "user:delete"),
         %{} = member <- fetch(socket, id) do
      {:noreply, assign(socket, modal: {:remove, member})}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
    end
  end

  def handle_event("confirm_remove", %{"id" => id}, socket) do
    with true <- can?(socket.assigns.current_scope, "user:delete"),
         %{} = member <- fetch(socket, id),
         {:ok, _} <- Tenants.remove_member(socket.assigns.current_scope, member) do
      {:noreply,
       socket
       |> put_flash(:info, "#{member.user.email} removed.")
       |> assign(modal: nil)
       |> load_members()}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
      {:error, :last_owner} -> {:noreply, close_with_error(socket, last_owner_msg())}
      {:error, _} -> {:noreply, close_with_error(socket, "Couldn't remove that member.")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  defp act(socket, id, permission, fun, verb) do
    with true <- can?(socket.assigns.current_scope, permission),
         %{} = member <- fetch(socket, id),
         {:ok, _} <- fun.(socket.assigns.current_scope, member) do
      {:noreply, socket |> put_flash(:info, "#{member.user.email} #{verb}.") |> load_members()}
    else
      false -> {:noreply, denied(socket)}
      nil -> {:noreply, missing(socket)}
      {:error, :last_owner} -> {:noreply, flash_reload(socket, last_owner_msg())}
      {:error, _} -> {:noreply, flash_reload(socket, "Couldn't update that member.")}
    end
  end

  defp assign_role(socket, member, role_id) do
    case Tenants.update_member_role(socket.assigns.current_scope, member, %{"role_id" => role_id}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{member.user.email}'s role updated.")
         |> assign(modal: nil, form: nil)
         |> load_members()}

      {:error, :role_not_found} ->
        {:noreply, assign(socket, form: role_form(member, role_id, "pick a valid role"))}

      {:error, _} ->
        {:noreply, close_with_error(socket, "Couldn't update that role.")}
    end
  end

  defp do_demote(socket, member, role_id) do
    case Tenants.demote_owner(socket.assigns.current_scope, member, %{"role_id" => role_id}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "#{member.user.email} is now a member.")
         |> assign(modal: nil, form: nil)
         |> load_members()}

      {:error, :last_owner} ->
        {:noreply, close_with_error(socket, last_owner_msg())}

      {:error, :role_not_found} ->
        {:noreply, assign(socket, form: role_form(member, role_id, "pick a valid role"))}

      {:error, _} ->
        {:noreply, close_with_error(socket, "Couldn't demote that owner.")}
    end
  end

  # A schemaless form for the role-id select, with an optional error for live feedback.
  defp role_form(member, role_id \\ nil, error \\ nil) do
    types = %{role_id: :binary_id}
    data = {%{role_id: role_id || member.role_id}, types}

    changeset =
      data
      |> Ecto.Changeset.cast(%{}, [:role_id])
      |> then(fn cs -> if error, do: Ecto.Changeset.add_error(cs, :role_id, error), else: cs end)
      |> Map.put(:action, if(error, do: :validate, else: nil))

    to_form(changeset, as: :membership)
  end

  defp fetch(socket, id), do: Tenants.get_member_visible_to(socket.assigns.current_scope, id)

  defp membership_email(_socket, %{user: %{email: email}}), do: email
  defp membership_email(_socket, _membership), do: "the new member"

  defp denied(socket) do
    socket
    |> put_flash(:error, "You don't have permission to do that.")
    |> assign(modal: nil, form: nil)
  end

  defp missing(socket) do
    socket
    |> put_flash(:error, "That member no longer exists.")
    |> assign(modal: nil, form: nil)
    |> load_members()
  end

  defp close_with_error(socket, message) do
    socket
    |> put_flash(:error, message)
    |> assign(modal: nil, form: nil)
    |> load_members()
  end

  defp flash_reload(socket, message), do: socket |> put_flash(:error, message) |> load_members()

  defp last_owner_msg, do: "There must always be one active owner — this is the last one."

  defp role_options(roles), do: Enum.map(roles, fn role -> {role.name, role.id} end)

  # ── Per-row action visibility (permission + protected-type + self aware) ───────────

  defp show_edit_role?(scope, member) do
    member.type == :member and can?(scope, "user:update")
  end

  defp show_demote?(scope, member) do
    scope.membership.id != member.id and member.type == :owner and
      :owner in Tenancy.assignable_types_for(scope)
  end

  defp show_deactivate?(scope, member) do
    member.active and member.id != scope.membership.id and can?(scope, "user:deactivate")
  end

  defp show_remove?(scope, member) do
    member.id != scope.membership.id and can?(scope, "user:delete")
  end
end
