# QuoteAssist Outlook add-in (stub)

Office.js add-in that runs the same lead → quote → draft flow as the web app,
against a selected email. **Phase 2 deliverable** — this directory is a Phase-0
stub so the monorepo structure and CI are coherent.

## What's here now

- `manifest.xml` — manifest v2 / `ReadWriteItem` skeleton (placeholder GUID/URLs).
- `src/taskpane/state_machine.ts` — the SW-02 workspace state machine, shared in
  spirit with the LiveView app.
- `package.json` / `tsconfig.json` — typecheck-only build for now.

## Phase 2 will add

- MSAL auth (silent refresh, popup fallback, in-memory tokens) — CC-05/06.
- Email reader module (subject/sender/conversationId/itemId/attachments) +
  forwarded-email detection.
- Typed API client sharing the `shared/contracts` boundary types.
- Vite dev server (https://localhost:3000) + esbuild/vite production build.
- Entra app registration + redirect URIs.

## Develop

```sh
npm install
npm run typecheck
```
