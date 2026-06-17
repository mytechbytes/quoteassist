/* MangoCMS — Collection records browser controller.
   Excel-like editable data grid for a single collection's records.
   Depends on mc-ui.js (MCUI.toast/confirm/menu/popover) and collection-flow.js (CF). */
(function () {
  'use strict';

  // ───────────────────────── ICONS ─────────────────────────
  const ic = (p, w) => `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w || 1.9}" stroke-linecap="round" stroke-linejoin="round">${p}</svg>`;
  const ICO = {
    pencil:  ic('<path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z"/>'),
    dots:    '<svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/></svg>',
    dotsV:   '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="12" cy="19" r="1.6"/></svg>',
    copy:    ic('<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/>'),
    dup:     ic('<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M4 16V6a2 2 0 0 1 2-2h10"/>'),
    trash:   ic('<path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>'),
    eye:     ic('<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>'),
    swap:    ic('<path d="M17 2l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><path d="M7 22l-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>'),
    down:    ic('<path d="M12 3v12M7 10l5 5 5-5"/><path d="M5 21h14"/>'),
    search:  ic('<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>'),
    check:   ic('<polyline points="20 6 9 17 4 12"/>', 2.4),
    plus:    ic('<path d="M12 5v14M5 12h14"/>', 2.4),
    chev:    ic('<polyline points="6 9 12 15 18 9"/>', 2.4),
    left:    ic('<polyline points="15 18 9 12 15 6"/>', 2.4),
    right:   ic('<polyline points="9 18 15 12 9 6"/>', 2.4),
    image:   ic('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="m21 16-5-5L5 20"/>'),
    x:       ic('<path d="M18 6 6 18M6 6l12 12"/>', 2),
    arrowUp: '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"/></svg>',
    arrowDn: '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>',
  };

  // ───────────────────────── SCHEMA + DATA ─────────────────────────
  const GENRE_HUE = { Fiction: 60, Mystery: 290, 'Sci-Fi': 230, Romance: 350, Biography: 150, Children: 30, History: 90 };
  const GENRES = Object.keys(GENRE_HUE);
  const STATUSES = ['Live', 'Pre-order', 'Draft'];

  const TITLE_FIELDS = [
    { id: 'cover',    label: 'Cover',    type: 'image' },
    { id: 'title',    label: 'Title',    type: 'text', primary: true, required: true },
    { id: 'author',   label: 'Author',   type: 'text' },
    { id: 'isbn',     label: 'ISBN',     type: 'text', mono: true },
    { id: 'genre',    label: 'Genre',    type: 'category', options: GENRES },
    { id: 'price',    label: 'Price',    type: 'number', money: true },
    { id: 'stock',    label: 'Stock',    type: 'number' },
    { id: 'released', label: 'Released', type: 'datetime' },
    { id: 'status',   label: 'Status',   type: 'status', options: STATUSES },
  ];

  let _uid = 100;
  const nid = () => 'rec_' + (++_uid);

  function seedRecords() {
    const raw = [
      ['The Salt Garden', 'Elena Marchetti', '978-1-4839-1102-7', 'Fiction', 24.99, 842, '2025-03-12T09:00', 'Live'],
      ['A Quiet Reckoning', 'Idris Bowen', '978-1-4839-1204-1', 'Mystery', 22.50, 412, '2025-02-28T09:00', 'Live'],
      ['Orbital Drift', 'Mei-Lin Park', '978-1-4839-1311-6', 'Sci-Fi', 18.99, 1204, '2024-11-05T09:00', 'Live'],
      ['Lemons in July', 'Camille Renaud', '978-1-4839-1422-3', 'Romance', 16.99, 14, '2025-04-18T09:00', 'Live'],
      ['Borrowed Light', 'Yusuf Adebayo', '978-1-4839-1533-8', 'Biography', 28.00, 602, '2025-01-22T09:00', 'Live'],
      ["The Cartographer's Bride", 'Anya Vasquez', '978-1-4839-1755-9', 'Romance', 19.99, 0, '2025-06-01T09:00', 'Pre-order'],
      ['Counting the Frost', 'Tomás Linde', '978-1-4839-1866-3', 'Fiction', 21.00, 0, '2025-07-15T09:00', 'Draft'],
      ['The Marmalade Cat', 'Joon Park', '978-1-4839-2310-7', 'Children', 12.99, 2218, '2024-09-30T09:00', 'Live'],
    ];
    return raw.map(r => ({
      _id: nid(),
      cover: { hue: GENRE_HUE[r[3]] },
      title: r[0], author: r[1], isbn: r[2], genre: r[3],
      price: r[4], stock: r[5], released: r[6], status: r[7],
    }));
  }

  // ───────────────────────── STATE ─────────────────────────
  const S = {
    fields: TITLE_FIELDS.slice(),
    records: seedRecords(),
    visible: new Set(TITLE_FIELDS.map(f => f.id)),
    search: '',
    sort: { field: null, dir: 1 },
    filters: { genre: new Set(), status: new Set() },
    selected: new Set(),
    sel: null,        // {r, c} focused grid cell
    editing: null,    // {r, c}
    display: [],      // current display record refs (in order)
  };

  function visFields() { return S.fields.filter(f => S.visible.has(f.id)); }

  // ───────────────────────── FORMATTERS ─────────────────────────
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  function fmtMoney(v) { return v == null || v === '' ? '' : '$' + Number(v).toFixed(2); }
  function fmtDateTime(iso) {
    if (!iso) return '';
    const d = new Date(iso);
    if (isNaN(d)) return '';
    const time = d.getHours() || d.getMinutes()
      ? ` · ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}` : '';
    return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}${time}`;
  }
  function coverHTML(cover, big) {
    const w = big ? '' : '';
    if (cover && cover.src) return `<div class="img-thumb${big ? ' cover-big' : ''}"><img src="${cover.src}" alt=""/></div>`;
    if (cover && cover.hue != null) {
      const h = cover.hue;
      return `<div class="img-thumb${big ? ' cover-big' : ''}" style="background:linear-gradient(160deg, oklch(0.55 0.17 ${h}), oklch(0.38 0.10 ${h}));"><span class="spine"></span></div>`;
    }
    return `<div class="img-thumb empty${big ? ' cover-big' : ''}">${ICO.image}</div>`;
  }
  function chipStyle(hue) { return `background: oklch(0.95 0.04 ${hue}); color: oklch(0.42 0.12 ${hue});`; }
  function statusHTML(v) {
    if (v === 'Live') return '<span class="mc-status mc-status-live">Live</span>';
    if (v === 'Pre-order') return '<span class="mc-status mc-status-build">Pre-order</span>';
    if (v === 'Draft') return '<span class="mc-status mc-status-draft">Draft</span>';
    return '<span class="cell-empty">—</span>';
  }
  const esc = (s) => String(s == null ? '' : s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');

  // ───────────────────────── DISPLAY ROWS ─────────────────────────
  function computeDisplay() {
    let rows = S.records.filter(r => !r._draft);
    const q = S.search.trim().toLowerCase();
    if (q) rows = rows.filter(r => [r.title, r.author, r.isbn].some(v => String(v || '').toLowerCase().includes(q)));
    if (S.filters.genre.size) rows = rows.filter(r => S.filters.genre.has(r.genre));
    if (S.filters.status.size) rows = rows.filter(r => S.filters.status.has(r.status));
    if (S.sort.field) {
      const f = S.sort.field, dir = S.sort.dir;
      rows = rows.slice().sort((a, b) => {
        let x = a[f], y = b[f];
        if (typeof x === 'number' || typeof y === 'number') { x = +x || 0; y = +y || 0; return (x - y) * dir; }
        return String(x || '').localeCompare(String(y || '')) * dir;
      });
    }
    const drafts = S.records.filter(r => r._draft);
    S.display = rows.concat(drafts);
  }

  // ───────────────────────── RENDER ─────────────────────────
  function render() {
    computeDisplay();
    renderHead();
    renderBody();
    renderBulk();
    renderCount();
  }

  function renderHead() {
    const vf = visFields();
    const allOn = S.display.filter(r => !r._draft).length > 0 && S.display.filter(r => !r._draft).every(r => S.selected.has(r._id));
    const th = [
      `<th style="width:40px;"><div class="rec-check"><input type="checkbox" id="rec-all" ${allOn ? 'checked' : ''}/></div></th>`,
      ...vf.map(f => {
        const sorted = S.sort.field === f.id;
        const arrow = sorted ? (S.sort.dir === 1 ? ICO.arrowUp : ICO.arrowDn) : ICO.arrowDn;
        const numCls = (f.type === 'number') ? ' num' : '';
        const sortable = f.type !== 'image';
        return `<th class="${sortable ? 'sortable' : ''}${sorted ? ' sorted' : ''}${numCls}" ${sortable ? `data-sort="${f.id}"` : ''}>${esc(f.label)}${sortable ? `<span class="th-arrow">${arrow}</span>` : ''}</th>`;
      }),
      `<th style="width:96px; text-align:right; padding-right:18px;"></th>`,
    ].join('');
    document.querySelector('#rec-thead').innerHTML = `<tr>${th}</tr>`;
  }

  function renderBody() {
    const vf = visFields();
    const tb = document.querySelector('#rec-tbody');
    if (!S.display.length) {
      tb.innerHTML = `<tr><td colspan="${vf.length + 2}" style="padding:48px; text-align:center;"><div class="cell-empty" style="font-style:normal; color:var(--mc-text-3);">No records match your filters.</div></td></tr>`;
      return;
    }
    tb.innerHTML = S.display.map((rec, r) => {
      const checked = S.selected.has(rec._id);
      const cells = vf.map((f, c) => cellTD(rec, f, r, c)).join('');
      const actions = rec._draft
        ? `<td><div class="draft-actions">
             <button class="mc-btn mc-btn-sm mc-btn-ghost" data-draft-cancel="${rec._id}">Cancel</button>
             <button class="mc-btn mc-btn-sm mc-btn-primary" data-draft-save="${rec._id}">${ICO.check} Save row</button>
           </div></td>`
        : `<td><div class="rec-actions">
             <button class="rec-act-btn" data-edit="${rec._id}" title="Edit in form">${ICO.pencil}</button>
             <button class="rec-act-btn" data-row-menu="${rec._id}" title="More">${ICO.dots}</button>
           </div></td>`;
      return `<tr class="${rec._draft ? 'draft-row' : ''} ${checked ? 'sel-row' : ''}" data-id="${rec._id}">
        <td><div class="rec-check">${rec._draft ? '<span class="draft-badge">New</span>' : `<input type="checkbox" data-check="${rec._id}" ${checked ? 'checked' : ''}/>`}</div></td>
        ${cells}${actions}
      </tr>`;
    }).join('');
    // restore selection ring
    if (S.sel) markSel();
  }

  function cellTD(rec, f, r, c) {
    const numCls = (f.type === 'number') ? ' num' : '';
    let inner;
    const val = rec[f.id];
    if (f.type === 'image') {
      inner = `<div class="img-cell">${coverHTML(val)}<button class="img-menu-btn" data-img-menu="${rec._id}" title="Image options">${ICO.dotsV}</button></div>`;
      return `<td class="rec-td" data-r="${r}" data-c="${c}">${inner}</td>`;
    }
    if (f.type === 'category') {
      inner = val ? `<span class="rec-chip" style="${chipStyle(GENRE_HUE[val] || 220)}">${esc(val)}</span>` : '<span class="cell-empty">—</span>';
      inner += `<span class="chev-dim">${ICO.chev}</span>`;
    } else if (f.type === 'status') {
      inner = statusHTML(val) + `<span class="chev-dim">${ICO.chev}</span>`;
    } else if (f.type === 'datetime') {
      inner = val ? esc(fmtDateTime(val)) : '<span class="cell-empty">—</span>';
    } else if (f.type === 'number') {
      inner = (val === '' || val == null) ? '<span class="cell-empty">—</span>' : (f.money ? fmtMoney(val) : esc(val));
    } else {
      const cls = f.mono ? ' style="font-family:\'JetBrains Mono\',monospace; font-size:12.5px;"' : (f.primary ? ' style="font-weight:600;"' : '');
      inner = (val === '' || val == null) ? '<span class="cell-empty">—</span>' : `<span${cls}>${esc(val)}</span>`;
    }
    return `<td class="rec-td" data-r="${r}" data-c="${c}"><div class="rec-cell${numCls}">${inner}</div></td>`;
  }

  function renderCount() {
    const total = S.records.filter(r => !r._draft).length;
    const shown = S.display.filter(r => !r._draft).length;
    const el = document.querySelector('#rec-count');
    if (el) el.textContent = `Showing ${shown} of ${total} records`;
  }

  // ───────────────────────── BULK BAR ─────────────────────────
  function renderBulk() {
    const bar = document.querySelector('#rec-bulkbar');
    const n = S.selected.size;
    if (!n) { bar.style.display = 'none'; bar.innerHTML = ''; return; }
    bar.style.display = 'flex';
    bar.innerHTML = `
      <span class="bulk-count">${n} selected</span>
      <div style="width:1px; height:18px; background:rgb(255 255 255 / 0.2);"></div>
      <button class="bulk-btn" data-bulk="duplicate">${ICO.dup} Duplicate</button>
      <button class="bulk-btn" data-bulk="export">${ICO.down} Export</button>
      <button class="bulk-btn danger" data-bulk="delete">${ICO.trash} Delete</button>
      <div style="flex:1"></div>
      <button class="bulk-btn" data-bulk="clear">Clear selection</button>`;
  }

  // ───────────────────────── CELL SELECTION + KEYBOARD ─────────────────────────
  function cellEl(r, c) { return document.querySelector(`#rec-tbody td.rec-td[data-r="${r}"][data-c="${c}"]`); }
  function clearSelMark() { document.querySelectorAll('#rec-tbody td.is-sel').forEach(td => td.classList.remove('is-sel')); }
  function markSel() {
    clearSelMark();
    if (!S.sel) return;
    const td = cellEl(S.sel.r, S.sel.c);
    if (td) td.classList.add('is-sel');
  }
  function setSel(r, c) {
    const vf = visFields();
    r = Math.max(0, Math.min(S.display.length - 1, r));
    c = Math.max(0, Math.min(vf.length - 1, c));
    S.sel = { r, c };
    markSel();
  }

  function onKey(e) {
    if (S.editing) return;
    if (document.querySelector('.mc-modal-backdrop:not([style*="display: none"])') && !document.querySelector('#rec-grid')) return;
    // ignore when typing in an unrelated input/popover
    const t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT') && !t.closest('#rec-tbody')) return;
    if (document.querySelector('.mcui-pop, .mcui-menu')) return; // a popover editor is open
    if (!S.sel) return;
    const vf = visFields();
    const { r, c } = S.sel;
    const k = e.key;
    if (k === 'ArrowUp') { e.preventDefault(); setSel(r - 1, c); }
    else if (k === 'ArrowDown') { e.preventDefault(); setSel(r + 1, c); }
    else if (k === 'ArrowLeft') { e.preventDefault(); setSel(r, c - 1); }
    else if (k === 'ArrowRight') { e.preventDefault(); setSel(r, c + 1); }
    else if (k === 'Tab') { e.preventDefault(); setSel(r, c + (e.shiftKey ? -1 : 1)); }
    else if (k === 'Enter' || k === 'F2') { e.preventDefault(); startEdit(r, c); }
    else if (k === 'Escape') { S.sel = null; clearSelMark(); }
    else if (k.length === 1 && !e.metaKey && !e.ctrlKey && !e.altKey) {
      const f = vf[c];
      if (f.type === 'text' || f.type === 'number') startEdit(r, c, k);
    }
  }

  // ───────────────────────── INLINE EDIT (text / number) ─────────────────────────
  function startEdit(r, c, seed) {
    const vf = visFields();
    const f = vf[c]; const rec = S.display[r];
    if (!f || !rec) return;
    setSel(r, c);
    if (f.type === 'category' || f.type === 'status') return openChoiceEditor(r, c);
    if (f.type === 'datetime' || f.type === 'date') return openDateEditor(r, c);
    if (f.type === 'image') return openImageMenu(r, c);

    S.editing = { r, c };
    const td = cellEl(r, c);
    td.classList.add('is-editing');
    const cur = rec[f.id];
    const monoCls = f.mono ? ' mono' : (f.type === 'number' ? ' num' : '');
    td.innerHTML = `<input class="rec-cell-input${monoCls}" type="${f.type === 'number' ? 'number' : 'text'}" ${f.money ? 'step="0.01"' : ''} value="${seed != null ? esc(seed) : esc(cur == null ? '' : cur)}"/>`;
    const inp = td.querySelector('input');
    inp.focus();
    if (seed == null) inp.select(); else { const L = inp.value.length; inp.setSelectionRange(L, L); }

    let done = false;
    const commit = (move) => {
      if (done) return; done = true;
      let v = inp.value;
      if (f.type === 'number') v = (v === '' ? '' : Number(v));
      const changed = rec[f.id] !== v;
      rec[f.id] = v;
      S.editing = null;
      render();
      setSel(r, c);
      if (changed && !rec._draft) MCUI.toast(`Updated “${f.label}”`, 'ok', 1600);
      if (move === 'down') setSel(r + 1, c);
      if (move === 'right') setSel(r, c + 1);
    };
    const cancel = () => { if (done) return; done = true; S.editing = null; render(); setSel(r, c); };
    inp.addEventListener('keydown', (e) => {
      e.stopPropagation();
      if (e.key === 'Enter') { e.preventDefault(); commit('down'); }
      else if (e.key === 'Tab') { e.preventDefault(); commit(e.shiftKey ? null : 'right'); }
      else if (e.key === 'Escape') { e.preventDefault(); cancel(); }
    });
    inp.addEventListener('blur', () => commit());
  }

  // ───────────────────────── CHOICE EDITOR (category / status) ─────────────────────────
  function openChoiceEditor(r, c) {
    const vf = visFields(); const f = vf[c]; const rec = S.display[r];
    const td = cellEl(r, c);
    const opts = f.options.slice();
    const cur = rec[f.id];
    const wrap = document.createElement('div');
    wrap.className = 'sdrop';
    wrap.innerHTML = `
      <div class="sdrop-search">${ICO.search}<input placeholder="Search ${esc(f.label.toLowerCase())}…" autofocus/></div>
      <div class="sdrop-list"></div>`;
    const listEl = wrap.querySelector('.sdrop-list');
    const searchEl = wrap.querySelector('input');
    let close;
    function paint(q) {
      const filtered = opts.filter(o => o.toLowerCase().includes(q.toLowerCase()));
      if (!filtered.length) { listEl.innerHTML = `<div class="sdrop-empty">No matches for “${esc(q)}”</div>`; return; }
      listEl.innerHTML = filtered.map(o => {
        const sw = f.type === 'category'
          ? `<span class="rec-chip" style="${chipStyle(GENRE_HUE[o] || 220)}">${esc(o)}</span>`
          : statusHTML(o);
        return `<button class="sdrop-opt ${o === cur ? 'selected' : ''}" data-opt="${esc(o)}">${sw}<span class="opt-check">${ICO.check}</span></button>`;
      }).join('');
      listEl.querySelectorAll('[data-opt]').forEach(b => b.onclick = () => {
        const v = b.getAttribute('data-opt');
        rec[f.id] = v;
        if (f.id === 'genre' && rec.cover && rec.cover.hue != null) rec.cover = { hue: GENRE_HUE[v] };
        close();
        render(); setSel(r, c);
        if (!rec._draft) MCUI.toast(`Set “${f.label}” to ${v}`, 'ok', 1600);
      });
    }
    paint('');
    searchEl.addEventListener('input', () => paint(searchEl.value));
    searchEl.addEventListener('keydown', (e) => { e.stopPropagation(); if (e.key === 'Escape') close(); });
    close = MCUI.popover(td, wrap, { width: 248, gap: 2 });
    setTimeout(() => searchEl.focus(), 30);
  }

  // ───────────────────────── DATE / TIME EDITOR ─────────────────────────
  function openDateEditor(r, c) {
    const vf = visFields(); const f = vf[c]; const rec = S.display[r];
    const td = cellEl(r, c);
    let base = rec[f.id] ? new Date(rec[f.id]) : new Date();
    if (isNaN(base)) base = new Date();
    let viewY = base.getFullYear(), viewM = base.getMonth();
    let selDate = rec[f.id] ? new Date(rec[f.id]) : null;
    let timeStr = selDate ? `${String(selDate.getHours()).padStart(2,'0')}:${String(selDate.getMinutes()).padStart(2,'0')}` : '09:00';

    const wrap = document.createElement('div');
    wrap.className = 'cal';
    function paint() {
      const first = new Date(viewY, viewM, 1);
      const startDow = (first.getDay() + 6) % 7; // Mon-first
      const days = new Date(viewY, viewM + 1, 0).getDate();
      const prevDays = new Date(viewY, viewM, 0).getDate();
      const today = new Date();
      let cells = '';
      for (let i = 0; i < startDow; i++) cells += `<button class="cal-day muted" disabled>${prevDays - startDow + i + 1}</button>`;
      for (let d = 1; d <= days; d++) {
        const isSel = selDate && selDate.getFullYear() === viewY && selDate.getMonth() === viewM && selDate.getDate() === d;
        const isToday = today.getFullYear() === viewY && today.getMonth() === viewM && today.getDate() === d;
        cells += `<button class="cal-day ${isSel ? 'sel' : ''} ${isToday ? 'today' : ''}" data-day="${d}">${d}</button>`;
      }
      wrap.innerHTML = `
        <div class="cal-head">
          <button class="cal-nav" data-prev>${ICO.left}</button>
          <div class="cal-title">${MONTHS[viewM]} ${viewY}</div>
          <button class="cal-nav" data-next>${ICO.right}</button>
        </div>
        <div class="cal-grid">${['M','T','W','T','F','S','S'].map(d => `<div class="cal-dow">${d}</div>`).join('')}${cells}</div>
        <div class="cal-foot">
          ${f.type === 'datetime' ? `<div class="cal-time"><label>Time</label><input type="time" value="${timeStr}"/></div>` : '<div class="cal-time"></div>'}
          <button class="mc-btn mc-btn-sm mc-btn-primary" data-apply style="align-self:flex-end;">Apply</button>
        </div>`;
      wrap.querySelector('[data-prev]').onclick = () => { viewM--; if (viewM < 0) { viewM = 11; viewY--; } paint(); };
      wrap.querySelector('[data-next]').onclick = () => { viewM++; if (viewM > 11) { viewM = 0; viewY++; } paint(); };
      wrap.querySelectorAll('[data-day]').forEach(b => b.onclick = () => { selDate = new Date(viewY, viewM, +b.getAttribute('data-day')); paint(); });
      const timeInp = wrap.querySelector('input[type="time"]');
      if (timeInp) timeInp.addEventListener('input', () => { timeStr = timeInp.value || '00:00'; });
      wrap.querySelector('[data-apply]').onclick = () => {
        if (!selDate) selDate = new Date(viewY, viewM, today.getDate());
        let iso;
        if (f.type === 'datetime') {
          const [hh, mm] = timeStr.split(':');
          selDate.setHours(+hh || 0, +mm || 0, 0, 0);
        }
        iso = f.type === 'datetime'
          ? `${selDate.getFullYear()}-${String(selDate.getMonth()+1).padStart(2,'0')}-${String(selDate.getDate()).padStart(2,'0')}T${timeStr}`
          : `${selDate.getFullYear()}-${String(selDate.getMonth()+1).padStart(2,'0')}-${String(selDate.getDate()).padStart(2,'0')}`;
        rec[f.id] = iso;
        close();
        render(); setSel(r, c);
        if (!rec._draft) MCUI.toast(`Set “${f.label}”`, 'ok', 1600);
      };
    }
    paint();
    const close = MCUI.popover(td, wrap, { width: 268, gap: 2 });
  }

  // ───────────────────────── IMAGE CELL MENU ─────────────────────────
  function openImageMenu(rOrId, c) {
    let rec, anchor;
    if (typeof rOrId === 'string') { rec = S.records.find(x => x._id === rOrId); anchor = document.querySelector(`[data-img-menu="${rOrId}"]`); }
    else { rec = S.display[rOrId]; anchor = cellEl(rOrId, c); }
    if (!rec) return;
    const hasImg = rec.cover && (rec.cover.src || rec.cover.hue != null);
    const items = [
      { label: 'Replace image', icon: ICO.swap, onClick: () => replaceImage(rec) },
      { label: 'View full size', icon: ICO.eye, onClick: () => previewImage(rec) },
      { label: 'Download', icon: ICO.down, onClick: () => MCUI.toast('Download started', 'info', 1800) },
    ];
    if (hasImg) { items.push({ sep: true }); items.push({ label: 'Remove image', icon: ICO.trash, danger: true, onClick: () => removeImage(rec) }); }
    MCUI.menu(anchor, items, { align: 'left' });
  }
  function replaceImage(rec) {
    const inp = document.createElement('input');
    inp.type = 'file'; inp.accept = 'image/*';
    inp.onchange = () => {
      const file = inp.files[0]; if (!file) return;
      const fr = new FileReader();
      fr.onload = () => { rec.cover = { src: fr.result }; render(); restoreSel(); MCUI.toast('Image replaced', 'ok'); };
      fr.readAsDataURL(file);
    };
    inp.click();
  }
  async function removeImage(rec) {
    const ok = await MCUI.confirm({ title: 'Remove image?', message: 'This clears the cover for this record. You can add a new one anytime.', confirmLabel: 'Remove image', danger: true });
    if (!ok) return;
    rec.cover = null; render(); restoreSel(); MCUI.toast('Image removed', 'ok');
  }
  function previewImage(rec) {
    const bd = document.createElement('div');
    bd.className = 'mc-modal-backdrop';
    bd.innerHTML = `
      <div class="mc-modal" style="max-width:380px;">
        <div class="mc-modal-head">
          <div><div class="font-display font-bold text-lg">${esc(rec.title || 'Cover preview')}</div>
          <div class="text-xs mt-0.5" style="color:var(--mc-text-3);">${esc(rec.genre || '')}</div></div>
          <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-x>${ICO.x}</button>
        </div>
        <div class="mc-modal-body imgview-stage">${coverHTML(rec.cover, true)}</div>
      </div>`;
    document.body.appendChild(bd);
    const close = () => bd.remove();
    bd.querySelector('[data-x]').onclick = close;
    bd.addEventListener('mousedown', e => { if (e.target === bd) close(); });
  }

  function restoreSel() { if (S.sel) setSel(S.sel.r, S.sel.c); }

  // ───────────────────────── ROW MENU ─────────────────────────
  function openRowMenu(id) {
    const rec = S.records.find(x => x._id === id);
    const anchor = document.querySelector(`[data-row-menu="${id}"]`);
    MCUI.menu(anchor, [
      { label: 'Edit in form', icon: ICO.pencil, onClick: () => openForm(rec) },
      { label: 'Duplicate', icon: ICO.dup, onClick: () => duplicateRecord(rec) },
      { label: 'Copy record ID', icon: ICO.copy, onClick: () => { MCUI.toast('Record ID copied', 'info', 1600); } },
      { sep: true },
      { label: 'Delete record', icon: ICO.trash, danger: true, onClick: () => deleteRecord(rec) },
    ], { align: 'right' });
  }

  async function duplicateRecord(rec) {
    const ok = await MCUI.confirm({ title: 'Duplicate record?', message: `A copy of “${esc(rec.title || 'Untitled')}” will be added to the collection.`, confirmLabel: 'Duplicate', kind: 'brand', icon: MCUI.ICONS ? undefined : '' });
    if (!ok) return;
    const copy = JSON.parse(JSON.stringify(rec)); copy._id = nid(); copy.title = (rec.title || 'Untitled') + ' (copy)';
    const i = S.records.indexOf(rec); S.records.splice(i + 1, 0, copy);
    render(); MCUI.toast('Record duplicated', 'ok');
  }
  async function deleteRecord(rec) {
    const ok = await MCUI.confirm({ title: 'Delete this record?', message: `“${esc(rec.title || 'Untitled')}” will be permanently removed. This can’t be undone.`, confirmLabel: 'Delete record', danger: true });
    if (!ok) return;
    S.records = S.records.filter(x => x !== rec); S.selected.delete(rec._id); S.sel = null;
    render(); MCUI.toast('Record deleted', 'ok');
  }

  // ───────────────────────── DRAFT (bottom add-row) ─────────────────────────
  function addDraftRow() {
    const draft = { _id: nid(), _draft: true, cover: null };
    S.fields.forEach(f => { if (!(f.id in draft)) draft[f.id] = (f.type === 'number' ? '' : (f.type === 'image' ? null : '')); });
    S.records.push(draft);
    render();
    // focus first editable cell of the new row
    const r = S.display.indexOf(draft);
    const firstText = visFields().findIndex(f => f.type === 'text');
    setSel(r, firstText < 0 ? 0 : firstText);
    const td = cellEl(S.sel.r, S.sel.c);
    if (td) td.scrollIntoView ? null : null;
    setTimeout(() => startEdit(S.sel.r, S.sel.c), 60);
  }
  async function saveDraft(id) {
    const rec = S.records.find(x => x._id === id); if (!rec) return;
    if (!rec.title || !String(rec.title).trim()) { MCUI.toast('Title is required', 'err'); return; }
    const ok = await MCUI.confirm({ title: 'Create this record?', message: `“${esc(rec.title)}” will be saved to the Titles collection.`, confirmLabel: 'Create record', kind: 'brand' });
    if (!ok) return;
    delete rec._draft;
    if (!rec.cover && rec.genre) rec.cover = { hue: GENRE_HUE[rec.genre] || 220 };
    render(); MCUI.toast('Record created', 'ok');
  }
  async function cancelDraft(id) {
    const rec = S.records.find(x => x._id === id); if (!rec) return;
    const hasData = ['title','author','isbn','genre','price','stock'].some(k => rec[k] !== '' && rec[k] != null);
    if (hasData) {
      const ok = await MCUI.confirm({ title: 'Discard new row?', message: 'The data you entered in this row will be discarded.', confirmLabel: 'Discard', danger: true });
      if (!ok) return;
    }
    S.records = S.records.filter(x => x !== rec); S.sel = null; render();
  }

  // ───────────────────────── RECORD FORM MODAL ─────────────────────────
  function openForm(rec) {
    const isNew = !rec;
    const data = rec ? JSON.parse(JSON.stringify(rec)) : (function () { const o = { _id: nid() }; S.fields.forEach(f => o[f.id] = f.type === 'image' ? null : ''); return o; })();
    const bd = document.createElement('div');
    bd.className = 'mc-modal-backdrop';
    bd.innerHTML = `
      <div class="mc-modal" style="max-width:640px;">
        <div class="mc-modal-head">
          <div>
            <div class="font-display font-bold text-lg">${isNew ? 'New record' : 'Edit record'}</div>
            <div class="text-xs mt-0.5" style="color:var(--mc-text-3);">${isNew ? 'Add a new item to' : 'Update an item in'} the Titles collection</div>
          </div>
          <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-x>${ICO.x}</button>
        </div>
        <div class="mc-modal-body"><div class="rf-grid" id="rf-grid"></div></div>
        <div class="mc-modal-foot">
          <button class="mc-btn mc-btn-sm mc-btn-ghost" data-x>Cancel</button>
          <button class="mc-btn mc-btn-sm mc-btn-primary" data-save>${isNew ? 'Create record' : 'Save changes'}</button>
        </div>
      </div>`;
    document.body.appendChild(bd);
    const grid = bd.querySelector('#rf-grid');
    grid.innerHTML = S.fields.map(f => formField(f, data[f.id])).join('');
    bindFormField(grid, data);

    const close = () => bd.remove();
    bd.querySelectorAll('[data-x]').forEach(b => b.onclick = close);
    bd.addEventListener('mousedown', e => { if (e.target === bd) close(); });
    bd.querySelector('[data-save]').onclick = async () => {
      // collect text/number/select/date values
      grid.querySelectorAll('[data-field]').forEach(el => {
        const id = el.getAttribute('data-field'); const f = S.fields.find(x => x.id === id);
        if (!f || f.type === 'image') return;
        let v = el.value;
        if (f.type === 'number') v = (v === '' ? '' : Number(v));
        data[id] = v;
      });
      if (!data.title || !String(data.title).trim()) { MCUI.toast('Title is required', 'err'); return; }
      const ok = await MCUI.confirm({ title: isNew ? 'Create this record?' : 'Save changes?', message: isNew ? `“${esc(data.title)}” will be added to the collection.` : `Your edits to “${esc(data.title)}” will be saved.`, confirmLabel: isNew ? 'Create record' : 'Save changes', kind: 'brand' });
      if (!ok) return;
      if (data.genre && (!data.cover || data.cover.hue != null)) data.cover = data.cover && data.cover.src ? data.cover : { hue: GENRE_HUE[data.genre] || 220 };
      if (isNew) { S.records.push(data); MCUI.toast('Record created', 'ok'); }
      else { const i = S.records.findIndex(x => x._id === rec._id); if (i >= 0) S.records[i] = Object.assign(S.records[i], data); MCUI.toast('Record updated', 'ok'); }
      close(); render();
    };
  }

  function formField(f, val) {
    const full = (f.type === 'image' || f.id === 'title') ? ' full' : '';
    const label = `<label class="mc-label">${esc(f.label)}${f.required ? ' <span style="color:var(--mc-brand)">*</span>' : ''}<span class="rf-typehint">${f.type}</span></label>`;
    let ctrl;
    if (f.type === 'image') {
      ctrl = `<div class="rf-img">
        <div class="rf-img-thumb${val && (val.src || val.hue != null) ? '' : ' empty'}" id="rf-thumb">${(val && (val.src || val.hue != null)) ? coverInner(val) : ICO.image}</div>
        <div style="display:flex; gap:8px;">
          <button type="button" class="mc-btn mc-btn-sm mc-btn-secondary" data-rf-replace>${ICO.swap} Choose image</button>
          <button type="button" class="mc-btn mc-btn-sm mc-btn-ghost" data-rf-remove style="color:var(--mc-error);">Remove</button>
        </div>
      </div>`;
      return `<div class="rf-field${full}">${label}${ctrl}</div>`;
    }
    if (f.type === 'category' || f.type === 'status') {
      ctrl = `<select class="mc-input mc-select" data-field="${f.id}"><option value="">— Select —</option>${f.options.map(o => `<option ${o === val ? 'selected' : ''}>${esc(o)}</option>`).join('')}</select>`;
    } else if (f.type === 'datetime' || f.type === 'date') {
      const d = val ? new Date(val) : null;
      const dStr = d && !isNaN(d) ? `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}` : '';
      const tStr = d && !isNaN(d) ? `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}` : '';
      ctrl = `<div style="display:flex; gap:8px;">
        <input class="mc-input" type="date" value="${dStr}" data-rf-date="${f.id}"/>
        ${f.type === 'datetime' ? `<input class="mc-input" type="time" value="${tStr}" data-rf-time="${f.id}" style="max-width:130px;"/>` : ''}
        <input type="hidden" data-field="${f.id}" value="${esc(val || '')}"/>
      </div>`;
    } else if (f.type === 'number' && f.money) {
      ctrl = `<div class="rf-money"><input class="mc-input" type="number" step="0.01" value="${esc(val)}" data-field="${f.id}"/></div>`;
    } else if (f.type === 'number') {
      ctrl = `<input class="mc-input" type="number" value="${esc(val)}" data-field="${f.id}"/>`;
    } else {
      ctrl = `<input class="mc-input${f.mono ? ' font-mono' : ''}" type="text" value="${esc(val)}" data-field="${f.id}" ${f.primary ? 'placeholder="Untitled"' : ''}/>`;
    }
    return `<div class="rf-field${full}">${label}${ctrl}</div>`;
  }
  function coverInner(cover) {
    if (cover.src) return `<img src="${cover.src}" alt=""/>`;
    const h = cover.hue;
    return `<div style="position:absolute; inset:0; background:linear-gradient(160deg, oklch(0.55 0.17 ${h}), oklch(0.38 0.10 ${h}));"></div>`;
  }
  function bindFormField(grid, data) {
    // combine date + time hidden field
    grid.querySelectorAll('[data-rf-date]').forEach(de => {
      const id = de.getAttribute('data-rf-date');
      const te = grid.querySelector(`[data-rf-time="${id}"]`);
      const hidden = grid.querySelector(`input[type="hidden"][data-field="${id}"]`);
      const sync = () => {
        if (!de.value) { hidden.value = ''; data[id] = ''; return; }
        const v = te && te.value ? `${de.value}T${te.value}` : de.value;
        hidden.value = v; data[id] = v;
      };
      de.addEventListener('input', sync); if (te) te.addEventListener('input', sync);
    });
    const replace = grid.querySelector('[data-rf-replace]');
    if (replace) replace.onclick = () => {
      const inp = document.createElement('input'); inp.type = 'file'; inp.accept = 'image/*';
      inp.onchange = () => { const file = inp.files[0]; if (!file) return; const fr = new FileReader(); fr.onload = () => { data.cover = { src: fr.result }; const th = grid.querySelector('#rf-thumb'); th.classList.remove('empty'); th.innerHTML = coverInner(data.cover); }; fr.readAsDataURL(file); };
      inp.click();
    };
    const remove = grid.querySelector('[data-rf-remove]');
    if (remove) remove.onclick = () => { data.cover = null; const th = grid.querySelector('#rf-thumb'); th.classList.add('empty'); th.innerHTML = ICO.image; };
  }

  // ───────────────────────── TOOLBAR ACTIONS ─────────────────────────
  function openSortMenu(anchor) {
    const items = [{ label: 'Sort by', heading: true }];
    S.fields.filter(f => f.type !== 'image').forEach(f => {
      items.push({ label: `${f.label} — A→Z / low→high`, icon: ICO.arrowUp, onClick: () => { S.sort = { field: f.id, dir: 1 }; render(); MCUI.toast(`Sorted by ${f.label} ↑`, 'info', 1500); } });
    });
    items.push({ sep: true });
    items.push({ label: 'Clear sorting', onClick: () => { S.sort = { field: null, dir: 1 }; render(); } });
    MCUI.menu(anchor, items);
  }
  function openColumnsMenu(anchor) {
    const wrap = document.createElement('div');
    wrap.className = 'sdrop'; wrap.style.width = '220px';
    wrap.innerHTML = `<div class="mcui-menu-label">Toggle columns</div><div class="sdrop-list"></div>`;
    const list = wrap.querySelector('.sdrop-list');
    list.innerHTML = S.fields.map(f => `<label class="sdrop-opt" style="cursor:pointer;"><input type="checkbox" ${S.visible.has(f.id) ? 'checked' : ''} data-col="${f.id}" style="accent-color:var(--mc-brand);"/> ${esc(f.label)}</label>`).join('');
    list.querySelectorAll('[data-col]').forEach(cb => cb.onchange = () => {
      if (cb.checked) S.visible.add(cb.getAttribute('data-col')); else S.visible.delete(cb.getAttribute('data-col'));
      if (!S.visible.size) { S.visible.add(cb.getAttribute('data-col')); cb.checked = true; MCUI.toast('At least one column must stay visible', 'err'); return; }
      S.sel = null; render();
    });
    MCUI.popover(anchor, wrap, { align: 'right', width: 220 });
  }
  function openFilterMenu(anchor) {
    const wrap = document.createElement('div');
    wrap.className = 'sdrop'; wrap.style.width = '230px';
    wrap.innerHTML = `
      <div class="mcui-menu-label">Genre</div>
      <div class="sdrop-list" id="flt-genre">${GENRES.map(g => `<label class="sdrop-opt" style="cursor:pointer;"><input type="checkbox" ${S.filters.genre.has(g) ? 'checked' : ''} data-fg="${g}" style="accent-color:var(--mc-brand);"/> ${g}</label>`).join('')}</div>
      <div class="mcui-menu-label" style="margin-top:6px;">Status</div>
      <div class="sdrop-list">${STATUSES.map(s => `<label class="sdrop-opt" style="cursor:pointer;"><input type="checkbox" ${S.filters.status.has(s) ? 'checked' : ''} data-fs="${s}" style="accent-color:var(--mc-brand);"/> ${s}</label>`).join('')}</div>
      <div class="sdrop-add" style="display:flex; gap:8px;"><button class="mc-btn mc-btn-sm mc-btn-ghost" data-clear style="flex:1;">Clear</button></div>`;
    wrap.querySelectorAll('[data-fg]').forEach(cb => cb.onchange = () => { const g = cb.getAttribute('data-fg'); cb.checked ? S.filters.genre.add(g) : S.filters.genre.delete(g); updateFilterBadge(); render(); });
    wrap.querySelectorAll('[data-fs]').forEach(cb => cb.onchange = () => { const s = cb.getAttribute('data-fs'); cb.checked ? S.filters.status.add(s) : S.filters.status.delete(s); updateFilterBadge(); render(); });
    wrap.querySelector('[data-clear]').onclick = () => { S.filters.genre.clear(); S.filters.status.clear(); updateFilterBadge(); render(); MCUI.closeAll(); };
    MCUI.popover(anchor, wrap, { align: 'left', width: 230 });
  }
  function updateFilterBadge() {
    const n = S.filters.genre.size + S.filters.status.size;
    const b = document.querySelector('#flt-badge');
    if (b) { b.textContent = n; b.style.display = n ? 'inline-flex' : 'none'; }
  }

  async function doExport() {
    const n = S.records.filter(r => !r._draft).length;
    const ok = await MCUI.confirm({ title: 'Export records?', message: `All ${n} records in Titles will be exported as a CSV file.`, confirmLabel: 'Export CSV', kind: 'brand' });
    if (!ok) return; MCUI.toast('Export started — check your downloads', 'ok');
  }
  function openImport() {
    const bd = document.createElement('div');
    bd.className = 'mc-modal-backdrop';
    bd.innerHTML = `
      <div class="mc-modal" style="max-width:520px;">
        <div class="mc-modal-head">
          <div><div class="font-display font-bold text-lg">Bulk import CSV</div>
          <div class="text-xs mt-0.5" style="color:var(--mc-text-3);">Map CSV columns to collection fields and append records.</div></div>
          <button class="mc-btn mc-btn-sm mc-btn-icon mc-btn-ghost" data-x>${ICO.x}</button>
        </div>
        <div class="mc-modal-body">
          <label class="mc-label">CSV file</label>
          <div id="imp-drop" style="border:1.5px dashed var(--mc-border-2); border-radius:12px; padding:28px; text-align:center; cursor:pointer; background:var(--mc-surface-2);">
            <div style="color:var(--mc-text-3);">${ICO.down}</div>
            <div class="text-sm mt-2" style="color:var(--mc-text-2);"><b id="imp-name">Click to choose</b> or drag a .csv file here</div>
          </div>
        </div>
        <div class="mc-modal-foot">
          <button class="mc-btn mc-btn-sm mc-btn-ghost" data-x>Cancel</button>
          <button class="mc-btn mc-btn-sm mc-btn-primary" data-imp>Import records</button>
        </div>
      </div>`;
    document.body.appendChild(bd);
    const close = () => bd.remove();
    let picked = false;
    bd.querySelectorAll('[data-x]').forEach(b => b.onclick = close);
    bd.addEventListener('mousedown', e => { if (e.target === bd) close(); });
    bd.querySelector('#imp-drop').onclick = () => { const i = document.createElement('input'); i.type = 'file'; i.accept = '.csv'; i.onchange = () => { if (i.files[0]) { picked = true; bd.querySelector('#imp-name').textContent = i.files[0].name; } }; i.click(); };
    bd.querySelector('[data-imp]').onclick = async () => {
      if (!picked) { MCUI.toast('Choose a CSV file first', 'err'); return; }
      const ok = await MCUI.confirm({ title: 'Import records?', message: 'New records from the CSV will be appended to the Titles collection.', confirmLabel: 'Import', kind: 'brand' });
      if (!ok) return; close(); MCUI.toast('Import queued — records will appear shortly', 'ok');
    };
  }

  async function bulkAction(kind) {
    const ids = [...S.selected];
    if (kind === 'clear') { S.selected.clear(); render(); return; }
    if (kind === 'export') {
      const ok = await MCUI.confirm({ title: `Export ${ids.length} records?`, message: 'The selected records will be exported as CSV.', confirmLabel: 'Export CSV', kind: 'brand' });
      if (ok) MCUI.toast('Export started', 'ok'); return;
    }
    if (kind === 'duplicate') {
      const ok = await MCUI.confirm({ title: `Duplicate ${ids.length} records?`, message: 'Copies will be added to the collection.', confirmLabel: 'Duplicate', kind: 'brand' });
      if (!ok) return;
      ids.forEach(id => { const rec = S.records.find(x => x._id === id); if (rec) { const copy = JSON.parse(JSON.stringify(rec)); copy._id = nid(); copy.title = (rec.title || 'Untitled') + ' (copy)'; S.records.push(copy); } });
      S.selected.clear(); render(); MCUI.toast(`${ids.length} records duplicated`, 'ok'); return;
    }
    if (kind === 'delete') {
      const ok = await MCUI.confirm({ title: `Delete ${ids.length} records?`, message: 'The selected records will be permanently removed. This can’t be undone.', confirmLabel: `Delete ${ids.length} records`, danger: true });
      if (!ok) return;
      S.records = S.records.filter(x => !S.selected.has(x._id)); S.selected.clear(); S.sel = null;
      render(); MCUI.toast('Records deleted', 'ok'); return;
    }
  }

  // ───────────────────────── EVENT WIRING ─────────────────────────
  function wire() {
    const tb = document.querySelector('#rec-tbody');

    // single click → select cell or hit action
    tb.addEventListener('click', (e) => {
      const check = e.target.closest('[data-check]');
      if (check) { const id = check.getAttribute('data-check'); check.checked ? S.selected.add(id) : S.selected.delete(id); render(); return; }
      const edit = e.target.closest('[data-edit]'); if (edit) { openForm(S.records.find(x => x._id === edit.getAttribute('data-edit'))); return; }
      const rmenu = e.target.closest('[data-row-menu]'); if (rmenu) { openRowMenu(rmenu.getAttribute('data-row-menu')); return; }
      const imenu = e.target.closest('[data-img-menu]'); if (imenu) { openImageMenu(imenu.getAttribute('data-img-menu')); return; }
      const ds = e.target.closest('[data-draft-save]'); if (ds) { saveDraft(ds.getAttribute('data-draft-save')); return; }
      const dc = e.target.closest('[data-draft-cancel]'); if (dc) { cancelDraft(dc.getAttribute('data-draft-cancel')); return; }
      const td = e.target.closest('td.rec-td'); if (td && !S.editing) { setSel(+td.getAttribute('data-r'), +td.getAttribute('data-c')); }
    });
    // double click → edit
    tb.addEventListener('dblclick', (e) => {
      const td = e.target.closest('td.rec-td'); if (!td) return;
      startEdit(+td.getAttribute('data-r'), +td.getAttribute('data-c'));
    });

    // header sort
    document.querySelector('#rec-thead').addEventListener('click', (e) => {
      const allCb = e.target.closest('#rec-all'); if (allCb) { return; } // handled by change
      const th = e.target.closest('[data-sort]'); if (!th) return;
      const fid = th.getAttribute('data-sort');
      S.sort = { field: fid, dir: S.sort.field === fid ? -S.sort.dir : 1 };
      S.sel = null; render();
    });
    document.querySelector('#rec-thead').addEventListener('change', (e) => {
      const all = e.target.closest('#rec-all'); if (!all) return;
      const visIds = S.display.filter(r => !r._draft).map(r => r._id);
      if (all.checked) visIds.forEach(id => S.selected.add(id)); else visIds.forEach(id => S.selected.delete(id));
      render();
    });

    // bulk bar
    document.querySelector('#rec-bulkbar').addEventListener('click', (e) => { const b = e.target.closest('[data-bulk]'); if (b) bulkAction(b.getAttribute('data-bulk')); });

    // toolbar
    const search = document.querySelector('#rec-search');
    if (search) search.addEventListener('input', () => { S.search = search.value; S.sel = null; render(); });
    document.querySelector('#btn-filters').onclick = (e) => openFilterMenu(e.currentTarget);
    document.querySelector('#btn-sort').onclick = (e) => openSortMenu(e.currentTarget);
    document.querySelector('#btn-columns').onclick = (e) => openColumnsMenu(e.currentTarget);
    document.querySelector('#btn-export').onclick = doExport;
    document.querySelector('#btn-import').onclick = openImport;

    // header + bottom new record
    document.querySelector('#btn-new-record').onclick = () => openForm(null);
    document.querySelector('#btn-add-row').onclick = addDraftRow;

    // manage fields / add field via collection-flow
    const mf = document.querySelector('#btn-manage-fields'); if (mf) mf.onclick = () => window.CF && CF.openPanel();
    const af = document.querySelector('#btn-add-field'); if (af) af.onclick = () => window.CF && CF.openChooseType();

    // pagination (visual only)
    document.querySelectorAll('[data-page]').forEach(b => b.onclick = () => { document.querySelectorAll('[data-page]').forEach(x => x.classList.remove('is-page-active')); b.classList.add('is-page-active'); });

    document.addEventListener('keydown', onKey);
  }

  // ───────────────────────── INIT ─────────────────────────
  document.addEventListener('DOMContentLoaded', () => {
    // read ?name= for the header (which collection card was clicked)
    const params = new URLSearchParams(location.search);
    const name = params.get('name');
    const slug = params.get('c') || 'titles';
    if (name) {
      const h = document.querySelector('#coll-name'); if (h) h.textContent = name;
      const api = document.querySelector('#coll-api'); if (api) api.textContent = '/ api / ' + slug;
      const crumb = document.querySelector('#crumb-coll'); if (crumb) crumb.textContent = name;
      document.title = `MangoCMS — ${name}`;
    }
    wire();
    render();
  });

  window.REC = S;
})();
