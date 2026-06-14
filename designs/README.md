# MangoCMS Design System

**MangoCMS** is a multi-tenant CMS — think Wix for studios. One workspace, many tenant sites, each with its own theme, domain, content, members, and analytics. The platform ships with twelve free templates; **MangoBook** (a book-publisher CMS) is one of them, and it doubles as our deepest tenant-theme reference.

This design system therefore documents **two co-existing surfaces**:

| Surface | Fonts | Palette | When to use |
|---|---|---|---|
| **MangoCMS** (platform) | Inter + Familjen Grotesk | **Mist** cool-neutrals + Mango accent | Anything the studio/agency sees: marketing site, dashboard, builder, settings, auth. Light or dark theme. |
| **MangoBook** (sample tenant) | Manrope + JetBrains Mono | Warm paper + genre wheel + Mango | Internal book-publisher screens (catalog, title editor). Reference for what a fully-themed tenant site looks like. |

The Design System tab shows both worlds side-by-side. Tokens for both are in `colors_and_type.css` — namespaced `--mc-*` vs `--mb-*` so they never collide.

---

## Index

| Path | What it is |
|---|---|
| `README.md` | This document. |
| `colors_and_type.css` | All design tokens for both surfaces — paste-ready. |
| `SKILL.md` | Agent skill manifest. |
| `ui_kits/mangocms/` | **The platform UI kit** — marketing home, dashboard, builder, CRUD, auth, profile, team, settings. |
| `ui_kits/admin/` | **The MangoBook sample tenant theme** — three connected book-publisher screens, with the sidebar collapse bug fixed. |
| `preview/` | Atomic design-system cards (typography specimens, swatches, components in isolation). |

---

## MangoCMS — the platform

### Visual personality

Warm-precise. The brand color is a saturated mango orange (`oklch(58% 0.17 50)`), but it's restrained — surfaces are flat cool neutrals (the "mist" scale), and mango shows up only on CTAs, focus rings, brand badges, and the logo gradient. The result is closer to Linear/Vercel than Wix's loud full-bleed marketing pages — but the warmth keeps it from being clinical.

### Type

- **Familjen Grotesk** (700) for display: hero headlines, section titles, card titles. Tracking is always `-0.025em` or `-0.02em`. Familjen has a slight humanist warmth that pairs perfectly with the mango accent — sterile geometric sans-serifs would clash.
- **Inter** (400/500/600/700) for everything else: body, eyebrow, labels, buttons, table cells. Eyebrows are 11px / 700 / uppercase / `tracking-widest`. Labels are 12px / 600 in `mist-600`. Body is 14px / 400 — readable, neutral.
- **JetBrains Mono** (400/500) for numbers, IDs, domains, API keys, codes (e.g. the 6-digit verify-email OTP). Never body copy.

### Color

The **mist scale** (50–950, OKLCH, cool-teal) does all the neutral work. There is no "gray" — every shade has a hint of chroma at hue ~215°, which is what gives the light theme its silvery-paper feel and the dark theme its undersea quality. Roles map like so:

| Role | Light | Dark |
|---|---|---|
| `--mc-bg` | mist-100 | mist-950 |
| `--mc-surface` | white | mist-900 |
| `--mc-surface-2` | mist-50 | mist-800 |
| `--mc-border` | mist-200 | mist-800 |
| `--mc-text` | mist-900 | mist-100 |
| `--mc-text-2` | mist-600 | mist-400 |
| `--mc-brand` | mango-600 | mango-400 |

The mango ramp goes 50→900. **600 is the brand color**; 400 is the dark-mode primary swap (more luminous on dark surfaces); 50 is the hover-wash / soft chip background. The logo mark is a fixed `linear-gradient(135deg, mango-400 → mango-600)` and is the only blessed gradient surface in product chrome (marketing pages use additional radial mango glows).

### Layout & spacing

- App pages use a **two-column shell**: `260px sidebar + main`. Collapsing the sidebar (chevron button or `Cmd-\` later) drops it to a `72px` icon rail. Same pattern is back-patched into the MangoBook screens — see the **Bug fix** note below.
- Topbar is `64px`, sticky. Main content padding `p-8` (32 px).
- Cards use `mc-r-card: 16px`, modals `mc-r-modal: 20px`, buttons / inputs `mc-r-btn: 10px`, pills `99px`.
- Card padding ranges from `p-4` (compact stats) to `p-6` (default) to `p-7` (marketing feature cards).
- The marketing site is centred at `max-w-[1280px]` with `px-6` gutter; sections breathe at `py-28`.

### Backgrounds

Flat warm-cool neutrals throughout app pages — no gradients on surfaces. Marketing pages add three deliberate moments:

1. **Hero glow** — soft radial mango gradients in the background (`.mc-glow`), masked with `blur(50px)`.
2. **Grid mask** — a faint `mist-200` grid pattern under the hero, radial-masked so it fades at the edges.
3. **CTA banner** — a single `linear-gradient(135deg, mango-700, mango-800)` panel as the final pre-footer punctuation.

### Interaction & motion

- Buttons: 200ms ease on `background-color`. No transform, no scale.
- Sidebar collapse: 200ms ease on `grid-template-columns`.
- Inputs: 150ms ease on `border-color` + `box-shadow` for the focus ring.
- Modals: snap (no animation in this version).
- Hover states are subtle washes — `var(--mc-surface-2)` on ghosts, `mango-700` on primary buttons, `mango-soft` on active sidebar items.

### Iconography

Outlined SVG icons, 24×24 viewBox, `stroke-width: 2` (2.5 for chevrons/plus/check), round caps and joins. The set is hand-authored to match Lucide's metrics — see `preview/brand-iconography.html`. No icon font ships. Emoji is not used in product UI; on the marketing site, status indicators use unicode dots (`●`) and delta arrows (`▲ ▼`).

### Logo mark

A 32–40px rounded square (`rounded-xl` / `rounded-2xl`) filled with `linear-gradient(135deg, mango-400 → mango-600)`, with a single white `M` in Familjen Grotesk 700. The wordmark sits inline next to the mark when full identity presence is needed.

### CONTENT FUNDAMENTALS

**Voice.** Studio-confident, slightly editorial. Marketing copy speaks to an agency owner who's been around: _"Ship your client's site by Friday."_ — _"A visual editor that doesn't fight you."_ — _"One CMS. Every brand. Every site."_ App copy is direct and second-person: _"Good morning, Harper."_, _"You're about to permanently remove …"_, _"You have 16 seats left."_

**Casing.** Sentence case everywhere except eyebrows / column headers / form labels (UPPERCASE + tracking-widest). Buttons are sentence case ("New site", "Save changes"). Never title case.

**Punctuation.** Em dash (—) for emphasis, middle dot (·) for meta strings ("Studio Renza · Owner"), arrows (→) on action links. Numbers always in `JetBrains Mono` via the `font-mono` class.

**Tone moments.**
- **Empty states** carry a teaser, not "TBA": _"Citrus & Co. · drinkcitrus.shop · Pending DNS"_.
- **Danger zone** is short and firm: _"This action cannot be undone."_ / _"Type the site name to confirm."_
- **Pricing copy** is plain-spoken: _"$0/mo — For trying it out."_ / _"$49/mo — For agencies running <30 sites."_

---

## MangoBook — sample tenant theme

The three book-publisher screens (`ui_kits/admin/MangoBook-Admin.html`, `Catalog.html`, `Edit-Title.html`) demonstrate what a fully-themed MangoCMS tenant looks like: its own font stack (Manrope + JetBrains Mono), its own daisyUI custom theme (`mango` light / `midnight` dark), its own genre-color wheel, and a signature book-cover motif.

Treat MangoBook tokens (`--mb-*`) and components as **theme-scoped, not platform-scoped** — they apply only inside a tenant that uses the MangoBook template.

### CONTENT FUNDAMENTALS (MangoBook)

Editorial-operational. _"Good morning, Harper"_ · _"All books currently signed to MangoBook · across print, digital, and audio"_. Numbers and IDs always in JetBrains Mono. Status pills use a 6-px dot + colored text rather than fills.

See the **README sections still living in MangoBook** below for the deep visual foundations.

### Bug fix · sidebar collapse

In the uploaded MangoBook screens, the chevron button on the icon rail (and the matching one in the section-nav header) had no behavior. **Fixed across all three files** — a small inline `<script>` + `<style>` block:

- Section-nav `chevron-left` → adds `html.sb-collapsed`; main grid becomes `grid-cols-[72px_1fr]` and the 240-px aside is hidden.
- Icon-rail `chevron-right` (title="Expand") → removes the class; full sidebar returns.
- State persists in `localStorage` under `mb-sb-collapsed`.

The MangoCMS platform uses the same protocol (`.mc-shell.collapsed`) for its own sidebar collapse — they share the mental model so the two surfaces feel cousined.

---

## ICONOGRAPHY (shared)

Both surfaces use the same outlined-SVG iconography (24×24, stroke 2/2.5, round caps). No icon font. The MangoCMS marketing site adds a small set of brand monograms (Google, GitHub, Twitter, LinkedIn) in filled form for SSO/footer use only.

**Substitution path:** if you need an icon that isn't in `preview/brand-iconography.html`, load Lucide from CDN — its stroke weights match. Avoid Heroicons (lighter weight, different metric grid) and Phosphor (rounder corners).

---

## File layout cheatsheet

```
.
├── README.md
├── colors_and_type.css         # both --mc-* and --mb-* tokens
├── SKILL.md
├── preview/                    # design-system cards (atomic specimens)
│   ├── _card.css
│   ├── type-* / colors-* / spacing-* / comp-* / brand-*   # MangoBook
│   └── mc-type-* / mc-colors-* / mc-comp-*                # MangoCMS
├── ui_kits/
│   ├── mangocms/               # ── PLATFORM kit ──
│   │   ├── README.md
│   │   ├── mangocms.css                  # shared component classes + theme
│   │   ├── mangocms-config.js            # Tailwind CDN runtime config
│   │   ├── mangocms-shell.js             # theme toggle + sidebar collapse + modal helpers
│   │   ├── index.html                    # marketing home
│   │   ├── dashboard.html
│   │   ├── tenants.html                  # sites CRUD
│   │   ├── builder-page.html
│   │   ├── builder-section.html
│   │   ├── auth-login.html / auth-register.html
│   │   ├── auth-forgot.html / auth-reset.html / auth-verify.html
│   │   ├── profile.html
│   │   ├── settings.html
│   │   └── team.html
│   └── admin/                  # ── MANGOBOOK sample tenant ──
│       ├── README.md
│       ├── MangoBook-Admin.html
│       ├── MangoBook-Catalog.html
│       └── MangoBook-Edit-Title.html
```

---

## Open questions / caveats

- **Light mode is the only fully-built theme.** Dark tokens exist and are wired (toggle on dashboard sidebar footer, on auth-login top bar). I've spot-checked but not exhaustively reviewed every page in dark.
- **No real imagery** — covers are placeholder gradients, logos in the marquee are typographic stand-ins. Drop real assets into `ui_kits/mangocms/assets/` and swap the placeholders.
- **The page builder is a static mock.** Sections are clickable to select but not draggable. If you want drag-drop / inline text editing, that's the next prototype.
- **Eight of the twelve "free templates"** referenced on the marketing page don't exist as comps yet (only MangoBook does). Worth shooting a couple more if templates are a hero capability.
