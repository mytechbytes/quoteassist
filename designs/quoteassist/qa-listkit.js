// QuoteAssist — shared list engine. One toolbar (search left · filter/sort/view
// right), config-driven multi-condition filtering + sorting, view switching and
// pagination. Each screen supplies data + per-view renderers.

(function () {
  'use strict';

  function lsRead(k, d) { try { var v = JSON.parse(localStorage.getItem('qa-lk:' + k)); return v == null ? d : v; } catch (e) { return d; } }
  function lsWrite(k, v) { try { localStorage.setItem('qa-lk:' + k, JSON.stringify(v)); } catch (e) {} }
  function num(t) { return parseFloat(String(t == null ? '' : t).replace(/[^0-9.\-]/g, '')) || 0; }

  var ICON = {
    search: '<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>',
    filter: '<path d="M3 5h18M6 12h12M10 19h4"/>',
    sort:   '<path d="M7 4v16M7 20l-3-3M7 4l3 3M17 20V4M17 4l-3 3M17 20l3-3"/>',
    table:  '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18M9 4v16"/>',
    cards:  '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    list:   '<path d="M8 6h13M8 12h13M8 18h13"/><circle cx="4" cy="6" r="1.3"/><circle cx="4" cy="12" r="1.3"/><circle cx="4" cy="18" r="1.3"/>',
    chevL:  '<polyline points="15 18 9 12 15 6"/>',
    chevR:  '<polyline points="9 18 15 12 9 6"/>'
  };
  var VIEW_LABEL = { table: 'Table', cards: 'Cards', list: 'List' };
  function svg(p, sz) { sz = sz || 14; return '<svg width="' + sz + '" height="' + sz + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + p + '</svg>'; }
  function uid() { return 'c' + Math.random().toString(36).slice(2, 8); }

  var AGE_BUCKETS = [
    { v: '24h',   l: 'the last 24 hours', max: 24 },
    { v: '7d',    l: 'the last 7 days',   max: 168 },
    { v: 'older', l: 'older than 7 days', max: Infinity }
  ];

  window.QAList = function (cfg) {
    var key = cfg.key, pageSize = cfg.pageSize || 5, noun = cfg.noun || 'record';
    var FF = cfg.filterFields || {}, FO = cfg.filterOrder || Object.keys(FF);
    var SF = cfg.sortFields || {}, SO = cfg.sortOrder || Object.keys(SF);
    var views = cfg.views || ['table'];

    var S = {
      filters: lsRead(key + ':f', []),
      sorts:   lsRead(key + ':s', []),
      view:    lsRead(key + ':v', cfg.defaultView || views[0]),
      term: '', page: 1
    };
    if (views.indexOf(S.view) < 0) S.view = cfg.defaultView || views[0];
    S.filters = S.filters.filter(function (f) { return FF[f.field]; }).map(function (f) { f.id = f.id || uid(); return normF(f); });
    S.sorts = S.sorts.filter(function (s) { return SF[s.field]; }).map(function (s) { s.id = s.id || uid(); if (s.dir !== 'asc' && s.dir !== 'desc') s.dir = 'asc'; return s; });

    var mount = typeof cfg.mount === 'string' ? document.getElementById(cfg.mount) : cfg.mount;
    mount.classList.add('qa-lk');
    mount.innerHTML =
      '<div class="qa-lk-bar">' +
        '<div class="qa-lk-search">' + svg(ICON.search) + '<input type="text" placeholder="' + (cfg.searchPlaceholder || 'Search…') + '"/></div>' +
        '<div class="qa-lk-actions">' +
          (Object.keys(FF).length ? '<button class="qa-tool" data-act="filter">' + svg(ICON.filter) + 'Filter<span class="qa-num"></span></button>' : '') +
          (Object.keys(SF).length ? '<button class="qa-tool" data-act="sort">' + svg(ICON.sort) + 'Sort<span class="qa-num"></span></button>' : '') +
          (views.length > 1 ? '<div class="qa-viewseg">' + views.map(function (v) { return '<button data-view="' + v + '" title="' + VIEW_LABEL[v] + ' view" aria-label="' + VIEW_LABEL[v] + ' view">' + svg(ICON[v], 15) + '</button>'; }).join('') + '</div>' : '') +
        '</div>' +
      '</div>' +
      '<div class="qa-lk-chips"></div>' +
      '<div class="qa-lk-body"></div>' +
      '<div class="qa-lk-foot"></div>';

    var elSearch = mount.querySelector('.qa-lk-search input');
    var elChips = mount.querySelector('.qa-lk-chips');
    var elBody = mount.querySelector('.qa-lk-body');
    var elFoot = mount.querySelector('.qa-lk-foot');
    var fBtn = mount.querySelector('[data-act="filter"]');
    var sBtn = mount.querySelector('[data-act="sort"]');

    elSearch.addEventListener('input', function () { S.term = this.value.trim().toLowerCase(); S.page = 1; apply(); });
    if (fBtn) fBtn.addEventListener('click', function () { togglePop('filter'); });
    if (sBtn) sBtn.addEventListener('click', function () { togglePop('sort'); });
    mount.querySelectorAll('[data-view]').forEach(function (b) {
      b.addEventListener('click', function () { S.view = b.dataset.view; lsWrite(key + ':v', S.view); S.page = 1; closePop(); apply(); });
    });

    /* ── filter helpers ── */
    function normF(f) {
      var c = FF[f.field]; if (!c) return f;
      if (c.ops.indexOf(f.op) < 0) f.op = c.ops[0];
      if (c.type === 'enum' && (c.options || []).indexOf(f.value) < 0) f.value = c.options[0];
      if (c.type === 'age' && !AGE_BUCKETS.some(function (b) { return b.v === f.value; })) f.value = AGE_BUCKETS[0].v;
      if ((c.type === 'text' || c.type === 'number') && typeof f.value !== 'string' && typeof f.value !== 'number') f.value = '';
      return f;
    }
    function getVal(item, field) { var c = FF[field]; return c && c.get ? c.get(item) : item[field]; }
    function matchOne(item, f) {
      var c = FF[f.field]; if (!c) return true; var val = getVal(item, f.field);
      if (c.type === 'enum') return f.op === 'is' ? val === f.value : val !== f.value;
      if (c.type === 'text') { var hay = String(val == null ? '' : val).toLowerCase(); var hit = hay.indexOf(String(f.value || '').toLowerCase()) >= 0; return f.op === 'contains' ? hit : !hit; }
      if (c.type === 'number') { var n = num(val), v = parseFloat(f.value); if (isNaN(v)) return true; return f.op === 'greater than' ? n > v : n < v; }
      if (c.type === 'age') { var b = AGE_BUCKETS.filter(function (x) { return x.v === f.value; })[0] || AGE_BUCKETS[0]; var prev = AGE_BUCKETS[AGE_BUCKETS.indexOf(b) - 1]; var lo = prev ? prev.max : -Infinity; var h = num(val); return h > lo && h <= b.max; }
      return true;
    }
    function matchAll(item) {
      for (var i = 0; i < S.filters.length; i++) { if (!matchOne(item, S.filters[i])) return false; }
      if (S.term && cfg.searchText) { if (cfg.searchText(item).toLowerCase().indexOf(S.term) < 0) return false; }
      return true;
    }
    function sortData(arr) {
      if (!S.sorts.length) return arr;
      return arr.slice().sort(function (a, b) {
        for (var i = 0; i < S.sorts.length; i++) {
          var s = S.sorts[i], c = SF[s.field]; if (!c) continue;
          var av = c.key(a), bv = c.key(b), cmp;
          if (c.numeric) cmp = av - bv; else cmp = String(av).localeCompare(String(bv));
          if (cmp !== 0) return s.dir === 'desc' ? -cmp : cmp;
        }
        return 0;
      });
    }

    /* ── render ── */
    function apply() {
      var all = sortData(cfg.getData().filter(matchAll));
      var total = all.length;
      var pages = Math.max(1, Math.ceil(total / pageSize));
      if (S.page > pages) S.page = pages;
      if (S.page < 1) S.page = 1;
      var slice = total > pageSize ? all.slice((S.page - 1) * pageSize, S.page * pageSize) : all;

      elBody.innerHTML = total ? cfg.renderView(S.view, slice, all) : emptyHTML();
      if (total && cfg.onRendered) cfg.onRendered(S.view, slice, elBody);

      mount.querySelectorAll('[data-view]').forEach(function (b) { b.classList.toggle('on', b.dataset.view === S.view); });
      if (fBtn) { var fn = fBtn.querySelector('.qa-num'); fn.style.display = S.filters.length ? 'inline-grid' : 'none'; fn.textContent = S.filters.length; }
      if (sBtn) { var sn = sBtn.querySelector('.qa-num'); sn.style.display = S.sorts.length ? 'inline-grid' : 'none'; sn.textContent = S.sorts.length; }
      renderChips();
      renderFoot(total, pages);
      if (openName === 'filter') buildFilterPop(); if (openName === 'sort') buildSortPop();
    }

    function emptyHTML() {
      return '<div class="qa-lk-empty"><div class="qa-lk-empty-t">' + (cfg.emptyTitle || 'Nothing to show.') + '</div>' +
        '<div class="qa-lk-empty-s">' + (cfg.emptyHint || 'Try a different filter or search term.') + '</div></div>';
    }

    function renderFoot(total, pages) {
      var label = total + ' ' + noun + (total === 1 ? '' : 's');
      var pager = '';
      if (total > pageSize) {
        pager = '<div class="qa-pager"><button class="qa-pg" data-pg="prev"' + (S.page <= 1 ? ' disabled' : '') + '>' + svg(ICON.chevL, 13) + '</button>';
        for (var p = 1; p <= pages; p++) pager += '<button class="qa-pg-n' + (p === S.page ? ' on' : '') + '" data-pg="' + p + '">' + p + '</button>';
        pager += '<button class="qa-pg" data-pg="next"' + (S.page >= pages ? ' disabled' : '') + '>' + svg(ICON.chevR, 13) + '</button></div>';
        var from = (S.page - 1) * pageSize + 1, to = Math.min(total, S.page * pageSize);
        label = from + '–' + to + ' of ' + total + ' ' + noun + 's';
      }
      elFoot.innerHTML = '<span class="qa-foot-count">' + label + '</span>' + pager;
      elFoot.querySelectorAll('[data-pg]').forEach(function (b) {
        b.addEventListener('click', function () {
          var v = b.dataset.pg;
          if (v === 'prev') S.page = Math.max(1, S.page - 1);
          else if (v === 'next') S.page = Math.min(pages, S.page + 1);
          else S.page = parseInt(v, 10);
          apply();
        });
      });
    }

    /* ── chips ── */
    function fSummary(f) {
      var c = FF[f.field], val = f.value;
      if (c.type === 'age') { var b = AGE_BUCKETS.filter(function (x) { return x.v === f.value; })[0]; val = b ? b.l : f.value; }
      else if (c.type === 'number') val = (c.prefix || '') + f.value;
      return '<b>' + c.label + '</b> ' + f.op + ' ' + val;
    }
    function sSummary(s) {
      var c = SF[s.field], di = s.dir === 'desc' ? 1 : 0;
      return (di ? '↓' : '↑') + ' <b>' + c.label + '</b> · ' + c.dir[di];
    }
    function renderChips() {
      var html = '';
      S.filters.forEach(function (f) { html += '<button class="qa-chip" data-edit="filter">' + fSummary(f) + '<span class="qa-chip-x" data-rmf="' + f.id + '" title="Remove">&times;</span></button>'; });
      S.sorts.forEach(function (s) { html += '<button class="qa-chip qa-chip-sort" data-edit="sort">' + sSummary(s) + '<span class="qa-chip-x" data-rms="' + s.id + '" title="Remove">&times;</span></button>'; });
      if ((S.filters.length + S.sorts.length) > 1) html += '<button class="qa-chip-clear" data-clearall>Clear all</button>';
      elChips.innerHTML = html;
      elChips.style.display = html ? 'flex' : 'none';
      elChips.querySelectorAll('[data-rmf]').forEach(function (x) { x.addEventListener('click', function (e) { e.stopPropagation(); S.filters = S.filters.filter(function (f) { return f.id !== x.dataset.rmf; }); persist(); S.page = 1; apply(); }); });
      elChips.querySelectorAll('[data-rms]').forEach(function (x) { x.addEventListener('click', function (e) { e.stopPropagation(); S.sorts = S.sorts.filter(function (s) { return s.id !== x.dataset.rms; }); persist(); apply(); }); });
      elChips.querySelectorAll('[data-edit]').forEach(function (b) { b.addEventListener('click', function () { openPop(b.dataset.edit); }); });
      var ca = elChips.querySelector('[data-clearall]'); if (ca) ca.addEventListener('click', function () { S.filters = []; S.sorts = []; persist(); S.page = 1; apply(); });
    }
    function persist() { lsWrite(key + ':f', S.filters); lsWrite(key + ':s', S.sorts); }

    /* ── popovers ── */
    var openName = null, pop = null;
    function miniSelect(name, value, opts) {
      return '<select class="qa-mini" data-k="' + name + '">' + opts.map(function (o) { return '<option value="' + o.v + '"' + (o.v === value ? ' selected' : '') + '>' + o.l + '</option>'; }).join('') + '</select>';
    }
    function valueControl(f) {
      var c = FF[f.field];
      if (c.type === 'enum') return miniSelect('value', f.value, c.options.map(function (s) { return { v: s, l: s }; }));
      if (c.type === 'age') return miniSelect('value', f.value, AGE_BUCKETS.map(function (b) { return { v: b.v, l: b.l }; }));
      if (c.type === 'number') return '<input class="qa-mini qa-grow" data-k="value" type="number" placeholder="0" value="' + (f.value || '') + '"/>';
      return '<input class="qa-mini qa-grow" data-k="value" placeholder="value…" value="' + (f.value || '') + '"/>';
    }
    function defaultFilter() { var field = FO[0]; var c = FF[field]; return normF({ id: uid(), field: field, op: c.ops[0], value: '' }); }
    function defaultSort() { var used = S.sorts.map(function (s) { return s.field; }); var field = SO.filter(function (k) { return used.indexOf(k) < 0; })[0] || SO[0]; return { id: uid(), field: field, dir: 'asc' }; }

    function buildFilterPop() {
      var rows = S.filters.map(function (f) {
        var c = FF[f.field];
        return '<div class="qa-pop-row" data-id="' + f.id + '">' +
          miniSelect('field', f.field, FO.map(function (k) { return { v: k, l: FF[k].label }; })) +
          miniSelect('op', f.op, c.ops.map(function (o) { return { v: o, l: o }; })) +
          valueControl(f) +
          '<button class="qa-pop-rm" data-rm="' + f.id + '" title="Remove">&times;</button></div>';
      }).join('');
      pop.innerHTML =
        '<div class="qa-pop-head">Filters' + (S.filters.length ? '<button class="qa-pop-clear" data-clear>Clear</button>' : '') + '</div>' +
        '<div class="qa-pop-body">' + (rows || '<div class="qa-pop-empty">No filters yet.</div>') + '</div>' +
        '<div class="qa-pop-foot"><button class="qa-pop-add" data-add><span>+</span> Add filter</button></div>';
      pop.querySelectorAll('.qa-pop-row').forEach(function (row) {
        var id = row.dataset.id;
        row.querySelectorAll('[data-k]').forEach(function (ctrl) {
          ctrl.addEventListener(ctrl.tagName === 'SELECT' ? 'change' : 'input', function () {
            var f = S.filters.filter(function (x) { return x.id === id; })[0]; if (!f) return;
            f[ctrl.dataset.k] = ctrl.value;
            if (ctrl.dataset.k === 'field') normF(f);
            persist(); S.page = 1;
            if (ctrl.dataset.k === 'field') buildFilterPop();
            apply();
          });
        });
        row.querySelector('[data-rm]').addEventListener('click', function () { S.filters = S.filters.filter(function (x) { return x.id !== id; }); persist(); S.page = 1; buildFilterPop(); apply(); });
      });
      pop.querySelector('[data-add]').addEventListener('click', function () { S.filters.push(defaultFilter()); persist(); S.page = 1; buildFilterPop(); apply(); });
      var c = pop.querySelector('[data-clear]'); if (c) c.addEventListener('click', function () { S.filters = []; persist(); S.page = 1; buildFilterPop(); apply(); });
      place(fBtn);
    }
    function buildSortPop() {
      var rows = S.sorts.map(function (s) {
        var c = SF[s.field];
        return '<div class="qa-pop-row" data-id="' + s.id + '">' +
          miniSelect('field', s.field, SO.map(function (k) { return { v: k, l: SF[k].label }; })) +
          '<div class="qa-dir qa-grow" data-id="' + s.id + '"><button data-dir="asc" class="' + (s.dir === 'asc' ? 'on' : '') + '">' + c.dir[0] + '</button><button data-dir="desc" class="' + (s.dir === 'desc' ? 'on' : '') + '">' + c.dir[1] + '</button></div>' +
          '<button class="qa-pop-rm" data-rm="' + s.id + '" title="Remove">&times;</button></div>';
      }).join('');
      pop.innerHTML =
        '<div class="qa-pop-head">Sort' + (S.sorts.length ? '<button class="qa-pop-clear" data-clear>Clear</button>' : '') + '</div>' +
        '<div class="qa-pop-body">' + (rows || '<div class="qa-pop-empty">No sorting applied.</div>') + '</div>' +
        '<div class="qa-pop-foot"><button class="qa-pop-add" data-add' + (S.sorts.length >= SO.length ? ' disabled' : '') + '><span>+</span> Add sort</button></div>';
      pop.querySelectorAll('.qa-pop-row').forEach(function (row) {
        var id = row.dataset.id;
        row.querySelector('[data-k="field"]').addEventListener('change', function () { var s = S.sorts.filter(function (x) { return x.id === id; })[0]; if (!s) return; s.field = this.value; persist(); buildSortPop(); apply(); });
        row.querySelectorAll('[data-dir]').forEach(function (btn) { btn.addEventListener('click', function () { var s = S.sorts.filter(function (x) { return x.id === id; })[0]; if (!s) return; s.dir = btn.dataset.dir; persist(); buildSortPop(); apply(); }); });
        row.querySelector('[data-rm]').addEventListener('click', function () { S.sorts = S.sorts.filter(function (x) { return x.id !== id; }); persist(); buildSortPop(); apply(); });
      });
      var add = pop.querySelector('[data-add]'); if (add && !add.disabled) add.addEventListener('click', function () { S.sorts.push(defaultSort()); persist(); buildSortPop(); apply(); });
      var c = pop.querySelector('[data-clear]'); if (c) c.addEventListener('click', function () { S.sorts = []; persist(); buildSortPop(); apply(); });
      place(sBtn);
    }
    function place(anchor) {
      var r = anchor.getBoundingClientRect();
      pop.style.top = (r.bottom + 7) + 'px';
      var left = r.right - pop.offsetWidth;
      pop.style.left = Math.max(12, left) + 'px';
    }
    function openPop(name) {
      closePop();
      pop = document.createElement('div'); pop.className = 'qa-pop qa-pop-fixed'; document.body.appendChild(pop);
      openName = name;
      if (name === 'filter') { if (!S.filters.length) { S.filters.push(defaultFilter()); persist(); } buildFilterPop(); apply(); }
      else { if (!S.sorts.length) { S.sorts.push(defaultSort()); persist(); } buildSortPop(); apply(); }
      setTimeout(function () { document.addEventListener('mousedown', outside); window.addEventListener('resize', closePop); }, 0);
    }
    function togglePop(name) { if (openName === name) closePop(); else openPop(name); }
    function closePop() { if (pop) pop.remove(); pop = null; openName = null; document.removeEventListener('mousedown', outside); window.removeEventListener('resize', closePop); }
    function outside(e) {
      if (!pop) return;
      if (pop.contains(e.target)) return;
      if (e.target.closest('[data-act]')) return;
      if (e.target.closest('.qa-chip')) return;
      closePop();
    }

    apply();
    return { refresh: apply, state: S, closePop: closePop };
  };
})();
