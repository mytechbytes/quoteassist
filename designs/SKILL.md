---
name: mangocms-design
description: Use this skill to generate well-branded interfaces and assets for MangoCMS, a multi-tenant CMS platform (think Wix for studios), or for one of its tenant themes (MangoBook is the sample provided). Contains tokens, fonts, a 12-page platform UI kit, and a 3-page tenant theme reference.
user-invocable: true
---

Read `README.md` first — it explains the two co-existing surfaces (MangoCMS the platform and MangoBook the sample tenant theme) and which tokens to use when.

Then explore:
- `colors_and_type.css` — drop-in tokens for both surfaces. Platform tokens are `--mc-*`; tenant-theme tokens are `--mb-*`.
- `ui_kits/mangocms/` — the **platform** UI kit. 12 connected pages, three shared files (`mangocms.css` / `mangocms-config.js` / `mangocms-shell.js`). Start at `index.html` or `dashboard.html`.
- `ui_kits/admin/` — the **MangoBook** sample tenant theme (publishing CMS). 3 screens, daisyUI-based.
- `preview/*.html` — atomic design-system cards.

**When the user asks for new platform UI** (anything inside MangoCMS itself — admin screens, builder additions, marketing pages):
- Use Inter + Familjen Grotesk.
- Use the mist scale for neutrals and the mango accent for brand.
- Compose from `mc-*` component classes in `mangocms.css`. Never invent new colors outside the scales; never pick a different display font.
- Wrap app pages in `.mc-shell` so the sidebar-collapse behavior works automatically.

**When the user asks for new MangoBook tenant UI** (or a different tenant theme styled after MangoBook):
- Use Manrope + JetBrains Mono.
- Use the warm paper neutrals and the genre wheel.
- Follow the patterns in `ui_kits/admin/` — daisyUI custom theme + the cover motif + gradient avatars.

**When the user asks for a NEW tenant theme** (one of the "twelve free templates" mentioned on the marketing home but not yet built — Atelier, Citrus, Northbrand, Lemon Press, Sundial, Orbit, etc):
- Ask which template they want first.
- The template names + descriptions are in `ui_kits/mangocms/index.html` (Templates section) and `tenants.html` (modal). Pick a font pair and color palette that fits the theme's positioning; do not reuse the mango brand for a tenant — the tenant should look like its own brand, not like MangoCMS.

**Hard rules.**
- No emoji in product UI; allowed sparingly in marketing if it serves a point.
- Numbers are always set in `JetBrains Mono` via `.font-mono` (platform) or `.num-mono` (MangoBook).
- The sidebar-collapse pattern is a real, working contract — it's wired in both surfaces. When you add a new app page, include the collapse button in its sidebar header.
- Iconography is hand-authored outlined SVG (24×24, stroke 2/2.5, round caps), or Lucide as a stand-in. No icon font.
