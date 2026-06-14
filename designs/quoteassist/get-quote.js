/* QuoteAssist — Get Quote interactive engine (vanilla JS).
   Parses a pasted enquiry email, runs a mock pricing pipeline, drafts a reply.
   All data is dummy/fixture — no network calls. */
(function () {
  'use strict';

  const $ = s => document.querySelector(s);

  /* ───────── reference data ───────── */
  const CITIES = {
    london: ['LHR', 'London'], paris: ['CDG', 'Paris'], rome: ['FCO', 'Rome'],
    tokyo: ['HND', 'Tokyo'], dubai: ['DXB', 'Dubai'], singapore: ['SIN', 'Singapore'],
    bangkok: ['BKK', 'Bangkok'], sydney: ['SYD', 'Sydney'], barcelona: ['BCN', 'Barcelona'],
    amsterdam: ['AMS', 'Amsterdam'], istanbul: ['IST', 'Istanbul'], 'hong kong': ['HKG', 'Hong Kong'],
    dublin: ['DUB', 'Dublin'], madrid: ['MAD', 'Madrid'], lisbon: ['LIS', 'Lisbon'],
    berlin: ['BER', 'Berlin'], 'new york': ['JFK', 'New York'], 'los angeles': ['LAX', 'Los Angeles'],
    miami: ['MIA', 'Miami'], cairo: ['CAI', 'Cairo'], delhi: ['DEL', 'Delhi'], mumbai: ['BOM', 'Mumbai'],
    athens: ['ATH', 'Athens'], venice: ['VCE', 'Venice'], geneva: ['GVA', 'Geneva'], doha: ['DOH', 'Doha'],
  };
  const REGION = {
    LHR: 'eu', CDG: 'eu', FCO: 'eu', BCN: 'eu', AMS: 'eu', DUB: 'eu', MAD: 'eu', LIS: 'eu', BER: 'eu', ATH: 'eu', VCE: 'eu', GVA: 'eu', IST: 'eu',
    HND: 'as', SIN: 'as', BKK: 'as', HKG: 'as', DEL: 'as', BOM: 'as',
    DXB: 'me', DOH: 'me', CAI: 'me',
    JFK: 'am', LAX: 'am', MIA: 'am',
    SYD: 'oc',
  };
  const FARE = { // per-adult economy base, by region pair
    'eu-eu': 180, 'eu-me': 340, 'eu-as': 720, 'eu-am': 640, 'eu-oc': 1180,
    'me-as': 420, 'me-am': 820, 'me-oc': 980, 'me-me': 220,
    'as-am': 980, 'as-oc': 740, 'as-as': 260,
    'am-am': 280, 'am-oc': 1240, 'oc-oc': 300,
  };
  const MONTHS = { jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5, jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11 };
  const MONNAME = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const CABIN_MULT = { Economy: 1, 'Premium economy': 1.75, Business: 3.2, First: 5 };
  const STAR_RATE = { 3: 95, 4: 155, 5: 290 };

  const SAMPLES = [
    { name: 'Family · London → Tokyo', text: "Hi there,\n\nWe're a family of 4 (2 adults, 2 kids aged 6 and 9) looking to fly London to Tokyo, departing 14 Aug and returning 28 Aug. We'd prefer non-stop in economy. We'll also need a hotel near Shinjuku, 2 rooms please.\n\nWhat can you put together for us?\n\nThanks,\nThe Bennetts" },
    { name: 'Couple · Paris → Rome', text: "Hello,\n\nMy partner and I (2 adults) want to go from Paris to Rome on 12 Sept, coming back 19 Sept. Economy is fine. A 4-star hotel near the centre would be lovely.\n\nKind regards,\nClaire" },
    { name: 'Business · London → New York', text: "Hi,\n\nI need a business class fare, London to New York, out 03 Oct back 07 Oct, just myself. Non-stop only. No hotel needed.\n\nBest,\nMarcus Webb" },
    { name: 'Vague enquiry · Dubai', text: "Hi, thinking about a trip to Dubai sometime soon for me and my wife. Maybe a nice hotel. Can you give me an idea of cost?\n\nThanks" },
  ];

  /* ───────── parser ───────── */
  function parseEmail(t) {
    const low = ' ' + t.toLowerCase().replace(/[\n\r]+/g, ' ') + ' ';
    const gaps = [];

    // route
    const names = Object.keys(CITIES);
    const found = [];
    names.forEach(n => { const i = low.indexOf(' ' + n); if (i >= 0) found.push([i, n]); });
    found.sort((a, b) => a[0] - b[0]);
    let origin = null, dest = null;
    if (found.length >= 2) { origin = CITIES[found[0][1]]; dest = CITIES[found[1][1]]; }
    else if (found.length === 1) { dest = CITIES[found[0][1]]; gaps.push('Only one city detected — origin assumed London (LHR).'); origin = ['LHR', 'London']; }
    else { gaps.push('No route detected — please confirm origin and destination.'); origin = ['LHR', 'London']; dest = ['CDG', 'Paris']; }

    // dates
    const dates = [];
    const reDM = /(\d{1,2})\s*(?:st|nd|rd|th)?\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/g;
    const reMD = /(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+(\d{1,2})/g;
    let m;
    while ((m = reDM.exec(low))) dates.push({ d: +m[1], mo: MONTHS[m[2]] });
    while ((m = reMD.exec(low))) dates.push({ d: +m[2], mo: MONTHS[m[1]] });
    // range like "14-28 aug" (single month)
    const reRange = /(\d{1,2})\s*[–\-]\s*(\d{1,2})\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)/g;
    while ((m = reRange.exec(low))) { dates.push({ d: +m[1], mo: MONTHS[m[3]] }, { d: +m[2], mo: MONTHS[m[3]] }); }
    // dedupe + sort
    const uniq = [];
    dates.forEach(x => { if (!uniq.some(u => u.d === x.d && u.mo === x.mo)) uniq.push(x); });
    uniq.sort((a, b) => a.mo - b.mo || a.d - b.d);
    let depart = uniq[0] || null, ret = uniq[1] || null;
    let nights = 5;
    if (depart && ret) nights = Math.max(1, (new Date(2026, ret.mo, ret.d) - new Date(2026, depart.mo, depart.d)) / 86400000);
    if (!depart) gaps.push('Travel dates not found — using a 5-night placeholder.');
    else if (!ret) gaps.push('Return date not specified — assumed a 5-night stay.');

    // pax
    let adults = 0, children = 0;
    let mm = low.match(/(\d+)\s*adults?/); if (mm) adults = +mm[1];
    mm = low.match(/(\d+)\s*(?:kids?|child(?:ren)?)/); if (mm) children = +mm[1];
    if (!adults) { mm = low.match(/family of\s*(\d+)/); if (mm) { const tot = +mm[1]; adults = children ? Math.max(1, tot - children) : 2; if (!children) children = Math.max(0, tot - adults); } }
    if (!adults) { mm = low.match(/(\d+)\s*(?:passengers?|people|pax|travell?ers?)/); if (mm) adults = +mm[1]; }
    if (!adults) { if (/\b(my (wife|husband|partner)|couple|two of us|both of us)\b/.test(low)) adults = 2; else if (/\b(myself|just me|solo|i need|i'?m)\b/.test(low)) adults = 1; }
    if (!adults) { adults = 2; gaps.push('Passenger count unclear — assumed 2 adults.'); }

    // cabin
    let cabin = 'Economy', cabinStated = false;
    if (/business/.test(low)) { cabin = 'Business'; cabinStated = true; }
    else if (/first class/.test(low)) { cabin = 'First'; cabinStated = true; }
    else if (/premium/.test(low)) { cabin = 'Premium economy'; cabinStated = true; }
    else if (/economy/.test(low)) { cabin = 'Economy'; cabinStated = true; }
    if (!cabinStated) gaps.push('Cabin class not stated — assumed Economy.');

    const nonstop = /(non-?stop|direct)/.test(low);

    // hotel
    const wantHotel = /(hotel|accommodation|room|stay|nights?)/.test(low) && !/no hotel/.test(low);
    let rooms = 1, star = 4, area = '', starStated = false, areaStated = false;
    if (wantHotel) {
      mm = low.match(/(\d+)\s*rooms?/); if (mm) rooms = +mm[1]; else rooms = Math.max(1, Math.ceil((adults + children) / 2));
      mm = low.match(/(\d)\s*[-\s]?star/) || low.match(/(\d)\s*\*/); if (mm) { star = +mm[1]; starStated = true; }
      else { const words = { three: 3, four: 4, five: 5 }; for (const w in words) if (low.includes(w + ' star') || low.includes(w + '-star')) { star = words[w]; starStated = true; } }
      mm = t.match(/near\s+([A-Za-z][A-Za-z\s]{1,24}?)(?:[,.;]|\bfor\b|\bwith\b|\bplease\b|$)/i) || t.match(/in\s+(?:the\s+)?([A-Za-z][A-Za-z\s]{1,18}?)(?:\s+(?:centre|center|area|district))/i);
      if (mm) { area = mm[1].trim().replace(/\s+/g, ' '); areaStated = true; }
      if (!areaStated) gaps.push('Hotel location not specified.');
      if (!starStated) gaps.push('Hotel tier not specified — assumed 4★.');
    }

    const conf = Math.max(58, 97 - gaps.length * 7);
    return { origin, dest, depart, ret, nights, adults, children, cabin, nonstop, wantHotel, rooms, star, area, gaps, conf };
  }

  function fmtDate(x) { return x ? x.d + ' ' + MONNAME[x.mo] : '—'; }

  /* ───────── pricing ───────── */
  function regionPair(a, b) { const r1 = REGION[a] || 'eu', r2 = REGION[b] || 'eu'; return FARE[r1 + '-' + r2] ?? FARE[r2 + '-' + r1] ?? 300; }
  function round5(n) { return Math.round(n / 5) * 5; }

  function price(req, markup) {
    const base = regionPair(req.origin[0], req.dest[0]);
    const cabinMult = CABIN_MULT[req.cabin] || 1;
    const ns = req.nonstop ? 1.12 : 1;
    const farePerAdult = base * cabinMult * ns * 2; // *2 = return
    const flights = round5((req.adults + req.children * 0.75) * farePerAdult);
    const rows = [{ label: `Return flights · ${req.origin[0]}–${req.dest[0]} ${req.nonstop ? 'non-stop' : ''} · ${req.cabin}`, amount: flights }];
    let hotel = 0;
    if (req.wantHotel) {
      hotel = round5(req.rooms * (STAR_RATE[req.star] || 155) * req.nights);
      rows.push({ label: `Hotel · ${req.area || 'destination'} ${req.star}★ · ${req.rooms} room${req.rooms > 1 ? 's' : ''} · ${req.nights} nt`, amount: hotel });
    }
    const subtotal = flights + hotel;
    const total = round5(subtotal * (1 + markup / 100));
    return { rows, total };
  }

  /* ───────── draft ───────── */
  function buildDraft(req, p, cur) {
    const pax = [];
    if (req.adults) pax.push(req.adults + ' adult' + (req.adults > 1 ? 's' : ''));
    if (req.children) pax.push(req.children + ' child' + (req.children > 1 ? 'ren' : ''));
    const lines = [];
    lines.push('Dear Guest,');
    lines.push('');
    lines.push(`Thank you for your enquiry. Please find below a quotation for your ${req.origin[1]}–${req.dest[1]} trip (${pax.join(', ')}), travelling ${fmtDate(req.depart)} to ${fmtDate(req.ret)}:`);
    lines.push('');
    p.rows.forEach(r => lines.push(`  • ${r.label}: ${cur}${r.amount.toLocaleString()}`));
    lines.push(`  • Total incl. taxes & fees: ${cur}${p.total.toLocaleString()}`);
    lines.push('');
    lines.push('These fares are held for 48 hours under our standard booking policy. We are happy to adjust the cabin, hotel tier, or add airport transfers and travel insurance on request.');
    lines.push('');
    lines.push('Kind regards,');
    lines.push('Rana Aziz');
    lines.push('Skyline Travel · QuoteAssist');
    return lines.join('\n');
  }

  /* ───────── render ───────── */
  let current = null;

  function renderResults(req) {
    const cur = $('#currencySel').value;
    const markup = +$('#policySel').value;
    const p = price(req, markup);
    current = { req, p, cur, markup };

    // fields
    const f = $('#reqFields');
    f.innerHTML = [
      ['Route', `${req.origin[1]} (${req.origin[0]}) → ${req.dest[1]} (${req.dest[0]})`],
      ['Dates', `${fmtDate(req.depart)} – ${fmtDate(req.ret)} · ${req.nights} nights`],
      ['Passengers', `${req.adults} adult${req.adults > 1 ? 's' : ''}${req.children ? ' · ' + req.children + ' child' + (req.children > 1 ? 'ren' : '') : ''}`],
      ['Cabin', req.cabin + (req.nonstop ? ' · non-stop' : '')],
      ['Hotel', req.wantHotel ? `${req.area || 'Destination'} · ${req.star}★ · ${req.rooms} room${req.rooms > 1 ? 's' : ''}` : 'Not requested'],
    ].map(([k, v]) => `<div class="req-field"><label>${k}</label><input class="mc-input" value="${v.replace(/"/g, '&quot;')}" readonly style="height:34px;font-size:13px;"/></div>`).join('');

    // confidence
    $('#confBadge').textContent = req.conf + '% conf.';
    const cb = $('#confBadge');
    cb.className = 'mc-badge font-mono ' + (req.conf >= 85 ? 'mc-badge-success' : req.conf >= 70 ? 'mc-badge-warning' : 'mc-badge-error');

    // gaps
    const gl = $('#gapsList'), gc = $('#gapsCard');
    if (req.gaps.length) {
      gc.style.display = '';
      gl.innerHTML = req.gaps.map(g => `<div class="flex items-start gap-2.5 text-sm" style="color:var(--mc-text-2);"><span style="color:var(--mc-warning);margin-top:1px;">▲</span><span>${g}</span></div>`).join('');
    } else {
      gc.style.display = '';
      gl.innerHTML = `<div class="flex items-center gap-2.5 text-sm" style="color:var(--mc-text-2);"><span style="color:var(--mc-success);">✓</span><span>All required details present — nothing to confirm.</span></div>`;
    }

    // price rows
    $('#priceRows').innerHTML = p.rows.map((r, i) =>
      `<div class="flex items-center justify-between px-4 py-2.5 text-sm" style="${i ? 'border-top:1px solid var(--mc-border);' : ''}"><span style="color:var(--mc-text-2);">${r.label}</span><span class="font-mono">${cur}${r.amount.toLocaleString()}</span></div>`).join('');
    $('#totalPrice').textContent = cur + p.total.toLocaleString();

    // draft
    $('#draftBody').value = buildDraft(req, p, cur);
  }

  /* ───────── pipeline animation ───────── */
  const STEPS = [
    ['Reading the email', 'M4 4h16v12H4z'],
    ['Extracting requirements', 'M9 13h6M9 17h4'],
    ['Detecting missing info', 'M12 8v4M12 16h.01'],
    ['Fetching pricing (mock adapter)', 'M7 14l4-4 4 4 5-5'],
    ['Applying fare policy', 'm9 12 2 2 4-4'],
    ['Drafting reply', 'M12 19l7-7'],
  ];

  function runPipeline(req) {
    const card = $('#processCard'), box = $('#procSteps'), timer = $('#procTimer');
    $('#results').style.display = 'none';
    card.style.display = '';
    box.innerHTML = STEPS.map((s, i) => `<div class="proc-step" data-i="${i}">
      <span class="proc-ic"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg></span>
      <span class="text-sm font-medium">${s[0]}</span>
      <span class="ml-auto proc-spin" style="display:none;"><svg class="spin" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="var(--mc-brand)" stroke-width="2.4" stroke-linecap="round"><path d="M21 12a9 9 0 1 1-6.2-8.5"/></svg></span>
    </div>`).join('');
    const t0 = performance.now();
    const tick = setInterval(() => { timer.textContent = ((performance.now() - t0) / 1000).toFixed(1) + 's'; }, 80);

    const els = [...box.querySelectorAll('.proc-step')];
    let i = 0;
    function next() {
      if (i > 0) { els[i - 1].classList.remove('on'); els[i - 1].classList.add('done'); els[i - 1].querySelector('.proc-spin').style.display = 'none'; }
      if (i >= els.length) {
        clearInterval(tick);
        setTimeout(() => {
          card.style.display = 'none';
          $('#results').style.display = '';
          renderResults(req);
          $('#results').scrollIntoView ? null : null;
        }, 250);
        return;
      }
      els[i].classList.add('on');
      els[i].querySelector('.proc-spin').style.display = '';
      i++;
      setTimeout(next, 360 + Math.random() * 320);
    }
    next();
  }

  /* ───────── toast ───────── */
  function toast(msg, ok) {
    const el = $('#toast');
    el.style.display = 'flex';
    el.innerHTML = `<span style="color:${ok ? 'var(--mc-success)' : 'var(--mc-brand)'};">${ok ? '✓' : 'ℹ'}</span><span class="text-sm font-medium">${msg}</span>`;
    clearTimeout(el._t); el._t = setTimeout(() => { el.style.display = 'none'; }, 2400);
  }

  /* ───────── events ───────── */
  function init() {
    // sample menu
    const menu = $('#sampleMenu');
    menu.innerHTML = SAMPLES.map((s, i) => `<button class="mc-side-item" data-s="${i}" style="display:flex;flex-direction:column;align-items:flex-start;gap:2px;padding:10px 14px;border-bottom:1px solid var(--mc-border);">
      <span class="text-sm font-semibold" style="color:var(--mc-text);">${s.name}</span>
      <span class="text-[11px]" style="color:var(--mc-text-3);">${s.text.replace(/\n/g, ' ').slice(0, 52)}…</span></button>`).join('');
    $('#sampleBtn').addEventListener('click', e => { e.stopPropagation(); menu.style.display = menu.style.display === 'none' ? 'block' : 'none'; });
    document.addEventListener('click', () => { menu.style.display = 'none'; });
    menu.addEventListener('click', e => { const b = e.target.closest('[data-s]'); if (b) { $('#emailInput').value = SAMPLES[+b.dataset.s].text; menu.style.display = 'none'; } });

    $('#clearBtn').addEventListener('click', () => { $('#emailInput').value = ''; $('#results').style.display = 'none'; $('#processCard').style.display = 'none'; });

    $('#generateBtn').addEventListener('click', () => {
      const txt = $('#emailInput').value.trim();
      if (!txt) { toast('Paste a customer email first, or load a sample.'); return; }
      runPipeline(parseEmail(txt));
    });

    $('#regenBtn').addEventListener('click', () => { if (current) renderResults(current.req); toast('Quote regenerated with current settings.'); });
    [$('#currencySel'), $('#policySel')].forEach(s => s.addEventListener('change', () => { if (current && $('#results').style.display !== 'none') renderResults(current.req); }));

    $('#copyBtn').addEventListener('click', () => {
      const v = $('#draftBody').value;
      navigator.clipboard?.writeText(v).catch(() => {});
      $('#copyLabel').textContent = 'Approved & copied';
      toast('Draft approved and copied to clipboard.', true);
      setTimeout(() => { $('#copyLabel').textContent = 'Approve & copy'; }, 1800);
    });

    $('#saveBtn').addEventListener('click', () => {
      if (!current) return;
      const { req, p, cur } = current;
      let list = [];
      try { list = JSON.parse(localStorage.getItem('qa-quotes') || '[]'); } catch (e) {}
      const ref = 'QA-' + (1480 + list.length).toString();
      list.unshift({
        ref, route: `${req.origin[0]}–${req.dest[0]}`,
        dest: req.dest[1], dates: `${fmtDate(req.depart)} – ${fmtDate(req.ret)}`,
        pax: `${req.adults}A${req.children ? '·' + req.children + 'C' : ''}`,
        total: cur + p.total.toLocaleString(), status: 'Draft', created: 'just now',
      });
      try { localStorage.setItem('qa-quotes', JSON.stringify(list)); } catch (e) {}
      toast('Saved as ' + ref + ' — opening Quotes…', true);
      setTimeout(() => { window.location.href = 'quotes.html'; }, 1100);
    });
  }

  function maybeDemo() {
    if (/[?&]demo/.test(location.search)) {
      const req = parseEmail(SAMPLES[0].text);
      document.querySelector('#emailInput').value = SAMPLES[0].text;
      document.querySelector('#results').style.display = '';
      renderResults(req);
    }
  }

  function boot() { init(); maybeDemo(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
