// Hover popups for footnote markers, the way Wikipedia previews a reference.
// The Notes list at the end of a page stays the source; this only shows a
// note's content next to its marker while the pointer rests on it, so the
// reader need not jump down to see whether a number is a citation or a
// remark. Returns the script text for Starlight's `head` config.
export function notePopupScript(): string {
  return `
(() => {
  const SEL = 'a[data-footnote-ref]';
  let box = null;
  function ensureBox() {
    if (box) return box;
    box = document.createElement('div');
    box.className = 'note-popup';
    box.setAttribute('role', 'tooltip');
    box.hidden = true;
    document.body.appendChild(box);
    return box;
  }
  function contentOf(marker) {
    const id = marker.getAttribute('href').slice(1);
    const li = document.getElementById(id);
    if (!li) return null;
    const copy = li.cloneNode(true);
    copy.querySelectorAll('a[data-footnote-backref], .cite-backlinks').forEach((n) => n.remove());
    return copy.innerHTML;
  }
  function show(marker) {
    const html = contentOf(marker);
    if (html === null) return;
    const b = ensureBox();
    b.innerHTML = html;
    b.hidden = false;
    const r = marker.getBoundingClientRect();
    const width = Math.min(420, window.innerWidth - 16);
    b.style.width = width + 'px';
    let left = r.left + window.scrollX - width / 2 + r.width / 2;
    left = Math.max(8, Math.min(left, window.scrollX + window.innerWidth - width - 8));
    b.style.left = left + 'px';
    b.style.top = (r.bottom + window.scrollY + 6) + 'px';
  }
  function hide() { if (box) box.hidden = true; }
  document.addEventListener('mouseover', (e) => {
    const marker = e.target.closest && e.target.closest(SEL);
    if (marker) show(marker);
  });
  document.addEventListener('mouseout', (e) => {
    const marker = e.target.closest && e.target.closest(SEL);
    if (marker && !(e.relatedTarget && box && box.contains(e.relatedTarget))) hide();
  });
  document.addEventListener('focusin', (e) => {
    const marker = e.target.closest && e.target.closest(SEL);
    if (marker) show(marker);
  });
  document.addEventListener('focusout', hide);
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') hide(); });
})();
`;
}
