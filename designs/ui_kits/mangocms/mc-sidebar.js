// MangoCMS — shared sidebar renderer.
// Each page declares an <aside class="mc-side" data-mount data-active="ID" data-tenant="NAME"></aside>
// and includes this script before mangocms-shell.js. The aside is filled in at parse time
// (synchronously) so DOMContentLoaded bindings in shell.js still wire up correctly.

(function(){
  const I = {
    dashboard: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></svg>',
    sites:    '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15 15 0 0 1 0 20M12 2a15 15 0 0 0 0 20"/></svg>',
    team:     '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><circle cx="9" cy="8" r="3"/><path d="M3 20c.5-3.5 3-5 6-5s5.5 1.5 6 5"/><circle cx="17" cy="6" r="2"/><path d="M15 12c2.5 0 4 1 4.5 3"/></svg>',
    bell:     '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg>',
    clock:    '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
    doc:      '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="9" y1="13" x2="15" y2="13"/><line x1="9" y1="17" x2="13" y2="17"/></svg>',
    grid:     '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
    image:    '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/></svg>',
    db:       '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v6c0 1.66 4 3 9 3s9-1.34 9-3V5"/><path d="M3 11v6c0 1.66 4 3 9 3s9-1.34 9-3v-6"/></svg>',
    users:    '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><circle cx="12" cy="8" r="4"/><path d="M4 21c1-4.5 4-7 8-7s7 2.5 8 7"/></svg>',
    shield:   '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><path d="M12 2 4 5v7c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5z"/><path d="m9 12 2 2 4-4"/></svg>',
    user:     '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><circle cx="12" cy="8" r="4"/><path d="M4 21c1-4.5 4-7 8-7s7 2.5 8 7"/></svg>',
    cog:      '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mc-side-icon"><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="9"/></svg>',
  };

  const NAV = {
    workspace: [
      { id: 'dashboard',     label: 'Overview',      href: 'dashboard.html',      icon: 'dashboard' },
      { id: 'sites',         label: 'Sites',         href: 'tenants.html',        icon: 'sites', counter: 12 },
      { id: 'team',          label: 'Team',          href: 'team.html',           icon: 'team' },
      { id: 'notifications', label: 'Notifications', href: 'notifications.html',  icon: 'bell', counter: 3 },
      { id: 'audit',         label: 'Audit log',     href: 'audit.html',          icon: 'clock' },
    ],
    content: [
      { id: 'pages',       label: 'Pages',       href: 'pages.html',        icon: 'doc' },
      { id: 'sections',    label: 'Sections',    href: 'sections.html',     icon: 'grid' },
      { id: 'media',       label: 'Media',       href: 'media.html',        icon: 'image' },
      { id: 'collections', label: 'Collections', href: 'collections.html',  icon: 'db' },
      { id: 'users',       label: 'Site users',  href: 'users.html',        icon: 'users' },
    ],
    access: [
      { id: 'roles', label: 'Roles & permissions', href: 'roles.html', icon: 'shield' },
    ],
    account: [
      { id: 'profile',  label: 'Profile',  href: 'profile.html',  icon: 'user' },
      { id: 'settings', label: 'Settings', href: 'settings.html', icon: 'cog' },
    ],
  };

  const item = (it, active) => `
    <a href="${it.href}"${active === it.id ? ' class="active"' : ''}>
      ${I[it.icon] || ''}
      <span class="mc-side-label">${it.label}</span>
      ${it.counter ? `<span class="mc-side-counter">${it.counter}</span>` : ''}
    </a>`;

  document.querySelectorAll('aside.mc-side[data-mount]').forEach(side => {
    const active = side.dataset.active || '';
    const tenant = side.dataset.tenant || 'MangoBook';

    side.innerHTML = `
      <div class="mc-side-header">
        <a href="dashboard.html" class="flex items-center gap-2.5" style="text-decoration:none; color:inherit;">
          <span class="mc-logo" style="width:30px; height:30px; font-size:15px;">M</span>
          <span class="font-display font-bold text-base mc-side-brand-text">MangoCMS</span>
        </a>
        <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost mc-side-brand-text" data-sidebar-toggle aria-label="Toggle sidebar">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
      </div>
      <div class="mc-side-section">Workspace</div>
      ${NAV.workspace.map(i => item(i, active)).join('')}
      <div class="mc-side-section">Content · <span style="color: var(--mc-text-2); text-transform: none; letter-spacing: 0;">${tenant}</span></div>
      ${NAV.content.map(i => item(i, active)).join('')}
      <div class="mc-side-section">Access</div>
      ${NAV.access.map(i => item(i, active)).join('')}
      <div class="mc-side-section">Account</div>
      ${NAV.account.map(i => item(i, active)).join('')}
      <div class="mc-side-footer">
        <div class="w-9 h-9 rounded-full grid place-items-center text-white text-xs font-bold flex-shrink-0" style="background: linear-gradient(135deg, oklch(0.74 0.16 60), oklch(0.58 0.17 50));">HN</div>
        <div class="min-w-0 flex-1 mc-side-brand-text">
          <div class="text-sm font-semibold leading-tight truncate">Harper Nelson</div>
          <div class="text-[11px] truncate" style="color: var(--mc-text-3);">Studio Renza · Owner</div>
        </div>
        <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost mc-side-brand-text" data-theme-toggle aria-label="Toggle theme">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="block dark:hidden"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="hidden dark:block"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
        </button>
      </div>`;
  });
})();
