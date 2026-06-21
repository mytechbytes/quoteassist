// QuoteAssist — vanilla Tweaks panel. No React; pure DOM + the host edit-mode
// protocol. Drives window.QA (defined in qa-shell.js) for live accent / corner
// / theme changes and persists them via localStorage + __edit_mode_set_keys.

(function () {
  'use strict';

  const ACCENT_SWATCH = {
    teal:   'linear-gradient(135deg, oklch(72% 0.13 188), oklch(50% 0.105 192))',
    ocean:  'linear-gradient(135deg, oklch(70% 0.15 245), oklch(50% 0.15 255))',
    violet: 'linear-gradient(135deg, oklch(70% 0.16 295), oklch(50% 0.17 288))',
    mango:  'linear-gradient(135deg, oklch(74% 0.16 60), oklch(58% 0.17 50))',
  };

  let panel = null;

  function post(edits) {
    try { window.parent.postMessage({ type: '__edit_mode_set_keys', edits }, '*'); } catch (e) {}
  }

  function seg(name, value, options) {
    return `<div class="qa-tw-seg" data-seg="${name}">` + options.map(o =>
      `<button type="button" data-val="${o.v}" class="${o.v === value ? 'on' : ''}">${o.l}</button>`).join('') + `</div>`;
  }

  function build() {
    const st = window.QA.getState();
    panel = document.createElement('div');
    panel.id = 'qa-tweaks';
    panel.style.display = 'none';
    panel.innerHTML = `
      <div class="qa-tw-head">
        <span class="qa-tw-dot"></span>
        <span class="qa-tw-title">Tweaks</span>
        <button type="button" class="qa-tw-x" aria-label="Close">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
        </button>
      </div>
      <div class="qa-tw-body">
        <div class="qa-tw-field">
          <label>Accent</label>
          <div class="qa-tw-swatches">
            ${Object.keys(ACCENT_SWATCH).map(k =>
              `<button type="button" class="qa-tw-sw ${k === st.accent ? 'on' : ''}" data-accent="${k}" title="${k}" style="background:${ACCENT_SWATCH[k]}"></button>`).join('')}
          </div>
        </div>
        <div class="qa-tw-field">
          <label>Corners</label>
          ${seg('radius', st.radius, [{ v: 'sharp', l: 'Sharp' }, { v: 'rounded', l: 'Rounded' }, { v: 'soft', l: 'Soft' }])}
        </div>
        <div class="qa-tw-field">
          <label>Theme</label>
          ${seg('theme', st.theme, [{ v: 'light', l: 'Light' }, { v: 'dark', l: 'Dark' }])}
        </div>
      </div>`;
    document.body.appendChild(panel);

    panel.querySelector('.qa-tw-x').addEventListener('click', () => {
      hide();
      try { window.parent.postMessage({ type: '__edit_mode_dismissed' }, '*'); } catch (e) {}
    });

    // accent swatches
    panel.querySelectorAll('.qa-tw-sw').forEach(b => b.addEventListener('click', () => {
      const v = b.dataset.accent;
      window.QA.setAccent(v);
      panel.querySelectorAll('.qa-tw-sw').forEach(x => x.classList.toggle('on', x === b));
      post({ accent: v });
    }));

    // segmented controls
    panel.querySelectorAll('.qa-tw-seg').forEach(segEl => {
      const name = segEl.dataset.seg;
      segEl.querySelectorAll('button').forEach(b => b.addEventListener('click', () => {
        const v = b.dataset.val;
        segEl.querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
        if (name === 'radius') { window.QA.setRadius(v); post({ radius: v }); }
        if (name === 'theme') { window.QA.applyTheme(v); post({ theme: v }); }
      }));
    });
  }

  function show() { if (!panel) build(); panel.style.display = 'block'; }
  function hide() { if (panel) panel.style.display = 'none'; }

  // protocol: register listener BEFORE announcing availability
  window.addEventListener('message', e => {
    const t = e.data && e.data.type;
    if (t === '__activate_edit_mode') show();
    else if (t === '__deactivate_edit_mode') hide();
  });

  function announce() { try { window.parent.postMessage({ type: '__edit_mode_available' }, '*'); } catch (e) {} }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', announce);
  else announce();
})();
