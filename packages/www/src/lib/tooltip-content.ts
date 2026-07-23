// Entity inspector tooltip content (playground slice B, task 8): pure data
// selection for the cursor-following tooltip, split from HTML templating
// (which stays in Playground.astro so `escapeHtml` is applied at the one
// place user-derived strings — names, sources — get written into innerHTML).
import type { Inspect } from "@beloch/scene";
import { type EntityRef, lineOfSpan } from "./inspect-lookup";
import { segRank } from "./stack-picker";

// The tooltip's un-anchored (hover) content: one title + one detail line,
// for all three entity kinds. Crease -> name (or id) + the bundle's TRUE
// segment count (`insp.creases[id].segments.length`, even if fewer are
// drawn this step under occlusion). Face -> flap/rank. Vertex -> name (+
// face/flap if known) — this is the same lightweight info Task 5's fixed
// panel showed for these two kinds, just now living in the follow-tooltip.
// Returns null when the current scene's `inspect` has nothing for `ref`
// (e.g. a scene evaluated before `beloch:inspect` was emitted).
export interface HoverSummary {
  title: string;
  detail: string;
}

export function hoverSummary(ref: EntityRef, insp: Inspect): HoverSummary | null {
  if (ref.kind === "crease") {
    const c = insp.creases[ref.creaseId];
    if (!c) return null;
    const n = c.segments.length;
    const segs = `${n} segment${n === 1 ? "" : "s"}`;
    if (c.name) return { title: `--${c.name}`, detail: segs };
    // Unnamed crease (an unbound fold's result): show WHERE it was made so the
    // user can find the statement and bind/assign it.
    const ln = lineOfSpan(c.span);
    return { title: "unnamed line", detail: `${ln ? `at line ${ln} · ` : ""}${segs}` };
  }
  if (ref.kind === "edge") {
    const e = insp.edges[ref.name];
    if (!e) return null;
    const n = e.segments.length;
    return { title: `--${e.name}`, detail: `${n} segment${n === 1 ? "" : "s"}` };
  }
  if (ref.kind === "face") {
    const f = insp.faces[ref.index];
    if (!f) return null;
    return { title: `face ${ref.index}`, detail: `flap ${f.flap} · rank ${f.rank}` };
  }
  const p = ref.name ? insp.points[ref.name] : null;
  return {
    title: ref.name ? `.${ref.name}` : `vertex ${ref.index}`,
    detail: p ? `face ${p.face ?? "—"} · flap ${p.flap ?? "—"}` : "",
  };
}

// The anchored tooltip's segment list for one crease bundle — subsumes the
// Task 7 stack picker (which lived as a separate panel section) into one
// list. `sortByRank` mirrors the Task 5/7 rule: the folded view stacks
// coincident segments at the same projected position, so ordering
// top-of-stack first (via `segRank`, descending) reads like the physical
// layer order; the CP view has no stacking (segments are spatially
// separate there), so the caller passes `sortByRank: false` to keep
// segment-array order instead.
export interface SegmentRow {
  index: number;
  faceL: number;
  faceR: number;
  assignment: string;
  rank: number;
}

export function segmentRows(insp: Inspect, creaseId: string, sortByRank: boolean): SegmentRow[] {
  const c = insp.creases[creaseId];
  if (!c) return [];
  const rows: SegmentRow[] = c.segments.map((s, i) => ({
    index: i,
    faceL: s.faces[0]!,
    faceR: s.faces[1]!,
    assignment: s.assignment,
    rank: segRank(insp, s),
  }));
  if (sortByRank) rows.sort((a, b) => b.rank - a.rank);
  return rows;
}

// The anchored tooltip's segment list for one paper-boundary edge bundle
// (task 9) — same shape/purpose as segmentRows above, but a boundary
// segment borders only ONE face (there's no far side, it's the sheet's
// edge — see InspectSegment's comment in types.ts), so there's no l|r pair
// and no stacking rank to speak of; the row is just `face <fi> · B`.
export interface EdgeSegmentRow {
  index: number;
  face: number;
  assignment: string;
}

export function edgeSegmentRows(insp: Inspect, name: string): EdgeSegmentRow[] {
  const e = insp.edges[name];
  if (!e) return [];
  return e.segments.map((s, i) => ({ index: i, face: s.faces[0]!, assignment: s.assignment }));
}
