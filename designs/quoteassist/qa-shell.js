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
    discount: '<circle cx="9" cy="9" r="1.8"/><circle cx="15" cy="15" r="1.8"/><path d="M19 5L5 19"/>',
    approvals: '<path d="M9 11l3 3L20 6"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h10"/>',
    quotas: '<line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="2" y1="14" x2="6" y2="14"/><line x1="10" y1="8" x2="14" y2="8"/><line x1="18" y1="16" x2="22" y2="16"/>',
    sellers: '<circle cx="9" cy="8" r="3"/><path d="M3 20c.5-3.5 3-5 6-5s5.5 1.5 6 5"/><circle cx="17" cy="6" r="2"/><path d="M15 12c2.5 0 4 1 4.5 3"/>',
    agencies: '<path d="M3 21h18M5 21V7l7-4 7 4v14M9 9h.01M15 9h.01M9 13h.01M15 13h.01M9 17h6"/>',
    verticals: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    policy: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
    billing: '<rect x="2" y="5" width="20" height="14" rx="2"/><line x1="2" y1="10" x2="22" y2="10"/>',
    deals: '<path d="M14 3v4a1 1 0 0 0 1 1h4"/><path d="M17 21H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7l5 5v11a2 2 0 0 1-2 2z"/>',
    switch: '<path d="M16 3l4 4-4 4"/><path d="M20 7H9a4 4 0 0 0-4 4v0"/><path d="M8 21l-4-4 4-4"/><path d="M4 17h11a4 4 0 0 0 4-4v0"/>',
  };

  // Per-persona navigation. Legacy sales pages (no data-app) default to 'sales'
  // with the original Skyline identity, so they render exactly as before.
  const NAV = {
    sales: {
      brandTag: null,
      sections: [
        { title: 'Workspace', items: [
          ['overview', 'dashboard.html', 'Overview'],
          ['quote', 'get-quote.html', 'Get a quote'],
          ['list', 'quotes.html', 'Quotes', '8'],
          ['discount', 'apply-discount.html', 'Apply discount'],
          ['sources', 'settings.html#sources', 'Pricing sources'],
          ['analytics', 'dashboard.html', 'Analytics'],
        ] },
        { title: 'Account', items: [
          ['team', 'team.html', 'Team'],
          ['profile', 'profile.html', 'Profile'],
          ['settings', 'settings.html', 'Settings'],
        ] },
        { title: null, items: [ ['switch', 'launcher.html', 'Switch persona'] ] },
      ],
      user: { name: 'Rana Aziz', org: 'Skyline Travel · Agent', initials: 'RA' },
    },
    agency: {
      brandTag: 'Agency',
      sections: [
        { title: 'Agency', items: [
          ['overview', 'agency-dashboard.html', 'Overview'],
          ['approvals', 'agency-approvals.html', 'Approvals', '__approvals__'],
          ['quotas', 'agency-quotas.html', 'Discount quotas'],
          ['sellers', 'agency-team.html', 'Salespeople'],
        ] },
        { title: 'Account', items: [
          ['settings', 'settings.html', 'Settings'],
        ] },
        { title: null, items: [ ['switch', 'launcher.html', 'Switch persona'] ] },
      ],
      user: { name: 'Daniel Reyes', org: 'Northwind Supply · Admin', initials: 'DR' },
    },
    admin: {
      brandTag: 'Platform',
      sections: [
        { title: 'Platform', items: [
          ['overview', 'admin-dashboard.html', 'Overview'],
          ['agencies', 'admin-tenants.html', 'Agencies'],
          ['verticals', 'admin-verticals.html', 'Verticals'],
          ['policy', 'admin-policy.html', 'Discount policy'],
          ['billing', 'admin-policy.html#plans', 'Plans & billing'],
        ] },
        { title: null, items: [ ['switch', 'launcher.html', 'Switch persona'] ] },
      ],
      user: { name: 'Mara Okafor', org: 'Platform admin', initials: 'MO' },
    },
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
    const app = aside.dataset.app || 'sales';
    const cfg = NAV[app] || NAV.sales;
    const active = aside.dataset.active || '';
    const pending = (window.QAData && window.QAData.pendingCount) ? window.QAData.pendingCount(window.QAData.ACTIVE_TENANT) : 0;

    const sectionsHtml = cfg.sections.map(sec => {
      const head = sec.title ? `<div class="mc-side-section">${sec.title}</div>` : `<div style="margin-top:auto;"></div>`;
      const items = sec.items.map(it => {
        let key = it[0], href = it[1], label = it[2], extra = it[3];
        if (extra === '__approvals__') extra = pending > 0 ? String(pending) : '';
        return navItem(active, key, href, label, extra);
      }).join('');
      return head + items;
    }).join('');

    const u = {
      name: aside.dataset.user || cfg.user.name,
      org: aside.dataset.org || cfg.user.org,
      initials: aside.dataset.initials || cfg.user.initials,
    };
    const tag = cfg.brandTag ? `<span class="mc-app-tag">${cfg.brandTag}</span>` : '';
    const homeHref = cfg.sections[0].items[0][1];

    const themeBtn = `<button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost mc-side-footer-meta" data-theme-toggle aria-label="Toggle theme" title="Toggle theme">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="block dark:hidden"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="hidden dark:block"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      </button>`;
    aside.innerHTML = `
      <div class="mc-side-header">
        <a href="${homeHref}" class="flex items-center gap-2.5" style="text-decoration:none; color:inherit; min-width:0;">
          <span class="mc-logo" style="width:30px; height:30px; font-size:14px; flex-shrink:0;">QA</span>
          <span class="mc-side-brand-text flex items-center gap-2 min-w-0"><span class="font-display font-bold text-base">QuoteAssist</span>${tag}</span>
        </a>
        <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost mc-side-brand-text" data-sidebar-toggle aria-label="Collapse sidebar" title="Collapse sidebar">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
      </div>
      ${sectionsHtml}
      <div class="mc-side-footer">
        <div class="w-9 h-9 rounded-full grid place-items-center text-white text-xs font-bold flex-shrink-0" style="background: linear-gradient(135deg, var(--mc-grad-1), var(--mc-grad-2));">${u.initials}</div>
        <div class="min-w-0 flex-1 mc-side-footer-meta">
          <div class="text-sm font-semibold leading-tight truncate">${u.name}</div>
          <div class="text-[11px] truncate" style="color: var(--mc-text-3);">${u.org}</div>
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
