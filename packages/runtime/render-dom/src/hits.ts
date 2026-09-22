// Hit areas for the thin marks the renderer draws. A crease `<line>` is one
// or two pixels wide and a point dot has r = 3, which is too fine a target to
// hover or click reliably. This inserts a transparent, fatter sibling right
// after each one, carrying the same identity attributes, so the host resolves
// a hit on the twin exactly as it resolves one on the visible mark while its
// own CSS gives the twin a forgiving `pointer-events` area.

export const HIT_CLASS = "bel-hit";
const SVG_NS = "http://www.w3.org/2000/svg";

// Every real crease segment the renderer drew. Mark overlay lines live in the
// same `data-layer="creases"` group and carry a crease id too, so a selector
// that keyed on the id alone would collect them; `data-kind` separates them.
export const CREASE_SELECTOR = '[data-layer="creases"] line[data-kind="crease"]';
// Lines that get a fat hit target: real creases plus the dashed mark overlay.
// A mark carries a crease id and reads to the reader as a flat crease, so it
// earns the same forgiving hover. The tiny partial-mark ticks stay untargeted.
export const HIT_SELECTOR =
  '[data-layer="creases"] line[data-kind="crease"], [data-layer="creases"] line[data-kind="mark"]';
export const POINT_SELECTOR = '[data-layer="annotations"] circle[data-vertex]';

// One transparent hit-line copying `line`'s endpoints and crease id, if it has
// one: a paper boundary carries no id, since there is no per-edge id to tag it
// with. The owner document is taken from the line rather than a global, so
// this behaves the same against a browser document and a headless one.
export function buildHitLine(line: Element): Element {
  const hit = line.ownerDocument.createElementNS(SVG_NS, "line");
  for (const attr of ["x1", "y1", "x2", "y2"]) {
    hit.setAttribute(attr, line.getAttribute(attr) ?? "0");
  }
  const creaseId = line.getAttribute("data-crease-id");
  if (creaseId !== null) hit.setAttribute("data-crease-id", creaseId);
  hit.setAttribute("class", HIT_CLASS);
  return hit;
}

const HIT_DOT_R = 10;

// The point twin is a disc rather than a fat stroke, so it takes the pointer
// over its whole area. It carries the identity the host resolves a dot by.
export function buildHitDot(dot: Element): Element {
  const hit = dot.ownerDocument.createElementNS(SVG_NS, "circle");
  for (const attr of ["cx", "cy"]) hit.setAttribute(attr, dot.getAttribute(attr) ?? "0");
  hit.setAttribute("r", String(HIT_DOT_R));
  for (const attr of ["data-vertex", "data-bel-name", "data-kind"]) {
    const v = dot.getAttribute(attr);
    if (v !== null) hit.setAttribute(attr, v);
  }
  hit.setAttribute("class", HIT_CLASS);
  return hit;
}

// Inserts a twin after every crease line and every point dot in `container`
// that has none. Idempotent: a mark already followed by its twin is skipped,
// so a second pass over unchanged markup stacks nothing.
export function enhanceHits(container: Element): void {
  container.querySelectorAll(HIT_SELECTOR).forEach((line) => {
    if (line.nextElementSibling?.classList.contains(HIT_CLASS)) return;
    line.after(buildHitLine(line));
  });
  container.querySelectorAll(POINT_SELECTOR).forEach((dot) => {
    if (dot.classList.contains(HIT_CLASS)) return; // a twin from an earlier pass
    if (dot.nextElementSibling?.classList.contains(HIT_CLASS)) return;
    dot.after(buildHitDot(dot));
  });
}
