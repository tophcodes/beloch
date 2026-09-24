/** The landing hero's folding sequence: the crease pattern the program ends
 *  on, and one step per write, each with the source lines that make it and
 *  the crease pattern as it stands after it. All of it is drawn at build time,
 *  so the page needs no evaluator to show it.
 *
 *  A read (`.o = …`, `--mid = …`) scores nothing, so it stands on the step of
 *  the write after it, which is the write it prepares. */
import { parseFold, type FoldScene, type Statement } from "@beloch/scene";
import { renderScene, colorLineStyle, WEB_THEME, type Theme } from "@beloch/render-svg";
import { lineOfSpan, parseSpan } from "@beloch/runtime-editor";
import { evalBelToFold } from "./eval-bel";

export interface HeroStep {
  /** The source lines of the step, a statement wrapped over several lines
   *  joined into one. */
  lines: string[];
  /** The crease pattern after this step, with the older creases dimmed. */
  figure: string;
  /** The same drawing without the corner names, for the step's own card. */
  thumb: string;
}

export interface HeroSequence {
  /** The crease pattern the program ends on. */
  final: string;
  steps: HeroStep[];
}

const THEME: Partial<Theme> = { ...WEB_THEME, lineStyle: colorLineStyle };
const CORNERS = [".a", ".b", ".c", ".d"];
// How far a crease scored before the step recedes behind the ones it adds.
const EARLIER_OPACITY = 0.3;

function crease(scene: FoldScene, upTo: number | "all", annotate: string[], fresh: Set<string> | null): string {
  const doc = renderScene(scene, {
    isometry: { kind: "flat" },
    texture: { upToStatement: upTo, creases: true, marks: true, points: false, lines: false, faces: "outline" },
    annotate,
    theme: THEME,
  });
  if (fresh !== null) {
    for (const line of doc.layer("creases").children) {
      const id = line.attrs["data-crease-id"];
      if (id !== undefined && !fresh.has(String(id))) line.attrs.opacity = EARLIER_OPACITY;
    }
  }
  return doc.toString();
}

// The creases a write scored: their provenance span starts on its line.
function scoredBy(scene: FoldScene, write: Statement): Set<string> {
  const ids = new Set<string>();
  for (const [id, c] of Object.entries(scene.inspect?.creases ?? {})) {
    if (lineOfSpan(c.span ?? null) === write.sourceLine) ids.add(id);
  }
  return ids;
}

// Lines `from`..`to` (1-based, inclusive) that carry code, with a line that
// continues a statement (indented) joined onto the one before it.
function codeLines(source: string[], from: number, to: number): string[] {
  const out: string[] = [];
  for (const raw of source.slice(from - 1, to)) {
    const text = raw.replace(/;.*$/, "").trimEnd();
    if (text.trim() === "") continue;
    if (/^\s/.test(text) && out.length > 0) out[out.length - 1] += " " + text.trim();
    else out.push(text);
  }
  return out;
}

export function heroSequence(src: string): HeroSequence {
  const scene = parseFold(evalBelToFold(src) as object);
  const source = src.split("\n");
  // The first write takes whatever follows the paper line.
  let after = source.findIndex((l) => /^\s*paper\b/.test(l)) + 1;
  const steps = scene.writes.map((write) => {
    let end = (write.span ? parseSpan(write.span)?.toLine : null) ?? write.sourceLine;
    // The span can stop short of an indented line that finishes the statement.
    while (end < source.length && /^\s+\S/.test(source[end]!)) end++;
    const lines = codeLines(source, after + 1, end);
    after = end;
    const fresh = scoredBy(scene, write);
    return {
      lines,
      figure: crease(scene, write.index, CORNERS, fresh),
      thumb: crease(scene, write.index, [], fresh),
    };
  });
  // Drawn as of its last write rather than as "all", so it marks the points
  // the steps mark and no crossing they leave out.
  const last = scene.writes.at(-1)?.index ?? "all";
  return { final: crease(scene, last, CORNERS, null), steps };
}
