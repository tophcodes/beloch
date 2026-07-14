// Deterministic label placement for the annotations layer. Two jobs, both
// byte-stable (no solver, no randomness) so golden snapshots stay put:
//   1. Coincidence clustering — anchors sharing a point (within ε px) merge
//      into one label (".a,.b,.c,.d"), fixing the cube-root folded collapse
//      where four corner names stack on one pixel.
//   2. Greedy placement — each cluster first tries its caller-supplied
//      `preferOffset` (the legacy per-view heuristic); only if that box
//      overlaps an already-placed label does it walk a fixed candidate ring.
// Because the preferred offset is tried first, a diagram with no colliding
// labels renders exactly as before — the ring engages only to separate a
// genuine overlap.
import type { Vec2 } from "@beloch/scene";

export interface LabelAnchor {
  x: number; // anchor point, screen px
  y: number;
  text: string; // the label as it would render for this single anchor, e.g. ".a"
  key: string; // identity for clustering + dedup (usually the bel name)
  preferOffset: Vec2; // legacy heuristic offset from (x,y), tried first
}

export type TextAnchor = "start" | "middle" | "end";

export interface PlacedLabel {
  x: number; // text origin, screen px
  y: number;
  text: string; // merged text for the cluster
  anchor: TextAnchor;
  keys: string[]; // every anchor key folded into this cluster (sorted)
}

export interface LabelOptions {
  fontSize?: number; // default 15 (governs bbox height + char width)
  epsilon?: number; // coincidence radius px, default 6
  charW?: number; // per-char advance px, default 0.62*fontSize
}

interface Box {
  x0: number;
  x1: number;
  y0: number;
  y1: number;
}

// bbox of a would-be <text> placed at (x,y) with the given anchor. Text sits
// above its baseline, so the box spans [y-h, y+0.2h] — a small descender pad.
function textBox(
  x: number,
  y: number,
  anchor: TextAnchor,
  w: number,
  h: number,
): Box {
  const x0 = anchor === "start" ? x : anchor === "middle" ? x - w / 2 : x - w;
  return { x0, x1: x0 + w, y0: y - h, y1: y + 0.2 * h };
}

function overlaps(a: Box, b: Box): boolean {
  return a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1;
}

// Fixed candidate ring, walked in this order when the preferred offset is
// taken. Radius scales with font size; anchor chosen so text grows away from
// the point (left of anchor → end-anchored, etc). Deterministic order.
function ring(r: number): { off: Vec2; anchor: TextAnchor }[] {
  return [
    { off: [-r, r * 1.1], anchor: "end" }, // SW
    { off: [r, r * 1.1], anchor: "start" }, // SE
    { off: [-r, -r * 0.6], anchor: "end" }, // NW
    { off: [r, -r * 0.6], anchor: "start" }, // NE
    { off: [0, r * 1.4], anchor: "middle" }, // S
    { off: [0, -r], anchor: "middle" }, // N
    { off: [-r * 1.3, r * 0.3], anchor: "end" }, // W
    { off: [r * 1.3, r * 0.3], anchor: "start" }, // E
  ];
}

// Cluster coincident anchors and place one non-overlapping label per cluster.
export function placeLabels(
  anchors: LabelAnchor[],
  opts: LabelOptions = {},
): PlacedLabel[] {
  const fontSize = opts.fontSize ?? 15;
  const eps = opts.epsilon ?? 6;
  const charW = opts.charW ?? 0.62 * fontSize;
  const h = fontSize;

  // 1. Coincidence clustering (single-link within ε on the anchor point).
  interface Cluster {
    x: number;
    y: number;
    members: LabelAnchor[];
  }
  const clusters: Cluster[] = [];
  for (const a of anchors) {
    const c = clusters.find(
      (cl) => Math.hypot(cl.x - a.x, cl.y - a.y) <= eps,
    );
    if (c) c.members.push(a);
    else clusters.push({ x: a.x, y: a.y, members: [a] });
  }

  // Deterministic processing order: by anchor point, then merged text.
  const prepared = clusters.map((cl) => {
    const members = [...cl.members].sort((p, q) => (p.key < q.key ? -1 : p.key > q.key ? 1 : 0));
    const text = members.map((m) => m.text).join(",");
    const keys = members.map((m) => m.key);
    // shared anchor point = centroid of the cluster's members
    const x = members.reduce((s, m) => s + m.x, 0) / members.length;
    const y = members.reduce((s, m) => s + m.y, 0) / members.length;
    return { x, y, text, keys, prefer: members[0]!.preferOffset };
  });
  prepared.sort((a, b) =>
    a.y !== b.y ? a.y - b.y : a.x !== b.x ? a.x - b.x : a.text < b.text ? -1 : 1,
  );

  // 2. Greedy placement.
  const placed: PlacedLabel[] = [];
  const boxes: Box[] = [];
  const r = fontSize;
  for (const c of prepared) {
    const w = c.text.length * charW;
    // preferred candidate first (start-anchored, matching the legacy emit)
    const candidates: { x: number; y: number; anchor: TextAnchor }[] = [
      { x: c.x + c.prefer[0], y: c.y + c.prefer[1], anchor: "start" },
      ...ring(r).map((rc) => ({
        x: c.x + rc.off[0],
        y: c.y + rc.off[1],
        anchor: rc.anchor,
      })),
    ];
    let chosen = candidates[0]!;
    for (const cand of candidates) {
      const box = textBox(cand.x, cand.y, cand.anchor, w, h);
      if (!boxes.some((b) => overlaps(box, b))) {
        chosen = cand;
        break;
      }
    }
    boxes.push(textBox(chosen.x, chosen.y, chosen.anchor, w, h));
    placed.push({ x: chosen.x, y: chosen.y, text: c.text, anchor: chosen.anchor, keys: c.keys });
  }
  return placed;
}
