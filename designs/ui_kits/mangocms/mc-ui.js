/* MangoCMS — shared UI primitives controller.
   Exposes window.MCUI: toast, confirm, menu, popover, closeAllPopovers.
   All confirmations are in-app modals — never window.confirm(). */
(function () {
  const ICONS = {
    check:  '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
    x:      '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    warn:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/></svg>',
    trash:  '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>',
    info:   '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></svg>',
  };

  // ───────────────── Toast ─────────────────
  let toastWrap;
  function toast(msg, kind = 'ok', ms = 2600) {
    if (!toastWrap) { toastWrap = document.createElement('div'); toastWrap.className = 'mcui-toasts'; document.body.appendChild(toastWrap); }
    const ico = kind === 'ok' ? ICONS.check : kind === 'err' ? ICONS.warn : ICONS.info;
    const el = document.createElement('div');
    el.className = 'mcui-toast ' + kind;
    el.innerHTML = `<span class="mcui-toast-ico">${ico}</span><span>${msg}</span>`;
    toastWrap.appendChild(el);
    requestAnimationFrame(() => el.classList.add('in'));
    setTimeout(() => { el.classList.remove('in'); setTimeout(() => el.remove(), 220); }, ms);
  }

  // ───────────────── Confirm modal ─────────────────
  function confirm(opts = {}) {
    const {
      title = 'Are you sure?', message = '', confirmLabel = 'Confirm',
      cancelLabel = 'Cancel', danger = false, kind = danger ? 'danger' : 'brand',
      icon = danger ? ICONS.trash : kind === 'warn' ? ICONS.warn : ICONS.info,
    } = opts;
    return new Promise((resolve) => {
      const bd = document.createElement('div');
      bd.className = 'mc-modal-backdrop mcui-confirm';
      bd.innerHTML = `
        <div class="mc-modal" role="dialog" aria-modal="true">
          <div class="mc-modal-head">
            <div style="display:flex; gap:14px; align-items:flex-start;">
              <div class="mcui-confirm-ico ${kind}">${icon}</div>
              <div>
                <div class="font-display font-bold text-lg" style="letter-spacing:-0.01em;">${title}</div>
                ${message ? `<div class="text-sm mt-1" style="color:var(--mc-text-2); line-height:1.5;">${message}</div>` : ''}
              </div>
            </div>
            <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-cancel>${ICONS.x}</button>
          </div>
          <div class="mc-modal-foot">
            <button class="mc-btn mc-btn-sm mc-btn-ghost" data-cancel>${cancelLabel}</button>
            <button class="mc-btn mc-btn-sm ${danger ? 'mc-btn-danger' : 'mc-btn-primary'}" data-ok>${confirmLabel}</button>
          </div>
        </div>`;
      document.body.appendChild(bd);
      const close = (val) => { bd.remove(); document.removeEventListener('keydown', onKey); resolve(val); };
      bd.querySelectorAll('[data-cancel]').forEach(b => b.onclick = () => close(false));
      bd.querySelector('[data-ok]').onclick = () => close(true);
      bd.addEventListener('mousedown', e => { if (e.target === bd) close(false); });
      function onKey(e) { if (e.key === 'Escape') close(false); if (e.key === 'Enter') { e.preventDefault(); close(true); } }
      document.addEventListener('keydown', onKey);
      setTimeout(() => bd.querySelector('[data-ok]').focus(), 30);
    });
  }

  // ───────────────── Popover positioning ─────────────────
  let openPops = [];
  function place(el, anchor, opts = {}) {
    const gap = opts.gap ?? 6;
    const r = anchor.getBoundingClientRect();
    el.style.visibility = 'hidden';
    el.style.left = '0px'; el.style.top = '0px';
    document.body.appendChild(el);
    const ew = el.offsetWidth, eh = el.offsetHeight;
    const vw = innerWidth, vh = innerHeight;
    let left = opts.align === 'right' ? r.right - ew : r.left;
    let top = r.bottom + gap;
    if (left + ew > vw - 8) left = vw - ew - 8;
    if (left < 8) left = 8;
    if (top + eh > vh - 8) { top = r.top - eh - gap; el.style.transformOrigin = 'bottom left'; }
    if (top < 8) top = 8;
    el.style.left = Math.round(left) + 'px';
    el.style.top = Math.round(top) + 'px';
    el.style.visibility = '';
  }

  function registerPop(el, onClose) {
    const entry = { el, onClose };
    openPops.push(entry);
    requestAnimationFrame(() => el.classList.add('in'));
    return () => {
      const i = openPops.indexOf(entry);
      if (i >= 0) openPops.splice(i, 1);
      el.classList.remove('in');
      setTimeout(() => el.remove(), 130);
      if (onClose) onClose();
    };
  }

  function closeAll(except) {
    [...openPops].forEach(p => { if (p.el !== except) { p.el.classList.remove('in'); setTimeout(() => p.el.remove(), 130); if (p.onClose) p.onClose(); } });
    openPops = openPops.filter(p => p.el === except);
  }

  document.addEventListener('mousedown', (e) => {
    if (!openPops.length) return;
    const inside = openPops.some(p => p.el.contains(e.target));
    const onAnchor = e.target.closest('[data-mcui-anchor]');
    if (!inside && !onAnchor) closeAll();
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeAll(); });
  window.addEventListener('resize', () => closeAll());

  // ───────────────── Contextual menu ─────────────────
  function menu(anchor, items, opts = {}) {
    closeAll();
    const el = document.createElement('div');
    el.className = 'mcui-menu';
    el.innerHTML = items.map(it => {
      if (it.sep) return '<div class="mcui-menu-sep"></div>';
      if (it.label && it.heading) return `<div class="mcui-menu-label">${it.label}</div>`;
      return `<button class="mcui-menu-item ${it.danger ? 'danger' : ''}" data-mi>
        ${it.icon || ''}<span>${it.label}</span>${it.kbd ? `<span class="mc-kbd mcui-menu-kbd">${it.kbd}</span>` : ''}
      </button>`;
    }).join('');
    place(el, anchor, { align: opts.align || 'left' });
    const close = registerPop(el);
    let idx = 0;
    el.querySelectorAll('[data-mi]').forEach((b) => {
      const item = items.filter(i => !i.sep && !i.heading)[idx++];
      b.onclick = () => { close(); if (item && item.onClick) item.onClick(); };
    });
    return close;
  }

  // ───────────────── Generic popover (caller supplies content node) ─────────────────
  function popover(anchor, contentEl, opts = {}) {
    closeAll();
    const el = document.createElement('div');
    el.className = 'mcui-pop';
    if (opts.width) el.style.width = opts.width + 'px';
    el.appendChild(contentEl);
    place(el, anchor, opts);
    return registerPop(el, opts.onClose);
  }

  window.MCUI = { toast, confirm, menu, popover, closeAll, ICONS };
})();
