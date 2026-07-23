// Whole-bundle crease highlight (playground slice B, task 8): a `--var`
// named line is ONE crease_id whose segments are the bundle (ADR-0014) —
// hovering any one segment must highlight every segment sharing that id,
// across flaps/layers, not just the one under the cursor.
//
// `enhanceCreaseHits` (crease-hits.ts) inserts transparent `.pg-hit` twins
// carrying the SAME `data-crease-id` as a bigger click target. Those must
// never themselves pick up the highlight class — `.pg-hit`'s own CSS
// (`stroke: transparent`) only makes sense as long as nothing overrides it,
// and `.pg-hl` (a visible stroke) would. `bundleElements` filters them out
// so every caller that highlights-by-crease-id gets this for free.
const HIT_CLASS = "pg-hit";

// CSS.escape is available in real browsers and happy-dom, but guard anyway
// — crease ids are plain small integers in practice, so a minimal
// quote-escape is a safe fallback if it's ever missing.
function escapeAttr(id: string): string {
  return typeof CSS !== "undefined" && typeof CSS.escape === "function"
    ? CSS.escape(id)
    : id.replace(/"/g, '\\"');
}

// Every element carrying `data-crease-id="<creaseId>"` under `container`,
// excluding the synthetic `.pg-hit` twins.
export function bundleElements(container: ParentNode, creaseId: string): Element[] {
  return Array.from(container.querySelectorAll(`[data-crease-id="${escapeAttr(creaseId)}"]`)).filter(
    (el) => !el.classList.contains(HIT_CLASS),
  );
}
