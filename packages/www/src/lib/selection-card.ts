// The selection card: what a click in the drawing settled, shown on the
// drawing at the place that was clicked. Placement and content are pure, so
// the markup and the listeners stay in Playground.astro.
import type { HoverSummary } from "./tooltip-content";

export interface CardPlacement {
  left: string;
  top: string;
  transform: string;
}

// Where the card stands against its anchor, given the anchor's position in a
// stage of `width` × `height`. It stands above the anchor with its tip
// pointing down, and grows away from whichever edge the anchor is close to,
// so it stays inside the stage without measuring itself.
export function cardPlacement(x: number, y: number, width: number, height: number): CardPlacement {
  const fx = width > 0 ? x / width : 0.5;
  const fy = height > 0 ? y / height : 0.5;
  const tx = fx < 0.3 ? "-12px" : fx > 0.7 ? "calc(-100% + 12px)" : "-50%";
  const ty = fy < 0.22 ? "14px" : "calc(-100% - 14px)";
  return { left: `${x}px`, top: `${y}px`, transform: `translate(${tx}, ${ty})` };
}

export interface CardContent {
  name: string;
  line: number | null;
  text: string | null;
}

// The name of what was settled, the line of the program that made it, and
// that line as the run answered it. An entity no line made falls back to the
// summary's detail.
export function cardContent(summary: HoverSummary, line: number | null, source: string | null): CardContent {
  if (line === null) return { name: summary.title, line, text: summary.detail || null };
  const said = source?.split("\n")[line - 1]?.trim();
  return { name: summary.title, line, text: said || null };
}
