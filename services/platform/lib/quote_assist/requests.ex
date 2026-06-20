defmodule QuoteAssist.Requests do
  @moduledoc """
  The generic tenant request inbox (RELEASE_PLAN.md, R7-rbac). A member raises a request
  (`request:create`, baseline) — `:leave` is the first type; a `request:manage` holder
  approves / declines it, and the requester may cancel their own open one. Approving a
  `:leave` removes the requester's membership through the normal `user:delete` path
  (subject to the last-active-owner guard).

  Every transition is audited (actor = user, subtype = owner | member). Tenant-scoped
  and membership-scoped throughout: `requested_by` / `resolved_by` are membership ids.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias QuoteAssist.Accounts.Scope
  alias QuoteAssist.Audit
  alias QuoteAssist.Repo
  alias QuoteAssist.Tenants
  alias QuoteAssist.Tenants.{Membership, Request, Tenant}

  @preloads [requested_by_membership: :user, resolved_by_membership: :user]

  @doc "Live requests for a tenant, newest first, with requester + resolver preloaded (the inbox)."
  def list_requests(%Tenant{} = tenant) do
    Repo.all(
      from r in tenant_requests(tenant),
        order_by: [desc: r.inserted_at, desc: r.id],
        preload: ^@preloads
    )
  end

  @doc "A member's own live requests, newest first."
  def list_requests_for_member(%Membership{} = membership) do
    Repo.all(
      from r in live_requests(),
        where: r.tenant_id == ^membership.tenant_id and r.requested_by == ^membership.id,
        order_by: [desc: r.inserted_at, desc: r.id],
        preload: ^@preloads
    )
  end

  @doc "A live request within a tenant by id (with associations), or nil. Safe for untrusted ids."
  def get_request(%Tenant{} = tenant, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.one(from r in tenant_requests(tenant), where: r.id == ^uuid, preload: ^@preloads)

      :error ->
        nil
    end
  end

  @doc "Whether the membership already has an open request of `type` (gates the raise UI)."
  def has_open_request?(%Membership{} = membership, type) when is_atom(type) do
    Repo.exists?(
      from r in live_requests(),
        where:
          r.tenant_id == ^membership.tenant_id and r.requested_by == ^membership.id and
            r.type == ^type and r.status == :open
    )
  end

  @doc "Changeset backing the raise-request form."
  def change_request(%Request{} = request \\ %Request{}, attrs \\ %{}) do
    Request.create_changeset(request, attrs)
  end

  @doc """
  Raises a request as `scope`'s member (`request:create`, baseline). `tenant_id` and
  `requested_by` come from the scope, never the form. The DB partial-unique index caps
  it at one open request per type per member (surfaced as a changeset error on `:type`).
  Audited.
  """
  def create_request(%Scope{} = scope, attrs) do
    membership = scope.membership

    changeset =
      %Request{tenant_id: scope.tenant.id, requested_by: membership.id}
      |> Request.create_changeset(attrs)

    Repo.transact(fn ->
      with {:ok, request} <- Repo.insert(changeset) do
        audit(scope, "request.created", request, %{"type" => to_string(request.type)})
        {:ok, request}
      end
    end)
  end

  @doc """
  Cancels the requester's own open request. Refuses a request the actor didn't raise
  (`:not_owner`) and an illegal transition (`:invalid_transition`). Audited.
  """
  def cancel_request(%Scope{} = scope, %Request{} = request) do
    if request.requested_by == scope.membership.id do
      resolve(scope, request, :cancelled, scope.membership.id, %{}, "request.cancelled")
    else
      {:error, :not_owner}
    end
  end

  @doc """
  Declines a request (`request:manage`), recording the resolver + resolution note.
  Audited.
  """
  def decline_request(%Scope{} = scope, %Request{} = request, resolution) do
    resolve(
      scope,
      request,
      :declined,
      scope.membership.id,
      %{"resolution" => resolution},
      "request.declined"
    )
  end

  @doc """
  Approves a request (`request:manage`). For a `:leave` this also removes the
  requester's membership (the normal `user:delete` path, last-active-owner guard
  applies) in the same transaction — so a failed removal rolls the approval back.
  Audited.
  """
  # `Ecto.Multi.t/0` is opaque and wraps a `MapSet`; piping `Multi.new/0` into
  # `Multi.run/3` makes Dialyzer read that MapSet structurally and emit a spurious
  # `call_without_opaque`. The code is correct (a well-known Ecto.Multi false
  # positive), so scope a `:no_opaque` suppression to just this function.
  @dialyzer {:no_opaque, approve_request: 3}

  def approve_request(%Scope{} = scope, %Request{type: :leave} = request, resolution) do
    Multi.new()
    |> Multi.run(:resolved, fn _repo, _ ->
      apply_transition(request, :approved, scope.membership.id, %{"resolution" => resolution})
    end)
    |> Multi.run(:removed, fn _repo, _ ->
      case Tenants.get_membership(scope.tenant, request.requested_by) do
        %Membership{} = member -> Tenants.remove_member(scope, member)
        nil -> {:error, :requester_gone}
      end
    end)
    |> Multi.run(:audit, fn _repo, %{resolved: resolved} ->
      audit(scope, "request.approved", resolved, %{"type" => to_string(resolved.type)})
      {:ok, :audited}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{resolved: resolved}} -> {:ok, resolved}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  # ── Internals ──────────────────────────────────────────────────────────────────────

  defp resolve(scope, request, new_status, resolved_by, attrs, action) do
    Repo.transact(fn ->
      with {:ok, resolved} <- apply_transition(request, new_status, resolved_by, attrs) do
        audit(scope, action, resolved, %{"type" => to_string(resolved.type)})
        {:ok, resolved}
      end
    end)
  end

  defp apply_transition(request, new_status, resolved_by, attrs) do
    request
    |> Request.resolve_changeset(new_status, attrs)
    |> Ecto.Changeset.put_change(:resolved_by, resolved_by)
    |> Repo.update()
  end

  defp tenant_requests(%Tenant{id: tenant_id}) do
    from r in live_requests(), where: r.tenant_id == ^tenant_id
  end

  defp live_requests, do: from(r in Request, where: is_nil(r.deleted_at))

  defp audit(%Scope{} = scope, action, %Request{} = request, metadata) do
    Audit.log(%{
      actor_type: :user,
      actor_subtype: scope.membership.type,
      actor_id: scope.user.id,
      tenant_id: scope.tenant.id,
      action: action,
      target_type: "request",
      target_id: request.id,
      metadata: metadata
    })
  end
end
