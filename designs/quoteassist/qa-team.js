// QuoteAssist — Team & access. Members / Roles / Permissions, each on the
// shared list engine (qa-listkit.js) with search + filter/sort + view + paging.

(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };

  /* ───────────────── permission catalog ───────────────── */
  var PERM_GROUPS = [
    { group: 'Quotes', items: [
      { k: 'quotes.view',   l: 'View quotes' },
      { k: 'quotes.create', l: 'Create quotes' },
      { k: 'quotes.edit',   l: 'Edit quotes' },
      { k: 'quotes.send',   l: 'Send to customer' },
      { k: 'quotes.export', l: 'Export CSV' },
      { k: 'quotes.delete', l: 'Delete quotes' }
    ] },
    { group: 'Pricing', items: [
      { k: 'pricing.view',    l: 'View pricing sources' },
      { k: 'pricing.policy',  l: 'Edit fare policy' },
      { k: 'pricing.sources', l: 'Manage pricing sources' }
    ] },
    { group: 'Team & access', items: [
      { k: 'team.view',   l: 'View team' },
      { k: 'team.invite', l: 'Invite members' },
      { k: 'team.roles',  l: 'Manage roles & permissions' },
      { k: 'team.remove', l: 'Remove members' }
    ] },
    { group: 'Settings', items: [
      { k: 'settings.view',    l: 'View settings' },
      { k: 'settings.edit',    l: 'Edit settings' },
      { k: 'settings.billing', l: 'Manage billing' }
    ] }
  ];
  var GROUP_NAMES = PERM_GROUPS.map(function (g) { return g.group; });
  var ALL_PERMS = [], PERM_FLAT = [];
  PERM_GROUPS.forEach(function (g) { g.items.forEach(function (i) { ALL_PERMS.push(i.k); PERM_FLAT.push({ k: i.k, l: i.l, group: g.group }); }); });
  function permsFromList(list) { var o = {}; list.forEach(function (k) { o[k] = true; }); return o; }
  function allOn() { return permsFromList(ALL_PERMS); }

  function defaults() {
    return {
      roles: [
        { id: 'owner',  name: 'Owner',        desc: 'Full control of the workspace, billing and access.', builtin: true, perms: allOn() },
        { id: 'lead',   name: 'Team lead',    desc: 'Runs the desk: pricing, members and every quote.',   builtin: true, perms: permsFromList(ALL_PERMS.filter(function (k) { return k !== 'settings.billing'; })) },
        { id: 'senior', name: 'Senior agent', desc: 'Full quoting plus fare-policy tuning.',               builtin: true, perms: permsFromList(['quotes.view','quotes.create','quotes.edit','quotes.send','quotes.export','quotes.delete','pricing.view','pricing.policy','team.view','settings.view']) },
        { id: 'agent',  name: 'Agent',        desc: 'Drafts and sends quotes from enquiries.',             builtin: true, perms: permsFromList(['quotes.view','quotes.create','quotes.edit','quotes.send','quotes.export','pricing.view','team.view','settings.view']) },
        { id: 'viewer', name: 'Viewer',       desc: 'Read-only access for auditors and observers.',        builtin: true, perms: permsFromList(['quotes.view','pricing.view','team.view','settings.view']) }
      ],
      members: [
        { id: 'm1', name: 'Rana Aziz',       email: 'rana@skylinetravel.com',  role: 'owner',  quotes: 41, active: 'now',        hue: 'brand', you: true },
        { id: 'm2', name: 'Diego Moss',      email: 'diego@skylinetravel.com', role: 'senior', quotes: 38, active: '12 min ago', hue: 230 },
        { id: 'm3', name: 'Sara Aboud',      email: 'sara@skylinetravel.com',  role: 'agent',  quotes: 29, active: '1 h ago',    hue: 150 },
        { id: 'm4', name: 'Yara Kovač',      email: 'yara@skylinetravel.com',  role: 'agent',  quotes: 22, active: '3 h ago',    hue: 290 },
        { id: 'm5', name: 'Elena Marchetti', email: 'elena@skylinetravel.com', role: 'lead',   quotes: 17, active: 'yesterday',  hue: 30 }
      ],
      pending: [
        { id: 'p1', email: 'tom@skylinetravel.com',   role: 'agent', ago: '2 days ago' },
        { id: 'p2', email: 'nadia@skylinetravel.com', role: 'agent', ago: '4 days ago' }
      ]
    };
  }

  var DB = load();
  function load() { try { var s = JSON.parse(localStorage.getItem('qa-team')); if (s && s.roles && s.members) return s; } catch (e) {} return defaults(); }
  function save() { try { localStorage.setItem('qa-team', JSON.stringify(DB)); } catch (e) {} }
  function uid(p) { return p + Math.random().toString(36).slice(2, 8); }

  function role(id) { return DB.roles.filter(function (r) { return r.id === id; })[0]; }
  function roleName(id) { var r = role(id); return r ? r.name : '—'; }
  function memberCount(rid) { return DB.members.filter(function (m) { return m.role === rid; }).length; }
  function permCount(r) { return ALL_PERMS.filter(function (k) { return r.perms[k]; }).length; }
  function rolesWith(k) { return DB.roles.filter(function (r) { return r.perms[k]; }); }
  function initials(n) { return n.trim().split(/\s+/).map(function (w) { return w[0]; }).slice(0, 2).join('').toUpperCase(); }
  function avatar(m, size) {
    size = size || 32;
    var bg = m.hue === 'brand' ? 'linear-gradient(135deg,var(--mc-grad-1),var(--mc-grad-2))' : 'linear-gradient(135deg,oklch(0.74 0.16 ' + m.hue + '),oklch(0.5 0.14 ' + m.hue + '))';
    var fs = size <= 32 ? 'text-xs' : 'text-sm';
    return '<div class="rounded-full grid place-items-center text-white font-bold flex-shrink-0 ' + fs + '" style="width:' + size + 'px;height:' + size + 'px;background:' + bg + ';">' + initials(m.name) + '</div>';
  }
  function roleBadge(rid) { return '<span class="mc-badge ' + (rid === 'owner' ? 'mc-badge-brand' : 'mc-badge-neutral') + '">' + roleName(rid) + '</span>'; }
  var dots = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="12" cy="19" r="1.4"/></svg>';
  var plus = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>';

  /* ───────────────── controllers ───────────────── */
  var ctrlMembers, ctrlRoles, ctrlPerms;
  function refreshAll() { if (ctrlMembers) ctrlMembers.refresh(); if (ctrlRoles) ctrlRoles.refresh(); if (ctrlPerms) ctrlPerms.refresh(); renderPending(); updateSeats(); }
  function updateSeats() { var s = $('#seatCount'); if (s) s.textContent = DB.members.length + ' of 20 seats used'; }

  /* ---- members ---- */
  function memberRowMenuBtn(m) { return '<button class="mc-btn mc-btn-sm mc-btn-ghost mc-btn-icon qa-rowmenu" data-id="' + m.id + '">' + dots + '</button>'; }
  function mViewTable(items) {
    var rows = items.map(function (m) {
      return '<tr><td><div class="flex items-center gap-3">' + avatar(m) +
        '<div><div class="font-semibold text-sm">' + m.name + (m.you ? ' <span class="text-xs font-normal" style="color:var(--mc-text-3);">(you)</span>' : '') + '</div><div class="text-[11px]" style="color:var(--mc-text-3);">' + m.email + '</div></div></div></td>' +
        '<td>' + roleBadge(m.role) + '</td><td class="font-mono text-xs">' + m.quotes + '</td>' +
        '<td class="text-xs" style="color:var(--mc-text-2);">' + m.active + '</td>' +
        '<td class="text-right">' + memberRowMenuBtn(m) + '</td></tr>';
    }).join('');
    return '<div class="mc-card overflow-hidden"><table class="mc-table"><thead><tr><th>Member</th><th>Role</th><th>Quotes · 30d</th><th>Last active</th><th></th></tr></thead><tbody>' + rows + '</tbody></table></div>';
  }
  function mViewCards(items) {
    return '<div class="qa-cardgrid">' + items.map(function (m) {
      return '<div class="qa-dcard"><div class="flex items-start justify-between gap-2">' +
        '<div class="flex items-center gap-3 min-w-0">' + avatar(m, 42) +
        '<div class="min-w-0"><div class="font-semibold text-sm truncate">' + m.name + (m.you ? ' <span class="text-xs font-normal" style="color:var(--mc-text-3);">(you)</span>' : '') + '</div><div class="text-[11px] truncate" style="color:var(--mc-text-3);">' + m.email + '</div></div></div>' +
        memberRowMenuBtn(m) + '</div>' +
        '<div class="flex items-center justify-between mt-4 pt-3" style="border-top:1px solid var(--mc-border);">' + roleBadge(m.role) +
        '<span class="text-xs" style="color:var(--mc-text-3);"><b style="color:var(--mc-text);">' + m.quotes + '</b> quotes · 30d</span></div></div>';
    }).join('') + '</div>';
  }
  function mViewList(items) {
    return '<div class="qa-listwrap">' + items.map(function (m) {
      return '<div class="qa-listrow">' + avatar(m) +
        '<div style="flex:1; min-width:0;"><div class="text-sm font-semibold truncate">' + m.name + (m.you ? ' <span class="text-xs font-normal" style="color:var(--mc-text-3);">(you)</span>' : '') + '</div><div class="text-[11px] truncate" style="color:var(--mc-text-3);">' + m.email + '</div></div>' +
        '<span style="width:120px;">' + roleBadge(m.role) + '</span>' +
        '<span class="font-mono text-xs" style="width:44px; text-align:right; color:var(--mc-text-2);">' + m.quotes + '</span>' +
        '<span class="text-xs" style="width:90px; text-align:right; color:var(--mc-text-3);">' + m.active + '</span>' +
        memberRowMenuBtn(m) + '</div>';
    }).join('') + '</div>';
  }
  function bindMemberMenus(body) {
    body.querySelectorAll('.qa-rowmenu').forEach(function (b) { b.addEventListener('click', function (e) { e.stopPropagation(); openMemberMenu(b, b.dataset.id); }); });
  }
  function renderPending() {
    var wrap = $('#pendingWrap'); if (!wrap) return;
    if (!DB.pending.length) { wrap.innerHTML = ''; return; }
    wrap.innerHTML = '<div class="mc-card overflow-hidden"><div class="p-5 border-b font-display font-bold text-base" style="border-color:var(--mc-border);">Pending invites · ' + DB.pending.length + '</div>' +
      '<table class="mc-table"><tbody>' + DB.pending.map(function (p) {
        return '<tr><td><div class="text-sm font-medium">' + p.email + '</div><div class="text-[11px]" style="color:var(--mc-text-3);">Invited ' + p.ago + ' · ' + roleName(p.role) + '</div></td>' +
          '<td>' + roleBadge(p.role) + '</td><td><span class="mc-status mc-status-build">Pending</span></td>' +
          '<td class="text-right"><button class="mc-btn mc-btn-sm mc-btn-ghost qa-resend" data-id="' + p.id + '">Resend</button><button class="mc-btn mc-btn-sm mc-btn-ghost qa-revoke" data-id="' + p.id + '" style="color:var(--mc-error);">Revoke</button></td></tr>';
      }).join('') + '</tbody></table></div>';
    wrap.querySelectorAll('.qa-revoke').forEach(function (b) { b.addEventListener('click', function () { DB.pending = DB.pending.filter(function (p) { return p.id !== b.dataset.id; }); save(); renderPending(); toast('Invite revoked.'); }); });
    wrap.querySelectorAll('.qa-resend').forEach(function (b) { b.addEventListener('click', function () { toast('Invite resent.'); }); });
  }

  /* ---- roles ---- */
  function roleCardMenuBtn(r) { return '<button class="mc-btn mc-btn-sm mc-btn-ghost mc-btn-icon qa-role-menu" data-id="' + r.id + '">' + dots + '</button>'; }
  function rViewCards(items) {
    return '<div class="qa-cardgrid">' + items.map(function (r) {
      var mc = memberCount(r.id);
      return '<div class="qa-dcard"><div class="flex items-start justify-between gap-3">' +
        '<div><div class="flex items-center gap-2"><span class="font-display font-bold text-base" style="white-space:nowrap;">' + r.name + '</span>' +
        (r.builtin ? '<span class="mc-badge mc-badge-neutral">Built-in</span>' : '<span class="mc-badge mc-badge-brand">Custom</span>') + '</div>' +
        '<p class="text-xs mt-1" style="color:var(--mc-text-3); max-width:42ch;">' + r.desc + '</p></div>' + roleCardMenuBtn(r) + '</div>' +
        '<div class="flex items-center gap-4 mt-4 pt-3" style="border-top:1px solid var(--mc-border);">' +
        '<span class="text-xs" style="color:var(--mc-text-2);"><b style="color:var(--mc-text);">' + mc + '</b> member' + (mc === 1 ? '' : 's') + '</span>' +
        '<span class="text-xs" style="color:var(--mc-text-2);"><b style="color:var(--mc-text);">' + permCount(r) + '</b> / ' + ALL_PERMS.length + ' permissions</span>' +
        '<button class="mc-btn mc-btn-sm mc-btn-ghost qa-edit-perms" data-id="' + r.id + '" style="margin-left:auto; color:var(--mc-brand);">Edit permissions →</button></div></div>';
    }).join('') + '</div>';
  }
  function rViewTable(items) {
    var rows = items.map(function (r) {
      var mc = memberCount(r.id);
      return '<tr><td><div class="font-semibold text-sm">' + r.name + '</div><div class="text-[11px]" style="color:var(--mc-text-3); max-width:44ch;">' + r.desc + '</div></td>' +
        '<td>' + (r.builtin ? '<span class="mc-badge mc-badge-neutral">Built-in</span>' : '<span class="mc-badge mc-badge-brand">Custom</span>') + '</td>' +
        '<td class="font-mono text-xs">' + mc + '</td><td class="font-mono text-xs">' + permCount(r) + ' / ' + ALL_PERMS.length + '</td>' +
        '<td><div class="qa-role-acts"><button class="mc-btn mc-btn-sm mc-btn-ghost qa-edit-perms" data-id="' + r.id + '" style="color:var(--mc-brand);">Edit</button>' + roleCardMenuBtn(r) + '</div></td></tr>';
    }).join('');
    return '<div class="mc-card overflow-hidden"><table class="mc-table"><thead><tr><th>Role</th><th>Type</th><th>Members</th><th>Permissions</th><th></th></tr></thead><tbody>' + rows + '</tbody></table></div>';
  }
  function rViewList(items) {
    return '<div class="qa-listwrap">' + items.map(function (r) {
      var mc = memberCount(r.id);
      return '<div class="qa-listrow"><div style="flex:1; min-width:0;"><div class="flex items-center gap-2"><span class="font-semibold text-sm">' + r.name + '</span>' +
        (r.builtin ? '<span class="mc-badge mc-badge-neutral">Built-in</span>' : '<span class="mc-badge mc-badge-brand">Custom</span>') + '</div>' +
        '<div class="text-[11px] truncate" style="color:var(--mc-text-3);">' + r.desc + '</div></div>' +
        '<span class="text-xs" style="width:90px; text-align:right; color:var(--mc-text-2);">' + mc + ' member' + (mc === 1 ? '' : 's') + '</span>' +
        '<span class="text-xs" style="width:80px; text-align:right; color:var(--mc-text-2);">' + permCount(r) + '/' + ALL_PERMS.length + '</span>' +
        '<button class="mc-btn mc-btn-sm mc-btn-ghost qa-edit-perms" data-id="' + r.id + '" style="color:var(--mc-brand);">Edit</button>' + roleCardMenuBtn(r) + '</div>';
    }).join('') + '</div>';
  }
  function bindRoleControls(body) {
    body.querySelectorAll('.qa-role-menu').forEach(function (b) { b.addEventListener('click', function (e) { e.stopPropagation(); openRoleMenu(b, b.dataset.id); }); });
    body.querySelectorAll('.qa-edit-perms').forEach(function (b) { b.addEventListener('click', function () { openRole(role(b.dataset.id)); }); });
  }

  /* ---- permissions ---- */
  function pViewTable(items) {
    var heads = DB.roles.map(function (r) { return '<th class="qa-mx-role"><div class="qa-mx-rolename">' + r.name + '</div><div class="qa-mx-rolemeta">' + permCount(r) + '/' + ALL_PERMS.length + '</div></th>'; }).join('');
    var lastGroup = null, body = '';
    items.forEach(function (i) {
      if (i.group !== lastGroup) { body += '<tr class="qa-mx-grouprow"><td class="qa-mx-grouphead" colspan="' + (DB.roles.length + 1) + '">' + i.group + '</td></tr>'; lastGroup = i.group; }
      var cells = DB.roles.map(function (r) {
        var on = !!r.perms[i.k], lock = r.id === 'owner';
        return '<td class="qa-mx-cell"><button class="qa-tick' + (on ? ' on' : '') + (lock ? ' lock' : '') + '" data-role="' + r.id + '" data-perm="' + i.k + '"' + (lock ? ' disabled' : '') + '>' +
          (on ? '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>' : '') + '</button></td>';
      }).join('');
      body += '<tr><td class="qa-mx-perm">' + i.l + '</td>' + cells + '</tr>';
    });
    return '<div class="mc-card overflow-hidden"><div class="qa-mx-scroll"><table class="qa-mx"><thead><tr><th class="qa-mx-perm qa-mx-corner">Permission</th>' + heads + '</tr></thead><tbody>' + body + '</tbody></table></div></div>';
  }
  function roleChips(i) {
    return DB.roles.map(function (r) { return '<span class="qa-rolechip' + (r.perms[i.k] ? '' : ' off') + '">' + r.name + '</span>'; }).join('');
  }
  function pViewList(items) {
    return '<div class="qa-listwrap">' + items.map(function (i) {
      var on = rolesWith(i.k);
      return '<div class="qa-perm-row"><div class="qa-perm-main"><div class="qa-perm-name">' + i.l + '</div><div class="qa-perm-grp">' + i.group + '</div></div>' +
        '<div class="qa-perm-roles">' + (on.length ? on.map(function (r) { return '<span class="qa-rolechip">' + r.name + '</span>'; }).join('') : '<span class="qa-perm-none">No roles</span>') + '</div></div>';
    }).join('') + '</div>';
  }
  function pViewCards(items) {
    return '<div class="qa-cardgrid">' + items.map(function (i) {
      return '<div class="qa-dcard"><div class="qa-perm-grp">' + i.group + '</div><div class="font-semibold text-sm mt-1.5 mb-3">' + i.l + '</div>' +
        '<div class="flex flex-wrap gap-1.5">' + roleChips(i) + '</div></div>';
    }).join('') + '</div>';
  }
  function bindPermTicks(body) {
    body.querySelectorAll('.qa-tick:not(.lock)').forEach(function (b) {
      b.addEventListener('click', function () {
        var r = role(b.dataset.role);
        if (r.perms[b.dataset.perm]) delete r.perms[b.dataset.perm]; else r.perms[b.dataset.perm] = true;
        save(); ctrlPerms.refresh(); if (ctrlRoles) ctrlRoles.refresh();
      });
    });
  }

  /* ───────────────── kebab menus ───────────────── */
  function openMemberMenu(anchor, id) {
    closeMenu();
    var m = DB.members.filter(function (x) { return x.id === id; })[0];
    var menu = document.createElement('div'); menu.className = 'qa-menu'; menu.id = 'qaMenu';
    menu.innerHTML = '<button data-a="edit">Edit member</button><button data-a="role">Change role</button>' +
      (m.you ? '' : '<div class="qa-menu-sep"></div><button data-a="remove" class="danger">Remove from team</button>');
    document.body.appendChild(menu);
    placeMenu(menu, anchor);
    menu.querySelector('[data-a="edit"]').onclick = function () { closeMenu(); openMember(m); };
    menu.querySelector('[data-a="role"]').onclick = function () { closeMenu(); openMember(m, true); };
    var rm = menu.querySelector('[data-a="remove"]'); if (rm) rm.onclick = function () { closeMenu(); confirmRemove(m); };
    armMenu();
  }
  function openRoleMenu(anchor, id) {
    closeMenu();
    var r = role(id), mc = memberCount(id), canDelete = !r.builtin && mc === 0;
    var menu = document.createElement('div'); menu.className = 'qa-menu'; menu.id = 'qaMenu';
    menu.innerHTML = '<button data-a="edit">Edit role</button><button data-a="dupe">Duplicate</button><div class="qa-menu-sep"></div>' +
      '<button data-a="del" class="danger"' + (canDelete ? '' : ' disabled') + '>' + (r.builtin ? "Built-in · can't delete" : (mc ? "In use · can't delete" : 'Delete role')) + '</button>';
    document.body.appendChild(menu);
    placeMenu(menu, anchor);
    menu.querySelector('[data-a="edit"]').onclick = function () { closeMenu(); openRole(r); };
    menu.querySelector('[data-a="dupe"]').onclick = function () { closeMenu(); DB.roles.push({ id: uid('r'), name: r.name + ' copy', desc: r.desc, builtin: false, perms: JSON.parse(JSON.stringify(r.perms)) }); save(); refreshAll(); toast('Role duplicated.'); };
    var del = menu.querySelector('[data-a="del"]'); if (canDelete) del.onclick = function () { closeMenu(); confirmDeleteRole(r); };
    armMenu();
  }
  function placeMenu(menu, anchor) { var r = anchor.getBoundingClientRect(); menu.style.top = (r.bottom + 4) + 'px'; menu.style.left = Math.max(12, r.right - menu.offsetWidth) + 'px'; }
  function armMenu() { setTimeout(function () { document.addEventListener('mousedown', menuOutside); window.addEventListener('resize', closeMenu); }, 0); }
  function closeMenu() { var m = $('#qaMenu'); if (m) m.remove(); document.removeEventListener('mousedown', menuOutside); window.removeEventListener('resize', closeMenu); }
  function menuOutside(e) { var m = $('#qaMenu'); if (m && !m.contains(e.target) && !e.target.closest('.qa-rowmenu') && !e.target.closest('.qa-role-menu')) closeMenu(); }

  /* ───────────────── modals ───────────────── */
  function roleOptions(sel) { return DB.roles.map(function (r) { return '<option value="' + r.id + '"' + (r.id === sel ? ' selected' : '') + '>' + r.name + '</option>'; }).join(''); }
  function modal(html, max) {
    var bd = document.createElement('div'); bd.className = 'mc-modal-backdrop'; bd.style.display = 'grid'; bd.style.zIndex = '130';
    bd.innerHTML = '<div class="mc-modal" style="max-width:' + (max || 480) + 'px;">' + html + '</div>';
    document.body.appendChild(bd);
    bd.addEventListener('click', function (e) { if (e.target === bd) bd.remove(); });
    bd.querySelectorAll('[data-close]').forEach(function (b) { b.addEventListener('click', function () { bd.remove(); }); });
    return bd;
  }
  function head(title, sub) {
    return '<div class="mc-modal-head"><div><div class="font-display font-bold text-lg">' + title + '</div>' + (sub ? '<div class="text-xs mt-0.5" style="color:var(--mc-text-3);">' + sub + '</div>' : '') + '</div>' +
      '<button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-close aria-label="Close"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6L6 18M6 6l12 12"/></svg></button></div>';
  }
  function openInvite() {
    var bd = modal(head('Invite a member', "They'll get an email to join Skyline Travel.") +
      '<div class="mc-modal-body"><label class="mc-label">Email address</label><input class="mc-input mb-4" id="iv-email" placeholder="colleague@skylinetravel.com"/>' +
      '<label class="mc-label">Role</label><select class="mc-input mc-select" id="iv-role">' + roleOptions('agent') + '</select>' +
      '<div class="text-xs mt-3" style="color:var(--mc-text-3);">Role permissions are managed under the Roles &amp; Permissions tabs.</div></div>' +
      '<div class="mc-modal-foot"><button class="mc-btn mc-btn-sm mc-btn-ghost" data-close>Cancel</button><button class="mc-btn mc-btn-sm mc-btn-primary" id="iv-send">Send invite</button></div>');
    $('#iv-send', bd).onclick = function () { var email = $('#iv-email', bd).value.trim(); if (!email) { $('#iv-email', bd).focus(); return; } DB.pending.push({ id: uid('p'), email: email, role: $('#iv-role', bd).value, ago: 'just now' }); save(); bd.remove(); renderPending(); toast('Invite sent to ' + email + '.'); };
  }
  function openMember(m, focusRole) {
    var bd = modal(head('Edit member', m.email) +
      '<div class="mc-modal-body"><label class="mc-label">Full name</label><input class="mc-input mb-4" id="me-name" value="' + m.name + '"/>' +
      '<label class="mc-label">Email address</label><input class="mc-input mb-4" id="me-email" value="' + m.email + '"/>' +
      '<label class="mc-label">Role</label><select class="mc-input mc-select" id="me-role">' + roleOptions(m.role) + '</select></div>' +
      '<div class="mc-modal-foot"><button class="mc-btn mc-btn-sm mc-btn-ghost" data-close>Cancel</button><button class="mc-btn mc-btn-sm mc-btn-primary" id="me-save">Save changes</button></div>');
    if (focusRole) $('#me-role', bd).focus();
    $('#me-save', bd).onclick = function () { m.name = $('#me-name', bd).value.trim() || m.name; m.email = $('#me-email', bd).value.trim() || m.email; m.role = $('#me-role', bd).value; save(); bd.remove(); refreshAll(); toast('Member updated.'); };
  }
  function confirmRemove(m) {
    var bd = modal(head('Remove ' + m.name + '?') +
      '<div class="mc-modal-body"><p class="text-sm" style="color:var(--mc-text-2);">They will immediately lose access to QuoteAssist. Quotes they created stay in the workspace.</p></div>' +
      '<div class="mc-modal-foot"><button class="mc-btn mc-btn-sm mc-btn-ghost" data-close>Cancel</button><button class="mc-btn mc-btn-sm mc-btn-danger" id="cf-rm">Remove member</button></div>');
    $('#cf-rm', bd).onclick = function () { DB.members = DB.members.filter(function (x) { return x.id !== m.id; }); save(); bd.remove(); refreshAll(); toast(m.name + ' removed.'); };
  }
  function confirmDeleteRole(r) {
    var bd = modal(head('Delete ' + r.name + '?') +
      '<div class="mc-modal-body"><p class="text-sm" style="color:var(--mc-text-2);">This role has no members assigned. Deleting it can\'t be undone.</p></div>' +
      '<div class="mc-modal-foot"><button class="mc-btn mc-btn-sm mc-btn-ghost" data-close>Cancel</button><button class="mc-btn mc-btn-sm mc-btn-danger" id="rd">Delete role</button></div>');
    $('#rd', bd).onclick = function () { DB.roles = DB.roles.filter(function (x) { return x.id !== r.id; }); save(); bd.remove(); refreshAll(); toast('Role deleted.'); };
  }
  function openRole(r) {
    var isNew = !r;
    var draft = r ? JSON.parse(JSON.stringify(r.perms)) : {};
    var locked = r && r.id === 'owner';
    var checklist = PERM_GROUPS.map(function (g) {
      return '<div class="qa-pl-group"><div class="qa-pl-gh">' + g.group + '</div>' + g.items.map(function (i) {
        return '<label class="qa-pl-row"><span>' + i.l + '</span><input type="checkbox" data-perm="' + i.k + '"' + (draft[i.k] ? ' checked' : '') + '/></label>';
      }).join('') + '</div>';
    }).join('');
    var bd = modal(head(isNew ? 'New role' : 'Edit ' + r.name, isNew ? 'Define a role and choose what it can do.' : (locked ? 'The Owner role always has every permission.' : 'Adjust details and permissions.')) +
      '<div class="mc-modal-body"><div class="grid grid-cols-2 gap-4 mb-1">' +
      '<div><label class="mc-label">Role name</label><input class="mc-input" id="r-name" value="' + (r ? r.name : '') + '" placeholder="e.g. Finance"/></div>' +
      '<div><label class="mc-label">Description</label><input class="mc-input" id="r-desc" value="' + (r ? r.desc : '') + '" placeholder="What this role is for"/></div></div>' +
      '<div class="mc-label" style="margin-top:14px;">Permissions <span style="font-weight:500;color:var(--mc-text-3);">· ' + ALL_PERMS.length + ' total</span></div>' +
      '<div class="qa-pl' + (locked ? ' qa-pl-locked' : '') + '">' + checklist + '</div></div>' +
      '<div class="mc-modal-foot"><button class="mc-btn mc-btn-sm mc-btn-ghost" data-close>Cancel</button><button class="mc-btn mc-btn-sm mc-btn-primary" id="r-save">' + (isNew ? 'Create role' : 'Save changes') + '</button></div>', 560);
    if (locked) bd.querySelectorAll('[data-perm]').forEach(function (c) { c.checked = true; c.disabled = true; });
    bd.querySelectorAll('[data-perm]').forEach(function (c) { c.addEventListener('change', function () { if (c.checked) draft[c.dataset.perm] = true; else delete draft[c.dataset.perm]; }); });
    $('#r-save', bd).onclick = function () {
      var name = $('#r-name', bd).value.trim(); if (!name) { $('#r-name', bd).focus(); return; }
      var desc = $('#r-desc', bd).value.trim();
      if (isNew) DB.roles.push({ id: uid('r'), name: name, desc: desc, builtin: false, perms: locked ? allOn() : draft });
      else { r.name = name; r.desc = desc; if (!locked) r.perms = draft; }
      save(); bd.remove(); refreshAll(); toast(isNew ? 'Role created.' : 'Role updated.');
    };
  }

  /* ───────────────── toast ───────────────── */
  function toast(msg) { var el = $('#toast'); el.style.display = 'flex'; el.innerHTML = '<span style="color:var(--mc-success);">✓</span><span class="text-sm font-medium">' + msg + '</span>'; clearTimeout(el._t); el._t = setTimeout(function () { el.style.display = 'none'; }, 2200); }

  /* ───────────────── tabs + init ───────────────── */
  var TAB = 'members';
  function setTab(t) {
    TAB = t; closeMenu();
    document.querySelectorAll('#teamTabs .qa-ttab').forEach(function (b) { b.classList.toggle('on', b.dataset.tab === t); });
    ['members', 'roles', 'perms'].forEach(function (k) { $('#tab-' + k).style.display = k === t ? 'block' : 'none'; });
    var btn = $('#primaryBtn');
    if (t === 'members') { btn.innerHTML = plus + 'Invite member'; btn.onclick = openInvite; }
    else { btn.innerHTML = plus + 'New role'; btn.onclick = function () { openRole(null); }; }
    if (t === 'members' && ctrlMembers) ctrlMembers.refresh();
    if (t === 'roles' && ctrlRoles) ctrlRoles.refresh();
    if (t === 'perms' && ctrlPerms) ctrlPerms.refresh();
  }

  function init() {
    ctrlMembers = window.QAList({
      mount: 'lkMembers', key: 'members', noun: 'member', searchPlaceholder: 'Search name or email…',
      views: ['table', 'cards', 'list'], defaultView: 'table', pageSize: 5, emptyTitle: 'No members match.',
      filterFields: { role: { label: 'Role', type: 'enum', ops: ['is', 'is not'], options: DB.roles.map(function (r) { return r.name; }), get: function (m) { return roleName(m.role); } }, quotes: { label: 'Quotes · 30d', type: 'number', ops: ['greater than', 'less than'], get: function (m) { return m.quotes; } } },
      filterOrder: ['role', 'quotes'],
      sortFields: { name: { label: 'Name', key: function (m) { return m.name; }, dir: ['A → Z', 'Z → A'] }, role: { label: 'Role', key: function (m) { return roleName(m.role); }, dir: ['A → Z', 'Z → A'] }, quotes: { label: 'Quotes · 30d', key: function (m) { return m.quotes; }, dir: ['Most', 'Fewest'], numeric: true } },
      sortOrder: ['name', 'role', 'quotes'],
      searchText: function (m) { return m.name + ' ' + m.email; },
      getData: function () { return DB.members.slice(); },
      renderView: function (v, items) { return v === 'cards' ? mViewCards(items) : v === 'list' ? mViewList(items) : mViewTable(items); },
      onRendered: function (v, items, body) { bindMemberMenus(body); }
    });

    ctrlRoles = window.QAList({
      mount: 'lkRoles', key: 'roles', noun: 'role', searchPlaceholder: 'Search roles…',
      views: ['cards', 'table', 'list'], defaultView: 'cards', pageSize: 6, emptyTitle: 'No roles match.',
      filterFields: { type: { label: 'Type', type: 'enum', ops: ['is', 'is not'], options: ['Built-in', 'Custom'], get: function (r) { return r.builtin ? 'Built-in' : 'Custom'; } } },
      filterOrder: ['type'],
      sortFields: { name: { label: 'Name', key: function (r) { return r.name; }, dir: ['A → Z', 'Z → A'] }, members: { label: 'Members', key: function (r) { return memberCount(r.id); }, dir: ['Most', 'Fewest'], numeric: true }, perms: { label: 'Permissions', key: function (r) { return permCount(r); }, dir: ['Most', 'Fewest'], numeric: true } },
      sortOrder: ['name', 'members', 'perms'],
      searchText: function (r) { return r.name + ' ' + r.desc; },
      getData: function () { return DB.roles.slice(); },
      renderView: function (v, items) { return v === 'table' ? rViewTable(items) : v === 'list' ? rViewList(items) : rViewCards(items); },
      onRendered: function (v, items, body) { bindRoleControls(body); }
    });

    ctrlPerms = window.QAList({
      mount: 'lkPerms', key: 'perms', noun: 'permission', searchPlaceholder: 'Search permissions…',
      views: ['table', 'list', 'cards'], defaultView: 'table', pageSize: 6, emptyTitle: 'No permissions match.',
      filterFields: { group: { label: 'Category', type: 'enum', ops: ['is', 'is not'], options: GROUP_NAMES, get: function (i) { return i.group; } } },
      filterOrder: ['group'],
      sortFields: { name: { label: 'Permission', key: function (i) { return i.l; }, dir: ['A → Z', 'Z → A'] }, group: { label: 'Category', key: function (i) { return GROUP_NAMES.indexOf(i.group); }, dir: ['Quotes → Settings', 'Settings → Quotes'], numeric: true } },
      sortOrder: ['group', 'name'],
      searchText: function (i) { return i.l + ' ' + i.group; },
      getData: function () { return PERM_FLAT.slice(); },
      renderView: function (v, items) { return v === 'list' ? pViewList(items) : v === 'cards' ? pViewCards(items) : pViewTable(items); },
      onRendered: function (v, items, body) { bindPermTicks(body); }
    });

    renderPending(); updateSeats();
    document.querySelectorAll('#teamTabs .qa-ttab').forEach(function (b) { b.addEventListener('click', function () { setTab(b.dataset.tab); }); });
    setTab('members');
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
