// QuoteAssist — Quotes screen on the shared list engine (qa-listkit.js).
// Table (default) · Cards · List views, with search + multi filter/sort + paging.

(function () {
  'use strict';

  var SEED = [
    { ref: 'QA-1478', customer: 'Diaz Family',      route: 'MAD–CUN', dates: '02–16 Jul',     pax: '2A·1C', total: '£4,820',  status: 'Sent',     created: '1 h ago',     age: 1 },
    { ref: 'QA-1477', customer: 'Marcus Webb',      route: 'LHR–JFK', dates: '03–07 Oct',     pax: '1A',    total: '£3,290',  status: 'Sent',     created: '3 h ago',     age: 3 },
    { ref: 'QA-1476', customer: 'Okonkwo & Co.',    route: 'LOS–DXB', dates: '19–24 Sep',     pax: '3A',    total: '£7,410',  status: 'Accepted', created: 'yesterday',   age: 24 },
    { ref: 'QA-1475', customer: 'Claire Laurent',   route: 'CDG–FCO', dates: '12–19 Sep',     pax: '2A',    total: '£2,140',  status: 'Expired',  created: '2 d ago',     age: 48 },
    { ref: 'QA-1474', customer: 'H. Tanaka',        route: 'HND–SIN', dates: '08–15 Nov',     pax: '2A',    total: '£3,980',  status: 'Sent',     created: '2 d ago',     age: 50 },
    { ref: 'QA-1473', customer: 'Greenwood School', route: 'LHR–BCN', dates: '14–18 Apr',     pax: '9A',    total: '£11,250', status: 'Accepted', created: '3 d ago',     age: 72 },
    { ref: 'QA-1472', customer: 'P. Andersen',      route: 'CPH–BKK', dates: '21 Dec–04 Jan', pax: '2A·2C', total: '£6,740',  status: 'Draft',    created: '4 d ago',     age: 96 },
    { ref: 'QA-1471', customer: 'Riveras',          route: 'LIS–GIG', dates: '10–24 Aug',     pax: '2A',    total: '£4,100',  status: 'Expired',  created: '5 d ago',     age: 120 }
  ];
  var STATUS = ['Draft', 'Sent', 'Accepted', 'Expired'];
  function num(t) { return parseFloat(String(t || '').replace(/[^0-9.]/g, '')) || 0; }
  var $ = function (s) { return document.querySelector(s); };

  function load() {
    var saved = [];
    try { saved = JSON.parse(localStorage.getItem('qa-quotes') || '[]'); } catch (e) {}
    saved = saved.map(function (s) {
      return { ref: s.ref, customer: s.customer || (s.dest ? s.dest + ' enquiry' : 'New enquiry'), route: s.route, dates: s.dates, pax: s.pax, total: s.total, status: s.status || 'Draft', created: s.created || 'just now', age: 0, saved: true };
    });
    return saved.concat(SEED);
  }

  function statusEl(st) {
    var cls = st === 'Sent' ? 'mc-status-live' : st === 'Draft' ? 'mc-status-draft' : st === 'Accepted' ? '' : 'mc-status-error';
    var style = st === 'Accepted' ? ' style="color:var(--mc-success);"' : '';
    var dot = st === 'Accepted' ? '<span style="width:6px;height:6px;border-radius:99px;background:var(--mc-success);box-shadow:0 0 0 3px color-mix(in oklch,var(--mc-success) 18%,transparent);"></span>' : '';
    return '<span class="mc-status ' + cls + '"' + style + '>' + (st === 'Accepted' ? dot : '') + st + '</span>';
  }
  var openIcon = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17L17 7M9 7h8v8"/></svg>';
  var delIcon = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/></svg>';
  function actions(q) {
    return '<a href="quote-detail.html" class="mc-btn mc-btn-sm mc-btn-ghost mc-btn-icon" title="Open">' + openIcon + '</a>' +
      '<button class="mc-btn mc-btn-sm mc-btn-ghost mc-btn-icon qa-del" data-ref="' + q.ref + '" data-saved="' + (q.saved ? 1 : 0) + '" title="Delete">' + delIcon + '</button>';
  }
  var newBadge = ' <span class="mc-badge mc-badge-brand" style="margin-left:4px;">new</span>';

  /* ── views ── */
  function viewTable(items) {
    var rows = items.map(function (q) {
      return '<tr>' +
        '<td class="font-mono text-xs" style="color:var(--mc-brand);">' + q.ref + (q.saved ? newBadge : '') + '</td>' +
        '<td>' + q.customer + '</td>' +
        '<td class="font-mono text-xs">' + q.route + '</td>' +
        '<td class="text-xs" style="color:var(--mc-text-2);">' + q.dates + '</td>' +
        '<td class="font-mono text-xs">' + q.pax + '</td>' +
        '<td class="num">' + q.total + '</td>' +
        '<td>' + statusEl(q.status) + '</td>' +
        '<td class="text-xs" style="color:var(--mc-text-2);">' + q.created + '</td>' +
        '<td><div class="flex items-center gap-1 justify-end">' + actions(q) + '</div></td></tr>';
    }).join('');
    return '<div class="mc-card overflow-hidden"><table class="mc-table"><thead><tr>' +
      '<th>Reference</th><th>Customer</th><th>Route</th><th>Travel dates</th><th>Pax</th><th class="num">Total</th><th>Status</th><th>Created</th><th></th>' +
      '</tr></thead><tbody>' + rows + '</tbody></table></div>';
  }
  function viewCards(items) {
    return '<div class="qa-cardgrid">' + items.map(function (q) {
      return '<div class="qa-dcard qa-qcard">' +
        '<div class="qa-qcard-top"><div><div class="qa-qcard-ref">' + q.ref + (q.saved ? newBadge : '') + '</div>' +
        '<div class="qa-qcard-name">' + q.customer + '</div>' +
        '<div class="qa-qcard-route">' + q.route + ' · ' + q.pax + '</div></div>' + statusEl(q.status) + '</div>' +
        '<div class="text-xs" style="color:var(--mc-text-3);">' + q.dates + ' · created ' + q.created + '</div>' +
        '<div class="qa-qcard-meta"><span class="qa-qcard-total">' + q.total + '</span>' +
        '<div class="qa-qcard-actions">' + actions(q) + '</div></div></div>';
    }).join('') + '</div>';
  }
  function viewList(items) {
    return '<div class="qa-listwrap">' + items.map(function (q) {
      return '<div class="qa-listrow">' +
        '<span class="font-mono text-xs" style="color:var(--mc-brand); width:70px; flex-shrink:0;">' + q.ref + '</span>' +
        '<div style="flex:1; min-width:0;"><div class="text-sm font-semibold truncate">' + q.customer + (q.saved ? newBadge : '') + '</div>' +
        '<div class="font-mono text-[11px]" style="color:var(--mc-text-3);">' + q.route + ' · ' + q.dates + '</div></div>' +
        '<span class="font-mono text-sm" style="width:84px; text-align:right;">' + q.total + '</span>' +
        '<span style="width:96px;">' + statusEl(q.status) + '</span>' +
        '<span class="text-xs" style="color:var(--mc-text-3); width:74px; text-align:right;">' + q.created + '</span>' +
        '<div class="flex items-center gap-1">' + actions(q) + '</div></div>';
    }).join('') + '</div>';
  }

  function toast(msg) {
    var el = $('#toast'); el.style.display = 'flex';
    el.innerHTML = '<span style="color:var(--mc-brand);">ℹ</span><span class="text-sm font-medium">' + msg + '</span>';
    clearTimeout(el._t); el._t = setTimeout(function () { el.style.display = 'none'; }, 2200);
  }

  var ctrl;
  function bindDeletes(body) {
    body.querySelectorAll('.qa-del').forEach(function (b) {
      b.addEventListener('click', function () {
        var ref = b.dataset.ref;
        if (b.dataset.saved === '1') { try { var l = JSON.parse(localStorage.getItem('qa-quotes') || '[]').filter(function (x) { return x.ref !== ref; }); localStorage.setItem('qa-quotes', JSON.stringify(l)); } catch (e) {} }
        else { SEED = SEED.filter(function (x) { return x.ref !== ref; }); }
        ctrl.refresh(); toast(ref + ' deleted.');
      });
    });
  }

  function init() {
    ctrl = window.QAList({
      mount: 'quotesList',
      key: 'quotes',
      noun: 'quote',
      searchPlaceholder: 'Search ref, customer, route…',
      views: ['table', 'cards', 'list'],
      defaultView: 'table',
      pageSize: 5,
      emptyTitle: 'No quotes match.',
      filterFields: {
        status:   { label: 'Status',     type: 'enum',   ops: ['is', 'is not'], options: STATUS },
        customer: { label: 'Customer',   type: 'text',   ops: ['contains', 'does not contain'] },
        route:    { label: 'Route',      type: 'text',   ops: ['contains', 'does not contain'] },
        pax:      { label: 'Passengers', type: 'text',   ops: ['contains', 'does not contain'] },
        total:    { label: 'Total',      type: 'number', ops: ['greater than', 'less than'], prefix: '£', get: function (q) { return num(q.total); } },
        created:  { label: 'Created',    type: 'age',    ops: ['within'], get: function (q) { return q.age; } }
      },
      filterOrder: ['status', 'customer', 'route', 'pax', 'total', 'created'],
      sortFields: {
        created:  { label: 'Created',   key: function (q) { return q.age; },        dir: ['Newest', 'Oldest'],         numeric: true },
        total:    { label: 'Total',     key: function (q) { return num(q.total); }, dir: ['Low → High', 'High → Low'], numeric: true },
        customer: { label: 'Customer',  key: function (q) { return q.customer; },   dir: ['A → Z', 'Z → A'] },
        ref:      { label: 'Reference', key: function (q) { return q.ref; },        dir: ['A → Z', 'Z → A'] },
        status:   { label: 'Status',    key: function (q) { return STATUS.indexOf(q.status); }, dir: ['Draft → Expired', 'Expired → Draft'], numeric: true }
      },
      sortOrder: ['created', 'total', 'customer', 'ref', 'status'],
      searchText: function (q) { return q.ref + ' ' + q.customer + ' ' + q.route; },
      getData: load,
      renderView: function (view, items) { return view === 'cards' ? viewCards(items) : view === 'list' ? viewList(items) : viewTable(items); },
      onRendered: function (view, items, body) { bindDeletes(body); }
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
