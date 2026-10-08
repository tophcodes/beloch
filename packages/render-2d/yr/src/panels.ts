// Which panels a program becomes: one per step group, one per write outside
// any group, and one for the final state (docs/reference/BELOCH-ANNOTATIONS.md).
import type { Annotation, FoldScene, Statement, Vec2 } from "@beloch/scene";
import { clipSegmentToPoly, pointInPolygon } from "@beloch/render-svg";
import { foldMotion, overlapArea, turnOver } from "./motion";

export interface Panel {
  number: string;          // "3", or "3a" when a step group is split
  text: string | null;     // the instruction under the panel
  base: number;            // index into scene.steps: the state the panel draws
  writes: Statement[];     // the writes the panel draws lines and arrows for; [] on the final panel
}

const neutral = (scene: FoldScene, key: string) =>
  scene.annotations.filter((a) => a.namespace === null && a.key === key);

// The statements an annotation belongs to, or null for one that belongs to a
// state or to the program as a whole.
const range = (a: Annotation): [number, number] | null => (Array.isArray(a.target) ? a.target : null);

const textOf = (a: Annotation | undefined): string | null => {
  const arg = a?.args.find((x) => x.kind === "text");
  return arg?.kind === "text" ? arg.text : null;
};

// The state a write is drawn on: a fold reads the state before the one it
// yields; a mark stands on the state it scores.
const baseOf = (w: Statement) => (w.kind === "fold" ? w.frameIndex - 1 : w.frameIndex);

// The paper a write moves, as convex paper polygons; a mark moves none, and a
// turn-over is counted apart by `split`.
const movedBy = (scene: FoldScene, w: Statement): Vec2[][] =>
  w.kind === "fold" && turnOver(scene, w) === null ? foldMotion(scene, w).moved : [];

// Whether the write folds or scores paper that one of `moved` covers.
function touches(scene: FoldScene, w: Statement, moved: Vec2[][]): boolean {
  if (w.kind === "fold") {
    const own = movedBy(scene, w);
    return own.some((p) => moved.some((q) => overlapArea(p, q) > 1e-9));
  }
  if (w.mark?.kind !== "seg") return false;
  const { a, b } = w.mark;
  return moved.some((q) => {
    const cut = clipSegmentToPoly(a, b, q);
    if (!cut) return false;
    const mid: Vec2 = [(cut[0][0] + cut[1][0]) / 2, (cut[0][1] + cut[1][1]) / 2];
    return pointInPolygon(mid, q);
  });
}

const isTurnOver = (scene: FoldScene, w: Statement) => w.kind === "fold" && turnOver(scene, w) !== null;

// Splits the writes of one step group where a write touches paper an earlier
// write of the same part moved: the earlier one has to be drawn folded first.
// `touched` says whether that happened. A turn-over is always a part of its
// own, drawn on the state the writes before it leave, so that the folder sees
// the result before turning the paper over [lang1991conventions, Part I].
function split(scene: FoldScene, writes: Statement[]): { parts: Statement[][]; touched: boolean } {
  const parts: Statement[][] = [];
  let moved: Vec2[][] = [];
  let alone = false;
  let touched = false;
  for (const w of writes) {
    const current = parts[parts.length - 1];
    const turn = isTurnOver(scene, w);
    const touching = !turn && touches(scene, w, moved);
    if (!current || alone || turn || touching) {
      if (current && touching && !alone) touched = true;
      parts.push([w]);
      moved = movedBy(scene, w);
    } else {
      current.push(w);
      moved = [...moved, ...movedBy(scene, w)];
    }
    alone = turn;
  }
  return { parts, touched };
}

export function panels(scene: FoldScene): { panels: Panel[]; hints: string[] } {
  const steps = neutral(scene, "step").filter((a) => range(a) !== null);
  const says = neutral(scene, "say");
  const sayOn = (i: number) => textOf(says.find((a) => range(a)?.[0] === i));
  const groupOf = (i: number) => steps.find((a) => range(a)![0] <= i && i <= range(a)![1]);

  const out: Panel[] = [];
  const hints: string[] = [];
  let n = 0;
  const done = new Set<Annotation>();
  for (const w of scene.writes) {
    const group = groupOf(w.index);
    if (!group) {
      out.push({ number: String(++n), text: sayOn(w.index), base: baseOf(w), writes: [w] });
      continue;
    }
    if (done.has(group)) continue;
    done.add(group);
    const writes = scene.writes.filter((x) => range(group)![0] <= x.index && x.index <= range(group)![1]);
    const { parts, touched } = split(scene, writes);
    const number = String(++n);
    const says = (ws: Statement[]) => ws.map((x) => sayOn(x.index)).filter((t) => t !== null).join(" ") || null;
    if (parts.length > 1) {
      const names = parts.map((_, k) => number + String.fromCharCode(97 + k));
      const listed = names.length === 2 ? `${names[0]} and ${names[1]}` : `${names.slice(0, -1).join(", ")} and ${names.at(-1)}`;
      // a turn-over in its own panel is the rule and earns no hint
      if (touched) {
        hints.push(
          `the step on line ${group.sourceLine} folds paper an earlier fold of the step moved; it is drawn as ${listed}. ` +
          `Give each of its folds an @say, or split the step`,
        );
      }
      // A part says what its own folds do. The step's sentence covers all of
      // them, so it stands once, under the first part, and a part without a
      // sentence of its own stays blank: under every part, it would tell the
      // folder to fold each part's folds again.
      parts.forEach((part, k) => out.push({
        number: names[k]!, text: says(part) ?? (k === 0 ? textOf(group) : null), base: baseOf(part[0]!), writes: part,
      }));
    } else {
      out.push({ number, text: textOf(group) ?? says(writes), base: baseOf(writes[0]!), writes });
    }
  }
  const last = scene.steps.length - 1;
  const closing = says.find((a) => a.target === null && a.frameIndex === last);
  out.push({ number: String(++n), text: textOf(closing), base: last, writes: [] });
  return { panels: out, hints };
}
