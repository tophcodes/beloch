/** The models the landing shows from examples/, and their two drawings in
 *  the landing's style. pages/landing/[drawing].svg.ts writes the drawings
 *  out as files, so a card loads them as images when it scrolls into view. */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseFold } from "@beloch/scene";
import { renderCP, renderFolded } from "@beloch/render-svg";
import { cachedFold, fitStep, LANDING_THEME, paperOnly } from "./landing-drawing";

export const MODELS = [
  { name: "Crane", file: "crane" },
  { name: "Frog", file: "traditional-frog" },
  { name: "Flapping bird", file: "flapping-bird" },
  { name: "Cicada", file: "cicada" },
] as const;

export type View = "cp" | "folded";

const source = (file: string) =>
  readFileSync(join(process.env.BELOCH_REPO_ROOT!, "examples", `${file}.bel`), "utf8");

/** A line of code: neither blank, nor a comment, nor an annotation. */
export function codeLines(file: string): number {
  return source(file).split("\n").filter((l) => !/^\s*(;|@|$)/.test(l)).length;
}

export function modelDrawing(file: string, view: View): string {
  const scene = parseFold(cachedFold(source(file)) as object);
  const bare = { theme: LANDING_THEME, annotate: [], dots: "annotated" as const };
  return view === "cp"
    ? paperOnly(renderCP(scene, bare))
    : paperOnly(renderFolded(scene, { ...bare, orient: true, layout: fitStep(scene) }));
}
