// Palette lifted verbatim from tools/fold2svg.mjs:200-215, 227, 365, then
// switched from axiom-provenance coloring to FOLD edges_assignment (M/V/B/U/F)
// — provenance is a construction-history detail, not what a folder reading a
// diagram needs.
import type { Assignment } from "@beloch/scene";

export interface LineStyle {
  stroke: string;
  strokeWidth: number;
  dasharray?: string;
  opacity?: number;
}

// Pluggable per-assignment styling: callers can pass their own fn via
// `theme.lineStyle`, or pick one of the two below.
export type LineStyleFn = (assignment: Assignment, theme: Theme) => LineStyle;

// One entry of the highlight palette: `stroke` draws the entity (a line, a
// point dot, its label), `wash` fills the faces of a highlighted flap. The wash
// is a literal rather than a blend of `stroke` with the paper, because the web
// theme supplies its paper fills as CSS variables that no blend can read, and
// because a translucent face would break the folded view's layer occlusion.
export interface HighlightColor {
  stroke: string;
  wash: string;
}

export interface Theme {
  boundary: string;        // "#1f2937" — B
  mountain: string;        // "#dc2626" — M
  valley: string;          // "#2563eb" — V
  flat: string;            // "#64748b" — F (flat-foldable/unfolded crease)
  unassigned: string;      // "#a16207" — U
  paperFill: string;       // "#f8fafc"  (CP face fill)
  front: string;           // "#fafaf7"  (folded: paper front)
  back: string;            // "#dbe4ee"  (folded: paper back)
  construction: string;    // "#4f46e5"
  highlightPalette: HighlightColor[]; // one colour per entity the caller emphasises
  ink: string;             // "#0f172a"  (dots, labels, title)
  background: string;      // "white"    (full-canvas backdrop rect fill)
  lineStyle: LineStyleFn;
}

// Colored: one solid color per assignment. Simple, no dash decoding required.
export const colorLineStyle: LineStyleFn = (assignment, theme) => {
  switch (assignment) {
    case "B": return { stroke: theme.boundary, strokeWidth: 3 };
    case "M": return { stroke: theme.mountain, strokeWidth: 2 };
    case "V": return { stroke: theme.valley, strokeWidth: 2 };
    case "F": return { stroke: theme.flat, strokeWidth: 2, opacity: 0.45 };
    default: return { stroke: theme.unassigned, strokeWidth: 2, opacity: 0.55 };
  }
};

// Yoshizawa–Randlett: solid = boundary/unfolded, dashed = valley, dash-dot =
// mountain, dotted = unassigned [demaine2007, p.6428 — Yoshizawa's notation
// of dotted lines + arrows; exact dash/dash-dot split for M vs V is the
// widely-used convention but not itself sourced in refs/]. Monochrome by
// default (reads via `theme.ink`), default line style.
export const yrLineStyle: LineStyleFn = (assignment, theme) => {
  switch (assignment) {
    case "B": return { stroke: theme.boundary, strokeWidth: 3 };
    case "M": return { stroke: theme.ink, strokeWidth: 2, dasharray: "8 2 1 2" };
    case "V": return { stroke: theme.ink, strokeWidth: 2, dasharray: "6 4" };
    case "F": return { stroke: theme.ink, strokeWidth: 1.5, dasharray: "1 3", opacity: 0.45 };
    default: return { stroke: theme.unassigned, strokeWidth: 1.5, dasharray: "2 3", opacity: 0.55 };
  }
};

// The entities a figure's caption refers to, one colour each, taken in the
// order the `highlight` attribute lists them. The same six colours carry the
// caption's inline code on the docs site (`.figure-hl-<n>` in
// packages/www/src/styles/theme.css) and in the PDF (scripts/typst-compat.typ),
// so a name in the caption and the thing drawn read as one. They are literals
// here because typst places the SVG into the PDF and resolves no var().
// Each stroke sits at L* 49 to 56, which keeps it legible on the paper of a
// drawing and on a page of either site theme, at least ΔE76 19 from every
// Beloch token colour and ΔE76 50 from the others here. A `highlight` longer
// than the palette wraps round to the first colour and two entities then share
// one; six is well past the two the documents use today.
// Six colours a caption can point with. Measured: L* 50.1 to 55.9, at least
// dE76 55.3 from each other, 34.9 from mountain and valley, 27.2 from the
// interface accent, so a highlight is never mistaken for a fold or a control.
// Each wash is its stroke lightened towards white by 0.25, the ratio the
// previous palette already used throughout.
export const HIGHLIGHT_PALETTE: HighlightColor[] = [
  { stroke: "#079876", wash: "#c1e5dd" },
  { stroke: "#fb0069", wash: "#febfd9" },
  { stroke: "#a945ff", wash: "#e9d0ff" },
  { stroke: "#ce6400", wash: "#f3d8bf" },
  { stroke: "#0880d4", wash: "#c1dff4" },
  { stroke: "#7d8700", wash: "#dee1bf" },
];

// A highlight used as caption text needs 4.5:1, which the stroke values do not
// hold on white. These are the same hues, darkened, for text only.
export const HIGHLIGHT_TEXT: string[] = [
  "#07715a", "#c2004f", "#8a2fd6", "#b25600", "#0b6fb0", "#5f6600",
];

// flat, unassigned and construction were re-measured against the paper
// schemes and darkened: the old values sat at 2.45, 2.05 and below 3:1 on
// white, so a crease could not be told from the sheet it was drawn on.
export const DEFAULT_THEME: Theme = {
  boundary: "#1f2937",
  mountain: "#dc2626",
  valley: "#2563eb",
  flat: "#64748b",
  unassigned: "#a16207",
  paperFill: "#f8fafc",
  front: "#fafaf7",
  back: "#dbe4ee",
  construction: "#4f46e5",
  highlightPalette: HIGHLIGHT_PALETTE,
  ink: "#0f172a",
  background: "white",
  lineStyle: yrLineStyle,
};

// Web render path (SSR cards + live Playground): paper, ink, and boundary
// colors as CSS variables with a hex fallback. A client script sets the
// variables on :root from localStorage, so every inline SVG (including
// already-baked SSR) repaints without a rebuild. The fallback is the
// DEFAULT_THEME value, so the headless resvg path (which does NOT resolve
// var()) stays unchanged — it keeps using DEFAULT_THEME.
export const WEB_THEME: Partial<Theme> = {
  paperFill: "var(--bel-paper-cp, #f8fafc)",
  front:     "var(--bel-paper-front, #fafaf7)",
  back:      "var(--bel-paper-back, #dbe4ee)",
  ink:       "var(--bel-ink, #0f172a)",
  boundary:  "var(--bel-boundary, #1f2937)",
  // Default fallback keeps the white backdrop everywhere (SSR cards, hero);
  // only surfaces that opt in (the Playground) set --bel-bg: transparent.
  background: "var(--bel-bg, white)",
};
