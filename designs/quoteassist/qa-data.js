// QuoteAssist v2 — shared domain model + persistence for the multi-tenant,
// multi-vertical platform. Verticals, agencies (tenants), seller levels, the
// discount-quota matrix, deals, approval requests and the activity log all live
// here, persisted to localStorage under the "qa2-*" namespace. Every persona
// app (Site Admin / Agency / Sales) reads and writes through window.QAData.

(function () {
  'use strict';

  /* ───────────────── verticals (platform catalog) ───────────────── */
  // Each vertical carries the noun for a deal, the money unit, and the pricing
  // categories that discount quotas are defined against.
  var VERTICALS = {
    airline:    { id: 'airline',    name: 'Airline & Travel',     deal: 'quote',  dealPlural: 'quotes',   unit: '£', icon: '<path d="M21 16v-2l-8-5V3.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/>', categories: ['Economy', 'Premium', 'Business', 'First'] },
    product:    { id: 'product',    name: 'Product & Wholesale',  deal: 'order',  dealPlural: 'orders',   unit: '£', icon: '<path d="M3 9l1-5h16l1 5"/><path d="M4 9v11h16V9"/><path d="M9 13h6"/>', categories: ['Electronics', 'Apparel', 'Home & Living', 'Industrial'] },
    medical:    { id: 'medical',    name: 'Medical & Pharma',     deal: 'order',  dealPlural: 'orders',   unit: '£', icon: '<path d="M12 7v10M7 12h10"/><rect x="3" y="3" width="18" height="18" rx="3"/>', categories: ['Devices', 'Consumables', 'Pharmaceuticals', 'Lab Equipment'] },
    saas:       { id: 'saas',       name: 'SaaS & Subscriptions', deal: 'deal',   dealPlural: 'deals',    unit: '$', icon: '<path d="M18 10a4 4 0 0 0-1-7.8A6 6 0 0 0 6 7a4.5 4.5 0 0 0 .5 9H18a3 3 0 0 0 0-6z"/>', categories: ['Starter', 'Pro', 'Enterprise', 'Add-ons'] },
    insurance:  { id: 'insurance',  name: 'Insurance',            deal: 'policy', dealPlural: 'policies', unit: '£', icon: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>', categories: ['Auto', 'Home', 'Life', 'Commercial'] },
    automotive: { id: 'automotive', name: 'Automotive',           deal: 'deal',   dealPlural: 'deals',    unit: '£', icon: '<path d="M5 13l1.5-4.5A2 2 0 0 1 8.4 7h7.2a2 2 0 0 1 1.9 1.5L19 13M5 13h14v5H5z"/><circle cx="7.5" cy="18" r="1.5"/><circle cx="16.5" cy="18" r="1.5"/>', categories: ['New Vehicles', 'Used Vehicles', 'Parts', 'Service'] }
  };
  var VERTICAL_ORDER = ['airline', 'product', 'medical', 'saas', 'insurance', 'automotive'];

  /* ───────────────── plans ───────────────── */
  var PLANS = {
    Starter:    { seats: 5,   price: 49 },
    Growth:     { seats: 20,  price: 149 },
    Scale:      { seats: 60,  price: 399 },
    Enterprise: { seats: 250, price: 1200 }
  };

  /* ───────────────── seller levels ───────────────── */
  // The role/level an agency assigns its salespeople; quotas are set per level.
  var LEVELS = ['Junior', 'Senior', 'Lead'];

  /* ───────────────── platform discount guardrails ───────────────── */
  // Hard ceilings the Site Admin sets per vertical — no tenant cap may exceed.
  var DEFAULT_GUARDRAILS = { airline: 20, product: 30, medical: 18, saas: 40, insurance: 15, automotive: 22 };

  /* ───────────────── seed: tenants (agencies) ───────────────── */
  function seedTenants() {
    return [
      { id: 't_northwind', name: 'Northwind Supply',  vertical: 'product',    plan: 'Growth',     seatsUsed: 14, status: 'active',    mrr: 149,  created: 'Mar 2024', owner: 'Daniel Reyes',  region: 'UK' },
      { id: 't_skyline',   name: 'Skyline Travel',    vertical: 'airline',    plan: 'Scale',      seatsUsed: 38, status: 'active',    mrr: 399,  created: 'Nov 2023', owner: 'Rana Aziz',     region: 'UK' },
      { id: 't_meridian',  name: 'Meridian MedTech',  vertical: 'medical',    plan: 'Enterprise', seatsUsed: 142,status: 'active',    mrr: 1200, created: 'Jun 2023', owner: 'Dr. Lena Cho',  region: 'EU' },
      { id: 't_cloudpeak', name: 'Cloudpeak SaaS',    vertical: 'saas',       plan: 'Growth',     seatsUsed: 9,  status: 'trial',     mrr: 0,    created: 'May 2024', owner: 'Ari Patel',     region: 'US' },
      { id: 't_sterling',  name: 'Sterling Insure',   vertical: 'insurance',  plan: 'Scale',      seatsUsed: 51, status: 'active',    mrr: 399,  created: 'Jan 2024', owner: 'Grace Hughes',  region: 'UK' },
      { id: 't_autonova',  name: 'AutoNova Motors',   vertical: 'automotive', plan: 'Starter',    seatsUsed: 4,  status: 'active',    mrr: 49,   created: 'Apr 2024', owner: 'Marco Bellini', region: 'EU' },
      { id: 't_globus',    name: 'Globus Tours',      vertical: 'airline',    plan: 'Starter',    seatsUsed: 3,  status: 'suspended', mrr: 0,    created: 'Feb 2024', owner: 'Henrik Olsen',  region: 'EU' },
      { id: 't_vertice',   name: 'Vértice Pharma',    vertical: 'medical',    plan: 'Growth',     seatsUsed: 17, status: 'active',    mrr: 149,  created: 'Dec 2023', owner: 'Sofia Marqués', region: 'ES' }
    ];
  }

  // Default per-level quota for a vertical's categories: { self, cap } in %.
  // self = a seller applies up to this freely; between self and cap needs
  // approval; above cap is not allowed.
  function seedQuota(verticalId) {
    var cats = VERTICALS[verticalId].categories;
    var byLevel = { Junior: [4, 8], Senior: [8, 15], Lead: [12, 22] };
    var q = {};
    LEVELS.forEach(function (lv, li) {
      q[lv] = {};
      cats.forEach(function (c, ci) {
        // taper later categories slightly (often lower-margin)
        var taper = ci; // 0..3
        var self = Math.max(2, byLevel[lv][0] - taper);
        var cap = Math.max(self + 3, byLevel[lv][1] - taper);
        q[lv][c] = { self: self, cap: cap };
      });
    });
    return q;
  }

  /* ───────────────── the active demo tenant for Agency + Sales ───────────────── */
  // Northwind Supply (Product & Wholesale) — proves the platform off the airline
  // vertical and connects the sales→approval flow to the agency inbox.
  var ACTIVE_TENANT = 't_northwind';

  var SELLERS = [
    { id: 's_marcus', name: 'Marcus Webb',     level: 'Senior', email: 'marcus@northwind.co',  hue: 230, you: true },
    { id: 's_priya',  name: 'Priya Nair',      level: 'Junior', email: 'priya@northwind.co',   hue: 290 },
    { id: 's_tom',    name: 'Tom Castellano',  level: 'Senior', email: 'tom@northwind.co',     hue: 150 },
    { id: 's_amara',  name: 'Amara Diallo',    level: 'Lead',   email: 'amara@northwind.co',   hue: 30  },
    { id: 's_jonas',  name: 'Jonas Lindqvist', level: 'Junior', email: 'jonas@northwind.co',   hue: 200 }
  ];
  // The signed-in salesperson for the Sales persona.
  var ME = 's_marcus';

  /* ───────────────── seed: deals (for the active tenant) ───────────────── */
  function seedDeals() {
    return [
      { ref: 'NW-3071', customer: 'Halverson Retail',    category: 'Electronics',   value: 42000, seller: 's_marcus', baseDiscount: 0,  status: 'Draft' },
      { ref: 'NW-3068', customer: 'Brightway Stores',     category: 'Apparel',       value: 8500,  seller: 's_priya',  baseDiscount: 5,  status: 'Sent' },
      { ref: 'NW-3065', customer: 'Kowalski Industries',  category: 'Industrial',    value: 120000,seller: 's_tom',    baseDiscount: 8,  status: 'Draft' },
      { ref: 'NW-3061', customer: 'Maison & Co.',         category: 'Home & Living', value: 16400, seller: 's_marcus', baseDiscount: 10, status: 'Accepted' },
      { ref: 'NW-3058', customer: 'Pacific Electronics',  category: 'Electronics',   value: 67800, seller: 's_amara',  baseDiscount: 14, status: 'Sent' },
      { ref: 'NW-3054', customer: 'Greenfield Schools',   category: 'Apparel',       value: 23900, seller: 's_jonas',  baseDiscount: 0,  status: 'Draft' }
    ];
  }

  /* ───────────────── seed: approval requests ───────────────── */
  function seedRequests() {
    var now = Date.now();
    var H = 3600e3;
    return [
      { id: 'rq_1', tenant: ACTIVE_TENANT, deal: 'NW-3071', customer: 'Halverson Retail',   category: 'Electronics', value: 42000,  seller: 's_marcus', level: 'Senior', current: 0,  requested: 11, routedTo: 'Team Lead',   reason: 'Repeat customer matching a competitor quote; volume commitment for Q3.', status: 'pending', ts: now - 2 * H },
      { id: 'rq_2', tenant: ACTIVE_TENANT, deal: 'NW-3054', customer: 'Greenfield Schools',  category: 'Apparel',     value: 23900,  seller: 's_jonas',  level: 'Junior', current: 0,  requested: 5,  routedTo: 'Team Lead',   reason: 'Education-sector framework deal, expecting reorders each term.', status: 'pending', ts: now - 5 * H },
      { id: 'rq_3', tenant: ACTIVE_TENANT, deal: 'NW-3065', customer: 'Kowalski Industries', category: 'Industrial',  value: 120000, seller: 's_tom',    level: 'Senior', current: 5,  requested: 11, routedTo: 'Agency Admin', reason: 'Strategic logo, six-figure first order, board-level sponsor.', status: 'pending', ts: now - 26 * H },
      { id: 'rq_4', tenant: ACTIVE_TENANT, deal: 'NW-3058', customer: 'Pacific Electronics', category: 'Electronics', value: 67800,  seller: 's_amara',  level: 'Lead',   current: 10, requested: 15, routedTo: 'Agency Admin', reason: 'Annual renewal uplift; retention priority.', status: 'approved', decidedBy: 'Daniel Reyes', note: 'Approved — strong retention case.', ts: now - 50 * H, decidedTs: now - 48 * H },
      { id: 'rq_5', tenant: ACTIVE_TENANT, deal: 'NW-3061', customer: 'Maison & Co.',        category: 'Home & Living', value: 16400, seller: 's_marcus', level: 'Senior', current: 6,  requested: 13, routedTo: 'Agency Admin', reason: 'Customer pushing hard on price.', status: 'rejected', decidedBy: 'Daniel Reyes', note: 'Margin too thin at this value — capped at 10%.', ts: now - 76 * H, decidedTs: now - 72 * H }
    ];
  }

  /* ───────────────── persistence ───────────────── */
  function read(k, d) { try { var v = JSON.parse(localStorage.getItem('qa2-' + k)); return v == null ? d : v; } catch (e) { return d; } }
  function write(k, v) { try { localStorage.setItem('qa2-' + k, JSON.stringify(v)); } catch (e) {} }

  var store = {
    tenants:    read('tenants', null) || seedTenants(),
    quotas:     read('quotas', null) || {},
    guardrails: read('guardrails', null) || Object.assign({}, DEFAULT_GUARDRAILS),
    deals:      read('deals', null) || seedDeals(),
    requests:   read('requests', null) || seedRequests(),
    activity:   read('activity', null) || []
  };
  // ensure every tenant has a quota matrix
  store.tenants.forEach(function (t) { if (!store.quotas[t.id]) store.quotas[t.id] = seedQuota(t.vertical); });
  if (!store.activity.length) {
    store.activity = store.requests.slice().sort(function (a, b) { return a.ts - b.ts; }).map(function (r) {
      return { id: 'ac_' + r.id, type: r.status === 'pending' ? 'requested' : r.status, seller: r.seller, deal: r.deal, requested: r.requested, by: r.decidedBy, ts: r.decidedTs || r.ts };
    });
  }
  function persist() { ['tenants', 'quotas', 'guardrails', 'deals', 'requests', 'activity'].forEach(function (k) { write(k, store[k]); }); }
  persist();

  /* ───────────────── helpers ───────────────── */
  function vertical(id) { return VERTICALS[id]; }
  function tenant(id) { return store.tenants.filter(function (t) { return t.id === id; })[0]; }
  function activeTenant() { return tenant(ACTIVE_TENANT); }
  function seller(id) { return SELLERS.filter(function (s) { return s.id === id; })[0]; }
  function me() { return seller(ME); }
  function quotaMatrix(tenantId) { return store.quotas[tenantId]; }
  function quotaFor(tenantId, level, category) { var m = store.quotas[tenantId]; return (m && m[level] && m[level][category]) || { self: 0, cap: 0 }; }
  function setQuota(tenantId, level, category, field, val) {
    var m = store.quotas[tenantId]; if (!m[level]) m[level] = {}; if (!m[level][category]) m[level][category] = { self: 0, cap: 0 };
    m[level][category][field] = val;
    if (field === 'self' && m[level][category].cap < val) m[level][category].cap = val;
    if (field === 'cap' && m[level][category].self > val) m[level][category].self = val;
    persist();
  }

  function fmtMoney(v, unit) {
    unit = unit || '£';
    var n = Math.round(v);
    var s = n >= 1000 ? n.toLocaleString('en-GB') : String(n);
    return unit + s;
  }
  function fmtAgo(ts) {
    var d = Date.now() - ts, h = Math.round(d / 3600e3);
    if (h < 1) return 'just now';
    if (h < 24) return h + ' h ago';
    var days = Math.round(h / 24);
    return days + (days === 1 ? ' day ago' : ' days ago');
  }

  // Decide what happens when `requested`% is asked for at `level` in `category`.
  // Returns { decision:'auto'|'pending'|'blocked', approver, self, cap }.
  function route(tenantId, level, category, requested) {
    var q = quotaFor(tenantId, level, category);
    if (requested <= q.self) return { decision: 'auto', self: q.self, cap: q.cap };
    if (requested > q.cap) return { decision: 'blocked', self: q.self, cap: q.cap };
    var over = requested - q.self, span = Math.max(0.0001, q.cap - q.self);
    var approver;
    if (level === 'Lead') approver = 'Agency Admin';
    else approver = (over <= span / 2) ? 'Team Lead' : 'Agency Admin';
    return { decision: 'pending', approver: approver, self: q.self, cap: q.cap, over: over };
  }

  function requestsFor(tenantId, status) {
    return store.requests.filter(function (r) { return r.tenant === tenantId && (!status || r.status === status); })
      .sort(function (a, b) { return b.ts - a.ts; });
  }
  function pendingCount(tenantId) { return requestsFor(tenantId, 'pending').length; }
  function myRequests(sellerId) { return store.requests.filter(function (r) { return r.seller === sellerId; }).sort(function (a, b) { return b.ts - a.ts; }); }

  function addRequest(req) {
    req.id = 'rq_' + Math.random().toString(36).slice(2, 8);
    req.status = 'pending'; req.ts = Date.now();
    store.requests.unshift(req);
    store.activity.unshift({ id: 'ac_' + req.id, type: 'requested', seller: req.seller, deal: req.deal, requested: req.requested, ts: req.ts });
    persist();
    return req;
  }
  function decideRequest(id, decision, note, by) {
    var r = store.requests.filter(function (x) { return x.id === id; })[0]; if (!r) return;
    r.status = decision; r.note = note || ''; r.decidedBy = by || 'Daniel Reyes'; r.decidedTs = Date.now();
    store.activity.unshift({ id: 'ac_' + id + '_' + decision, type: decision, seller: r.seller, deal: r.deal, requested: r.requested, by: r.decidedBy, ts: r.decidedTs });
    persist();
    return r;
  }

  /* ───────────────── platform analytics (derived) ───────────────── */
  function platformStats() {
    var ts = store.tenants;
    return {
      tenants: ts.length,
      active: ts.filter(function (t) { return t.status === 'active'; }).length,
      seats: ts.reduce(function (a, t) { return a + t.seatsUsed; }, 0),
      mrr: ts.reduce(function (a, t) { return a + t.mrr; }, 0),
      verticals: VERTICAL_ORDER.filter(function (v) { return ts.some(function (t) { return t.vertical === v; }); }).length
    };
  }

  /* ───────────────── shared toast ───────────────── */
  function toast(msg, kind) {
    var el = document.getElementById('qa-toast');
    if (!el) {
      el = document.createElement('div'); el.id = 'qa-toast'; el.className = 'mc-card';
      el.style.cssText = 'display:none;position:fixed;bottom:24px;left:50%;transform:translateX(-50%);z-index:160;padding:12px 18px;box-shadow:0 24px 60px -12px rgb(0 0 0/.25);align-items:center;gap:10px;';
      document.body.appendChild(el);
    }
    var color = kind === 'error' ? 'var(--mc-error)' : kind === 'warn' ? 'var(--mc-warning)' : 'var(--mc-success)';
    var glyph = kind === 'error' ? '✕' : kind === 'warn' ? '!' : '✓';
    el.style.display = 'flex';
    el.innerHTML = '<span style="color:' + color + ';font-weight:700;">' + glyph + '</span><span class="text-sm font-medium">' + msg + '</span>';
    clearTimeout(el._t); el._t = setTimeout(function () { el.style.display = 'none'; }, 2400);
  }

  function svgIcon(path, size) { size = size || 18; return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' + path + '</svg>'; }
  function resetAll() { ['tenants', 'quotas', 'guardrails', 'deals', 'requests', 'activity'].forEach(function (k) { try { localStorage.removeItem('qa2-' + k); } catch (e) {} }); }

  window.QAData = {
    VERTICALS: VERTICALS, VERTICAL_ORDER: VERTICAL_ORDER, PLANS: PLANS, LEVELS: LEVELS,
    SELLERS: SELLERS, ACTIVE_TENANT: ACTIVE_TENANT,
    get tenants() { return store.tenants; },
    get deals() { return store.deals; },
    get requests() { return store.requests; },
    get activity() { return store.activity; },
    get guardrails() { return store.guardrails; },
    vertical: vertical, tenant: tenant, activeTenant: activeTenant, seller: seller, me: me,
    quotaMatrix: quotaMatrix, quotaFor: quotaFor, setQuota: setQuota,
    route: route, requestsFor: requestsFor, pendingCount: pendingCount, myRequests: myRequests,
    addRequest: addRequest, decideRequest: decideRequest,
    addTenant: function (t) { t.id = 't_' + Math.random().toString(36).slice(2, 7); store.tenants.unshift(t); store.quotas[t.id] = seedQuota(t.vertical); persist(); return t; },
    updateTenant: function (id, patch) { var t = tenant(id); if (t) { Object.assign(t, patch); if (patch.vertical && !store.quotas[id]) store.quotas[id] = seedQuota(patch.vertical); persist(); } return t; },
    removeTenant: function (id) { store.tenants = store.tenants.filter(function (t) { return t.id !== id; }); persist(); },
    setGuardrail: function (v, val) { store.guardrails[v] = val; persist(); },
    platformStats: platformStats,
    fmtMoney: fmtMoney, fmtAgo: fmtAgo, toast: toast, svgIcon: svgIcon, resetAll: resetAll, persist: persist
  };
})();
