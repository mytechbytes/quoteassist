// Taskpane controller (Phase 2 foundation). Wires the read → extract flow through
// the SW-02 workspace state machine. The DOM rendering + live MSAL/Graph calls are
// fleshed out during Phase 2 completion; this proves the pieces fit together.

import { ApiClient, newCorrelationId } from "../api/client";
import { buildConfig, tokenProvider } from "../auth/msal";
import { readSelectedEmail } from "../office/email_reader";
import { canTransition, type WorkspaceState } from "./state_machine";

declare const Office: any;

const API_BASE = "https://localhost:4000";

let state: WorkspaceState = "idle";

function setState(next: WorkspaceState): void {
  if (!canTransition(state, next)) {
    throw new Error(`illegal transition ${state} -> ${next}`);
  }
  state = next;
  document.querySelector("#qa-state")?.replaceChildren(document.createTextNode(next));
}

export async function processSelectedEmail(): Promise<void> {
  const config = buildConfig({ clientId: "TODO", tenantId: "TODO" });
  const api = new ApiClient(API_BASE, tokenProvider(config));

  try {
    setState("reading_email");
    const email = await readSelectedEmail();

    setState("extracting");
    await api.extract({
      correlation_id: newCorrelationId(),
      tenant_id: "TODO",
      channel: "email",
      source_type: "individual",
      sender_identity: email.forwardedFrom ?? email.from,
      conversation_id: email.conversationId,
      subject: email.subject,
      content: email.body,
    });

    setState("pricing");
    setState("drafting");
    setState("draft_ready");
  } catch (_err) {
    setState("error");
  }
}

Office.onReady(() => {
  document.querySelector("#qa-run")?.addEventListener("click", processSelectedEmail);
});
