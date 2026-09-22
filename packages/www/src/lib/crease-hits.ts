// Hit areas for the thin marks the renderer draws: crease `<line>`s
// (stroke-width ~1-2, see render-scene.ts's `theme.lineStyle`) and point
// dots (r = 3) are too fine a target to reliably hover/click. This inserts a transparent,
// fatter sibling line with the SAME endpoints + `data-crease-id` right
// after each real crease line, so `lookupEntity` resolves the hit line
// exactly like the visible one, while CSS (`.pg-hit` in Playground.astro)
// gives it a forgiving `pointer-events: stroke` hit area.
//
// Only real crease segments get a hit line — mark/mark-tick overlay lines
// live in the SAME `data-layer="creases"` group and also carry
// `data-crease-id` (see render-scene.ts's `markAttrs`), but they aren't
// part of the crease bundle and shouldn't gain a click target of their own.
//
// Task 9: this now matches EVERY crease-layer line, not just ones with a
// `data-crease-id` — paper boundary (B) lines carry no id at all (there is
// no per-edge id to tag them with), so they need a hit target too; they're
// re-identified by geometry instead (see edge-lookup.ts). Exported so
// Playground.astro can also query "every real crease-layer line" (as
// opposed to its `.pg-hit` twins, which never carry `data-kind`) when
// hunting for a boundary line's edge bundle by geometry.
export const CREASE_SELECTOR = '[data-layer="creases"] line[data-kind="crease"]';
// Lines that get a fat hit target: real creases PLUS the dashed mark overlay
// (flat precreases) — those carry data-crease-id too and read to the user as
// "flat creases", so they deserve the same forgiving hover as a fold crease.
// (mark-tick — the tiny partial-mark ticks — stay untargeted.)
export const HIT_SELECTOR =
  '[data-layer="creases"] line[data-kind="crease"], [data-layer="creases"] line[data-kind="mark"]';
export const HIT_CLASS = "pg-hit";
const SVG_NS = "http://www.w3.org/2000/svg";

// Pure factory: one transparent hit-line copying `line`'s endpoints + crease
// id (if it has one — a boundary line doesn't). Takes the owner Document
// explicitly (rather than reading a global) so it behaves the same against a
// real document or a happy-dom one in tests.
export function buildHitLine(doc: Document, line: Element): Element {
  const hit = doc.createElementNS(SVG_NS, "line");
  for (const attr of ["x1", "y1", "x2", "y2"]) {
    hit.setAttribute(attr, line.getAttribute(attr) ?? "0");
  }
  const creaseId = line.getAttribute("data-crease-id");
  if (creaseId !== null) hit.setAttribute("data-crease-id", creaseId);
  hit.setAttribute("class", HIT_CLASS);
  return hit;
}

// Inserts a hit-line sibling after every crease line in `container` that
// doesn't already have one. Idempotent — skips a line already followed by
// a `.pg-hit`, so re-running against the SAME (unchanged) markup doesn't
// stack duplicates. Call this after every `showSvg` injection.
export function enhanceCreaseHits(container: Element): void {
  const doc = container.ownerDocument;
  container.querySelectorAll(HIT_SELECTOR).forEach((line) => {
    const next = line.nextElementSibling;
    if (next?.classList.contains(HIT_CLASS)) return;
    line.after(buildHitLine(doc, line));
  });
}

// Point dots are drawn at r = 3 in the annotations layer, which is a 6px
// target. Same treatment as a crease line: a transparent, fatter twin right
// after the dot, carrying the identity `lookupEntity` resolves by
// (`closest("[data-vertex]")`, plus the name when the dot has one).
export const POINT_SELECTOR = '[data-layer="annotations"] circle[data-vertex]';
const HIT_DOT_R = 10;

export function buildHitDot(doc: Document, dot: Element): Element {
  const hit = doc.createElementNS(SVG_NS, "circle");
  for (const attr of ["cx", "cy"]) hit.setAttribute(attr, dot.getAttribute(attr) ?? "0");
  hit.setAttribute("r", String(HIT_DOT_R));
  for (const attr of ["data-vertex", "data-bel-name", "data-kind"]) {
    const v = dot.getAttribute(attr);
    if (v !== null) hit.setAttribute(attr, v);
  }
  hit.setAttribute("class", HIT_CLASS);
  return hit;
}

// Idempotent, like enhanceCreaseHits: a dot already followed by its twin is
// skipped, so re-running against unchanged markup stacks nothing.
export function enhancePointHits(container: Element): void {
  const doc = container.ownerDocument;
  container.querySelectorAll(POINT_SELECTOR).forEach((dot) => {
    if (dot.classList.contains(HIT_CLASS)) return; // a twin from an earlier run
    const next = dot.nextElementSibling;
    if (next?.classList.contains(HIT_CLASS)) return;
    dot.after(buildHitDot(doc, dot));
  });
}
