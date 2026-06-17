// MangoCMS — shared shell behaviors.
// Auto-applies on DOMContentLoaded; no per-page wiring needed.

(function(){
  // ── Theme restore (light/dark) ──
  function applyTheme(t){
    document.documentElement.classList.toggle('dark', t === 'dark');
    try { localStorage.setItem('mc-theme', t); } catch(e){}
    document.querySelectorAll('[data-theme-toggle]').forEach(b => {
      b.dataset.themeState = t;
    });
  }
  function getTheme(){
    try { return localStorage.getItem('mc-theme') || 'light'; } catch(e){ return 'light'; }
  }
  // restore ASAP before paint
  document.documentElement.classList.toggle('dark', getTheme() === 'dark');

  // ── Sidebar collapse ──
  function applyCollapse(c){
    document.querySelectorAll('.mc-shell').forEach(s => s.classList.toggle('collapsed', c));
    try { localStorage.setItem('mc-sb-collapsed', c ? '1' : '0'); } catch(e){}
  }
  function getCollapsed(){
    try { return localStorage.getItem('mc-sb-collapsed') === '1'; } catch(e){ return false; }
  }

  document.addEventListener('DOMContentLoaded', () => {
    applyCollapse(getCollapsed());

    // Theme toggle buttons
    document.querySelectorAll('[data-theme-toggle]').forEach(b => {
      b.dataset.themeState = getTheme();
      b.addEventListener('click', () => {
        const next = getTheme() === 'dark' ? 'light' : 'dark';
        applyTheme(next);
      });
    });

    // Sidebar toggles
    document.querySelectorAll('[data-sidebar-toggle]').forEach(b => {
      b.addEventListener('click', () => {
        const shell = document.querySelector('.mc-shell');
        if (!shell) return;
        applyCollapse(!shell.classList.contains('collapsed'));
      });
    });

    // Modal open/close hooks
    document.querySelectorAll('[data-modal-open]').forEach(b => {
      b.addEventListener('click', () => {
        const id = b.getAttribute('data-modal-open');
        const m = document.getElementById(id);
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
      bd.addEventListener('click', (e) => {
        if (e.target === bd) bd.style.display = 'none';
      });
    });
  });
})();
