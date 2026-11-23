/** The landing hero: a program shown line by line beside two drawings of
 *  each fold, the folded state and the crease pattern after it. Every drawing
 *  is made at build time, so the page needs no evaluator; its script only
 *  swaps which pair is shown and which lines are lit.
 *
 *  A fold is a step of the folded state (`scene.steps`). A mark scores a line
 *  but folds nothing, so it shows in the crease pattern of the fold after it
 *  and has no step of its own. */
import { orientationAt, parseFold, type FoldScene } from "@beloch/scene";
import {
  colorLineStyle, makeLayout, renderFolded, renderScene, turnFrame, WEB_THEME, type Layout, type Theme,
} from "@beloch/render-svg";
import { lineOfSpan, parseSpan } from "@beloch/runtime-editor";
import { evalBelToFold } from "./eval-bel";
import { highlightBel } from "./highlight-bel";

export interface HeroFold {
  /** The lines of the fold's statement, 1-based and inclusive. */
  from: number;
  to: number;
  /** The folded state after the fold. */
  folded: string;
  /** The crease pattern after the fold, the older creases dimmed. */
  cp: string;
}

export interface HeroProgram {
  /** The program, highlighted, one HTML string per source line. */
  lines: string[];
  folds: HeroFold[];
  /** What a name in the program stands for, keyed by the name with its
   *  sigil (`.o`, `--wl`): where it comes from and the line that made it. */
  tips: Record<string, string>;
}

const THEME: Partial<Theme> = { ...WEB_THEME, lineStyle: colorLineStyle };
// The drawings write out no name and draw no point: the program beside them
// carries the names.
const BARE = { theme: THEME, annotate: [], dots: "annotated" as const };
// How far a crease scored before the fold recedes behind the ones it adds.
const EARLIER_OPACITY = 0.3;
// A tip quotes the statement behind a name up to this many characters.
const TIP_QUOTE = 44;

// The creases a fold scored: the source span the kernel records for each of
// them starts on the fold's line.
function scoredOn(scene: FoldScene, line: number): Set<string> {
  const ids = new Set<string>();
  for (const [id, c] of Object.entries(scene.inspect?.creases ?? {})) {
    if (lineOfSpan(c.span ?? null) === line) ids.add(id);
  }
  return ids;
}

function creasePattern(scene: FoldScene, frame: number, fresh: Set<string>): string {
  // The crease filter counts statements, the steps count frames: the last
  // statement that reads against this frame is the one whose creases the
  // sheet already carries.
  const upTo = scene.statements.reduce((last, st, i) => (st.frameIndex <= frame ? i : last), -1);
  const doc = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStatement: upTo, creases: true, marks: true, points: false, lines: false, faces: "outline" },
    ...BARE,
  });
  for (const line of doc.layer("creases").children) {
    const id = line.attrs["data-crease-id"];
    if (id !== undefined && !fresh.has(String(id))) line.attrs.opacity = EARLIER_OPACITY;
  }
  return doc.toString();
}

const CORNERS = new Set([".a", ".b", ".c", ".d"]);
const EDGES = new Set(["--ab", "--bc", "--cd", "--da"]);

function quote(text: string): string {
  return text.length > TIP_QUOTE ? text.slice(0, TIP_QUOTE - 1).trimEnd() + "…" : text;
}

/** The tips of the names a program binds, read off its source: a binding
 *  `.o = …` names a point or a line, and `as --x` at the end of a statement
 *  names what that statement made. A statement continues on every indented
 *  line under it. */
export function nameTips(source: string): Record<string, string> {
  const tips: Record<string, string> = {};
  for (const c of CORNERS) tips[c] = `${c}  ·  corner of the sheet`;
  for (const e of EDGES) tips[e] = `${e}  ·  edge of the sheet`;
  const lines = source.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const head = lines[i]!.replace(/;.*$/, "").trimEnd();
    if (head.trim() === "" || /^\s/.test(head) || head.startsWith("@")) continue;
    let text = head;
    for (let j = i + 1; j < lines.length && /^\s+\S/.test(lines[j]!); j++) {
      text += " " + lines[j]!.replace(/;.*$/, "").trim();
    }
    const at = `line ${i + 1}`;
    const bound = /^(\.[\w]+|--[\w]+)\s*=\s*(.+)$/.exec(text);
    if (bound) {
      const [, name, rhs] = bound;
      const kind = name!.startsWith(".") ? "point" : "line";
      tips[name!] = `${name}  ·  ${kind}, ${at}  ·  ${quote(rhs!)}`;
      continue;
    }
    for (const [, name] of text.matchAll(/\bas\s+(\.[\w]+|--[\w]+)/g)) {
      const kind = name!.startsWith(".") ? "point" : text.startsWith("mark") ? "marked line" : "crease";
      tips[name!] = `${name}  ·  ${kind}, ${at}  ·  ${quote(text)}`;
    }
  }
  return tips;
}

// One frame per folded step: a square centered on the step's drawing, turned
// by the `@orient` in force there. Every square has the side of the widest
// step, so the paper keeps one scale and visibly shrinks as it is folded.
function stepLayouts(scene: FoldScene): Layout[] {
  const boxes = scene.steps.map((step) => {
    const turn = orientationAt(scene, step.index);
    const vs = turn === 0 ? step.frame.vertices : turnFrame(step.frame, turn).frame.vertices;
    const xs = vs.map((v) => v[0]), ys = vs.map((v) => v[1]);
    return { minX: Math.min(...xs), maxX: Math.max(...xs), minY: Math.min(...ys), maxY: Math.max(...ys) };
  });
  const half = Math.max(...boxes.map((b) => Math.max(b.maxX - b.minX, b.maxY - b.minY))) / 2;
  return boxes.map((b) => {
    const cx = (b.minX + b.maxX) / 2, cy = (b.minY + b.maxY) / 2;
    return makeLayout([[cx - half, cy - half], [cx + half, cy + half]]);
  });
}

export async function heroProgram(src: string): Promise<HeroProgram> {
  const scene = parseFold(evalBelToFold(src) as object);
  const source = src.split("\n");
  // No token spans a line break, so the highlighted program splits where the
  // source does.
  const lines = (await highlightBel(src)).split("\n").slice(0, source.length);
  const layouts = stepLayouts(scene);
  const folds = scene.steps.flatMap((step, k): HeroFold[] => {
    if (k === 0 || step.sourceLine == null) return [];
    const write = scene.writes.find((w) => w.sourceLine === step.sourceLine);
    let to = (write?.span ? parseSpan(write.span)?.toLine : null) ?? step.sourceLine;
    // The span can stop short of an indented line that finishes the statement.
    while (to < source.length && /^\s+\S/.test(source[to]!)) to++;
    return [{
      from: step.sourceLine,
      to,
      folded: renderFolded(scene, { ...BARE, step: String(step.index), orient: true, layout: layouts[k] }).toString(),
      cp: creasePattern(scene, step.index, scoredOn(scene, step.sourceLine)),
    }];
  });
  return { lines, folds, tips: nameTips(src) };
}
