# MangoCMS · Platform UI kit

Twelve pages covering the full studio-owner experience.

## Entry points

| Path | Surface |
|---|---|
| `index.html` | Marketing home — hero, features, templates, builder showcase, pricing, CTA, footer |
| `dashboard.html` | Workspace overview — stats, traffic, activity, recent sites |
| `tenants.html` | Sites CRUD list + new-site modal + delete-confirm modal |
| `builder-page.html` | Page builder — section palette, canvas with click-to-select, properties panel |
| `builder-section.html` | Focused single-section editor — content / style / animation tabs, box-model controls |
| `profile.html` | User profile — cover, tabs, public profile, linked SSO accounts |
| `settings.html` | Workspace settings — identity, billing, domains, API keys, security, danger zone |
| `team.html` | Team members table + role legend + pending invites + invite modal |
| `auth-login.html` | Split-screen sign in |
| `auth-register.html` | 3-step signup with password strength |
| `auth-forgot.html` | Email-only reset request |
| `auth-reset.html` | New password + live requirement checklist |
| `auth-verify.html` | 6-digit OTP entry with auto-advance |

## Shared files

- `mangocms-config.js` — Tailwind CDN runtime config (mist + mango scales, Inter + Familjen Grotesk + JetBrains Mono).
- `mangocms.css` — design tokens (CSS vars that swap on `.dark`), plus component utility classes: `mc-btn`, `mc-card`, `mc-input`, `mc-label`, `mc-badge`, `mc-status`, `mc-shell`, `mc-side`, `mc-topbar`, `mc-table`, `mc-modal*`, plus helpers (`mc-logo`, `mc-grad-text`, `mc-glow`, `mc-hairline`, `mc-kbd`, `font-display`, `font-mono`).
- `mangocms-shell.js` — wires up `[data-theme-toggle]`, `[data-sidebar-toggle]`, and `[data-modal-open]`/`[data-modal-close]` once on `DOMContentLoaded`. Persists theme + sidebar state in `localStorage`.

## How to add a new page

1. Copy any `dashboard.html` or `tenants.html` as your starting point.
2. Keep the head block — fonts + Tailwind + config + `mangocms.css`.
3. Wrap your app content in `<div class="mc-shell"> <aside class="mc-side"> … </aside> <div class="min-w-0"> <header class="mc-topbar">…</header> <main class="p-8">…</main> </div> </div>`.
4. Mark the active sidebar link with `class="active"`.
5. End with `<script src="mangocms-shell.js"></script>`.

Direct edits to text are fine; the static-HTML structure means every page is direct-manipulable.
