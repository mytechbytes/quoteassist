// SW-02 · Add-in workspace state machine (Phase 2). Mirrors the salesperson
// workspace states shared with the LiveView app. Defined now so the contract is
// stable; the taskpane UI + Graph wiring land in Phase 2.

export type WorkspaceState =
  | "idle"
  | "reading_email"
  | "extracting"
  | "pricing"
  | "drafting"
  | "draft_ready"
  | "error";

export const transitions: Record<WorkspaceState, WorkspaceState[]> = {
  idle: ["reading_email"],
  reading_email: ["extracting", "error"],
  extracting: ["pricing", "error"],
  pricing: ["drafting", "error"],
  drafting: ["draft_ready", "error"],
  draft_ready: ["idle"],
  error: ["idle"],
};

export function canTransition(from: WorkspaceState, to: WorkspaceState): boolean {
  return transitions[from]?.includes(to) ?? false;
}
