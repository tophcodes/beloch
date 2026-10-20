// A figure's drawing, opened large. A click on a view of a `.figure` puts a
// copy of its SVG over the page, fitted to the window; the wheel and the
// keys + and - zoom about the pointer or the middle, a drag pans, 0 fits it
// again, and Escape, a click on the backdrop or the close button put it
// away. The copy is the drawing itself, so every label and color stays
// crisp at any size. Returns the script text for Starlight's `head` config.
export function figureLightboxScript(): string {
  return `
(() => {
  const VIEW = '.figure-view';
  const MIN = 0.25, MAX = 16;
  let box = null, stage = null, scale = 1, tx = 0, ty = 0;
  let dragging = false, lastX = 0, lastY = 0, moved = false;
  function ensureBox() {
    if (box) return box;
    box = document.createElement('div');
    box.className = 'figure-lightbox';
    box.setAttribute('role', 'dialog');
    box.setAttribute('aria-modal', 'true');
    box.setAttribute('aria-label', 'Figure, enlarged');
    box.hidden = true;
    box.innerHTML = '<div class="figure-lightbox-stage"></div>'
      + '<div class="figure-lightbox-bar">'
      + '<button type="button" data-act="out" aria-label="Zoom out">\\u2212</button>'
      + '<button type="button" data-act="fit" aria-label="Fit to window">0</button>'
      + '<button type="button" data-act="in" aria-label="Zoom in">+</button>'
      + '<button type="button" data-act="close" aria-label="Close">\\u00d7</button>'
      + '</div>';
    document.body.appendChild(box);
    stage = box.querySelector('.figure-lightbox-stage');
    box.addEventListener('click', (e) => {
      const act = e.target.closest('[data-act]');
      if (act) {
        const a = act.getAttribute('data-act');
        if (a === 'in') zoomBy(1.25);
        else if (a === 'out') zoomBy(0.8);
        else if (a === 'fit') fit();
        else close();
        return;
      }
      if (!moved && !stage.contains(e.target)) close();
    });
    box.addEventListener('wheel', (e) => {
      e.preventDefault();
      zoomAbout(e.clientX, e.clientY, scale * Math.exp(-e.deltaY * 0.0015));
    }, { passive: false });
    box.addEventListener('pointerdown', (e) => {
      if (e.button !== 0 || e.target.closest('[data-act]')) return;
      dragging = true; moved = false; lastX = e.clientX; lastY = e.clientY;
      box.setPointerCapture(e.pointerId);
    });
    box.addEventListener('pointermove', (e) => {
      if (!dragging) return;
      const dx = e.clientX - lastX, dy = e.clientY - lastY;
      if (Math.abs(dx) + Math.abs(dy) > 2) moved = true;
      tx += dx; ty += dy; lastX = e.clientX; lastY = e.clientY;
      apply();
    });
    box.addEventListener('pointerup', () => { dragging = false; });
    box.addEventListener('pointercancel', () => { dragging = false; });
    return box;
  }
  function apply() {
    stage.style.transform = 'translate(' + tx + 'px, ' + ty + 'px) scale(' + scale + ')';
  }
  function zoomAbout(cx, cy, next) {
    const clamped = Math.min(MAX, Math.max(MIN, next));
    if (clamped === scale) return;
    const r = stage.getBoundingClientRect();
    const ratio = clamped / scale;
    tx += (cx - r.left) * (1 - ratio);
    ty += (cy - r.top) * (1 - ratio);
    scale = clamped;
    apply();
  }
  function zoomBy(f) { zoomAbout(window.innerWidth / 2, window.innerHeight / 2, scale * f); }
  // The drawing at the largest size that fits the window with a margin,
  // centered; the stage's own size is the SVG's natural size.
  function fit() {
    const svg = stage.firstElementChild;
    if (!svg) return;
    stage.style.transform = '';
    const r = stage.getBoundingClientRect();
    const w = parseFloat(svg.getAttribute('width')) || r.width || 1;
    const h = parseFloat(svg.getAttribute('height')) || r.height || 1;
    scale = Math.max(MIN, Math.min((window.innerWidth - 48) / w, (window.innerHeight - 96) / h, MAX));
    tx = (window.innerWidth - w * scale) / 2 - r.left;
    ty = (window.innerHeight - 96 - h * scale) / 2 + 24 - r.top;
    apply();
  }
  let opener = null;
  function open(view) {
    const svg = view.querySelector('svg');
    if (!svg) return;
    const b = ensureBox();
    const copy = svg.cloneNode(true);
    // the copy keeps the drawing's own pixel size; the stage scales it
    const w = svg.viewBox && svg.viewBox.baseVal && svg.viewBox.baseVal.width || svg.clientWidth;
    const h = svg.viewBox && svg.viewBox.baseVal && svg.viewBox.baseVal.height || svg.clientHeight;
    copy.setAttribute('width', String(w));
    copy.setAttribute('height', String(h));
    copy.style.width = w + 'px';
    copy.style.height = h + 'px';
    stage.replaceChildren(copy);
    opener = view;
    b.hidden = false;
    document.body.classList.add('figure-lightbox-open');
    fit();
    b.querySelector('[data-act="close"]').focus();
  }
  function close() {
    if (!box || box.hidden) return;
    box.hidden = true;
    document.body.classList.remove('figure-lightbox-open');
    if (opener) opener.focus();
  }
  document.addEventListener('click', (e) => {
    const view = e.target.closest(VIEW);
    if (!view || (box && box.contains(e.target))) return;
    open(view);
  });
  document.addEventListener('keydown', (e) => {
    const view = e.target.closest && e.target.closest(VIEW);
    if (view && (e.key === 'Enter' || e.key === ' ') && (!box || box.hidden)) {
      e.preventDefault(); open(view); return;
    }
    if (!box || box.hidden) return;
    if (e.key === 'Escape') close();
    else if (e.key === '+' || e.key === '=') zoomBy(1.25);
    else if (e.key === '-') zoomBy(0.8);
    else if (e.key === '0') fit();
  });
  // every view is a button for the keyboard too
  const arm = () => document.querySelectorAll(VIEW).forEach((v) => {
    if (v.hasAttribute('tabindex')) return;
    v.setAttribute('tabindex', '0');
    v.setAttribute('role', 'button');
    v.setAttribute('aria-label', 'Enlarge the drawing');
  });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', arm); else arm();
})();
`;
}
