// QuoteAssist — shared shell behaviors + sidebar renderer + tweak application.
// Auto-applies on load; pages only need an <aside class="mc-side" data-nav
// data-active="..."> element and the standard topbar/buttons.

(function () {
  'use strict';

  /* ───────────────── Accent + radius presets (Tweaks) ───────────────── */
  const ACCENTS = {
    teal: {
      light: { brand: 'oklch(57% 0.115 192)', hover: 'oklch(49% 0.10 193)', soft: 'oklch(96% 0.03 188)', g1: 'oklch(72% 0.13 188)', g2: 'oklch(50% 0.105 192)' },
      dark:  { brand: 'oklch(74% 0.13 188)',  hover: 'oklch(80% 0.11 188)', soft: 'oklch(27.5% 0.011 216.9)', g1: 'oklch(80% 0.12 186)', g2: 'oklch(60% 0.13 191)' },
    },
    ocean: {
      light: { brand: 'oklch(55% 0.15 250)', hover: 'oklch(47% 0.14 250)', soft: 'oklch(96% 0.03 250)', g1: 'oklch(70% 0.15 245)', g2: 'oklch(50% 0.15 255)' },
      dark:  { brand: 'oklch(72% 0.14 248)', hover: 'oklch(80% 0.12 248)', soft: 'oklch(27.5% 0.011 216.9)', g1: 'oklch(78% 0.13 245)', g2: 'oklch(60% 0.15 252)' },
    },
    violet: {
      light: { brand: 'oklch(55% 0.18 290)', hover: 'oklch(47% 0.16 290)', soft: 'oklch(96% 0.04 290)', g1: 'oklch(70% 0.16 295)', g2: 'oklch(50% 0.17 288)' },
      dark:  { brand: 'oklch(74% 0.15 290)', hover: 'oklch(80% 0.13 290)', soft: 'oklch(27.5% 0.011 216.9)', g1: 'oklch(80% 0.13 295)', g2: 'oklch(62% 0.16 288)' },
    },
    mango: {
      light: { brand: 'oklch(58% 0.17 50)', hover: 'oklch(50% 0.16 48)', soft: 'oklch(97% 0.025 70)', g1: 'oklch(74% 0.16 60)', g2: 'oklch(58% 0.17 50)' },
      dark:  { brand: 'oklch(74% 0.16 60)', hover: 'oklch(82% 0.12 60)', soft: 'oklch(27.5% 0.011 216.9)', g1: 'oklch(80% 0.14 62)', g2: 'oklch(62% 0.17 52)' },
    },
  };
  const RADII = {
    rounded: { card: '16px', btn: '10px', input: '10px', modal: '20px' },
    soft:    { card: '22px', btn: '13px', input: '12px', modal: '26px' },
    sharp:   { card: '8px',  btn: '6px',  input: '7px',  modal: '12px' },
  };

  function get(k, d) { try { return localStorage.getItem(k) ?? d; } catch (e) { return d; } }
  function set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  function applyAccent(name) {
    const a = ACCENTS[name] || ACCENTS.teal;
    const dark = document.documentElement.classList.contains('dark');
    const mode = dark ? a.dark : a.light;
    const s = document.documentElement.style;
    s.setProperty('--mc-brand', mode.brand);
    s.setProperty('--mc-brand-hover', mode.hover);
    s.setProperty('--mc-brand-soft', mode.soft);
    s.setProperty('--mc-brand-ring', `color-mix(in oklch, ${mode.brand} 22%, transparent)`);
    s.setProperty('--mc-grad-1', mode.g1);
    s.setProperty('--mc-grad-2', mode.g2);
    // daisyUI primary sync (raw "L C H" triple) — harmless on non-daisyUI pages
    s.setProperty('--p', mode.brand.replace(/oklch\(|\)/g, ''));
    s.setProperty('--pc', dark ? '18% 0.02 200' : '100% 0 0');
  }
  function applyRadius(name) {
    const r = RADII[name] || RADII.rounded;
    const s = document.documentElement.style;
    s.setProperty('--mc-r-card', r.card);
    s.setProperty('--mc-r-btn', r.btn);
    s.setProperty('--mc-r-input', r.input);
    s.setProperty('--mc-r-modal', r.modal);
  }

  function applyTheme(t) {
    document.documentElement.classList.toggle('dark', t === 'dark');
    document.documentElement.dataset.theme = t === 'dark' ? 'quoteassist-dark' : 'quoteassist';
    set('qa-theme', t);
    applyAccent(get('qa-accent', 'teal')); // re-pick light/dark accent variant
    document.querySelectorAll('[data-theme-toggle]').forEach(b => { b.dataset.themeState = t; });
  }
  function getTheme() { return get('qa-theme', 'light'); }

  // ── restore ASAP, before paint ──
  document.documentElement.classList.toggle('dark', getTheme() === 'dark');
  document.documentElement.dataset.theme = getTheme() === 'dark' ? 'quoteassist-dark' : 'quoteassist';
  applyAccent(get('qa-accent', 'teal'));
  applyRadius(get('qa-radius', 'rounded'));

  // expose for the Tweaks panel
  window.QA = {
    ACCENTS, RADII, applyAccent, applyRadius, applyTheme,
    setAccent(n) { set('qa-accent', n); applyAccent(n); },
    setRadius(n) { set('qa-radius', n); applyRadius(n); },
    getState() { return { accent: get('qa-accent', 'teal'), radius: get('qa-radius', 'rounded'), theme: getTheme() }; },
  };

  /* ───────────────── Sidebar collapse ───────────────── */
  function applyCollapse(c) {
    document.querySelectorAll('.mc-shell').forEach(s => s.classList.toggle('collapsed', c));
    set('qa-sb-collapsed', c ? '1' : '0');
  }
  function getCollapsed() { return get('qa-sb-collapsed', '0') === '1'; }

  /* ───────────────── Sidebar markup ───────────────── */
  const ic = {
    overview: '<rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/>',
    quote: '<path d="M12 3l1.9 4.7L19 9l-4 3.3 1.2 5.2L12 15l-4.2 2.5L9 12.3 5 9l5.1-1.3z"/>',
    list: '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/>',
    sources: '<ellipse cx="12" cy="6" rx="8" ry="3"/><path d="M4 6v6c0 1.7 3.6 3 8 3s8-1.3 8-3V6"/><path d="M4 12v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6"/>',
    team: '<circle cx="9" cy="8" r="3"/><path d="M3 20c.5-3.5 3-5 6-5s5.5 1.5 6 5"/><circle cx="17" cy="6" r="2"/><path d="M15 12c2.5 0 4 1 4.5 3"/>',
    profile: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4.5 4-7 8-7s7 2.5 8 7"/>',
    settings: '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="9"/>',
    analytics: '<path d="M3 3v18h18"/><path d="M7 14l4-4 4 4 5-5"/>',
  };
  function svg(p) {
    return `<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon">${p}</svg>`;
  }
  function navItem(active, key, href, label, extra) {
    const cls = active === key ? ' class="active"' : '';
    const counter = extra ? `<span class="mc-side-counter">${extra}</span>` : '';
    return `<a href="${href}"${cls}>${svg(ic[key])}<span class="mc-side-label">${label}</span>${counter}</a>`;
  }
  function renderSidebar(aside) {
    const active = aside.dataset.active || '';
    const themeBtn = `<button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost mc-side-footer-meta" data-theme-toggle aria-label="Toggle theme" title="Toggle theme">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="block dark:hidden"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="hidden dark:block"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      </button>`;
    aside.innerHTML = `
      <div class="mc-side-header">
        <a href="dashboard.html" class="flex items-center gap-2.5" style="text-decoration:none; color:inherit;">
          <span class="mc-logo" style="width:30px; height:30px; font-size:14px;">QA</span>
          <span class="font-display font-bold text-base mc-side-brand-text">QuoteAssist</span>
        </a>
        <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost mc-side-brand-text" data-sidebar-toggle aria-label="Collapse sidebar" title="Collapse sidebar">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
      </div>

      <div class="mc-side-section">Workspace</div>
      ${navItem(active, 'overview', 'dashboard.html', 'Overview')}
      ${navItem(active, 'quote', 'get-quote.html', 'Get a quote')}
      ${navItem(active, 'list', 'quotes.html', 'Quotes', '8')}
      ${navItem(active, 'sources', 'settings.html#sources', 'Pricing sources')}
      ${navItem(active, 'analytics', 'dashboard.html', 'Analytics')}

      <div class="mc-side-section">Account</div>
      ${navItem(active, 'team', 'team.html', 'Team')}
      ${navItem(active, 'profile', 'profile.html', 'Profile')}
      ${navItem(active, 'settings', 'settings.html', 'Settings')}

      <div class="mc-side-footer">
        <div class="w-9 h-9 rounded-full grid place-items-center text-white text-xs font-bold flex-shrink-0" style="background: linear-gradient(135deg, var(--mc-grad-1), var(--mc-grad-2));">RA</div>
        <div class="min-w-0 flex-1 mc-side-footer-meta">
          <div class="text-sm font-semibold leading-tight truncate">Rana Aziz</div>
          <div class="text-[11px] truncate" style="color: var(--mc-text-3);">Skyline Travel · Agent</div>
        </div>
        ${themeBtn}
      </div>`;
  }

  /* ───────────────── Wire up on DOM ready ───────────────── */
  function wire() {
    document.querySelectorAll('aside.mc-side[data-nav]').forEach(renderSidebar);
    applyCollapse(getCollapsed());

    document.querySelectorAll('[data-theme-toggle]').forEach(b => {
      b.dataset.themeState = getTheme();
      b.addEventListener('click', () => applyTheme(getTheme() === 'dark' ? 'light' : 'dark'));
    });
    document.querySelectorAll('[data-sidebar-toggle]').forEach(b => {
      b.addEventListener('click', () => {
        const shell = document.querySelector('.mc-shell');
        if (shell) applyCollapse(!shell.classList.contains('collapsed'));
      });
    });
    document.querySelectorAll('[data-modal-open]').forEach(b => {
      b.addEventListener('click', () => {
        const m = document.getElementById(b.getAttribute('data-modal-open'));
        if (m) m.style.display = 'grid';
      });
    });
    document.querySelectorAll('[data-modal-close]').forEach(b => {
      b.addEventListener('click', () => {
        const m = b.closest('.mc-modal-backdrop');
        if (m) m.style.display = 'none';
      });
    });
    document.querySelectorAll('.mc-modal-backdrop').forEach(bd => {
      bd.addEventListener('click', e => { if (e.target === bd) bd.style.display = 'none'; });
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wire);
  else wire();
})();
