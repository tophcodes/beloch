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
// `theme.lineStyle`, or pick one of the PRESETS below.
export type LineStyleFn = (assignment: Assignment, theme: Theme) => LineStyle;

export interface Theme {
  boundary: string;        // "#1f2937" — B
  mountain: string;        // "#dc2626" — M
  valley: string;          // "#2563eb" — V
  flat: string;            // "#94a3b8" — F (flat-foldable/unfolded crease)
  unassigned: string;      // "#f59e0b" — U
  paperFill: string;       // "#f8fafc"  (CP face fill)
  front: string;           // "#fafaf7"  (folded: paper front)
  back: string;            // "#dbe4ee"  (folded: paper back)
  construction: string;    // "#6366f1"
  ink: string;             // "#0f172a"  (dots, labels, title)
  lineStyle: LineStyleFn;
}

// Yoshizawa–Randlett: solid = boundary/unfolded, dash-dot = mountain, dashed =
// valley, dotted = hidden/flat, monochrome ink [demaine2007, p.642 —
// Yoshizawa's notation of dotted lines + arrows]. Dash-pattern choice per
// Lang's diagramming conventions (langorigami.com/article/origami-diagramming-conventions/):
// valley = dashed ("no ifs, ands, or buts"), mountain = dot-dash (1 or 2 dots
// both acceptable), hidden/x-ray = dotted, edges heavier than creases. This
// replaces the old M dasharray `8 2 1 2`, whose 8px dash reads as visually
// solid at typical PNG render scale — indistinguishable from the boundary.
export const yrLineStyle: LineStyleFn = (assignment, theme) => {
  switch (assignment) {
    case "B": return { stroke: theme.boundary, strokeWidth: 3 };
    case "M": return { stroke: theme.ink, strokeWidth: 1.75, dasharray: "10 3 1.5 3" };
    case "V": return { stroke: theme.ink, strokeWidth: 1.75, dasharray: "6 4" };
    case "F": return { stroke: theme.ink, strokeWidth: 1.25, dasharray: "1 3", opacity: 0.45 };
    default: return { stroke: theme.unassigned, strokeWidth: 1.25, dasharray: "2 3", opacity: 0.55 };
  }
};

// Print-friendly weight-coded CP [hull2020, §7.1]: "denote a mountain crease
// with a bold line and a valley crease by a non-bold line ... using bold and
// non-bold lines will look more clear" — Hull explicitly drops dash patterns
// for dense crease patterns, coding M/V by stroke weight alone instead.
// Monochrome ink, all solid.
export const monoLineStyle: LineStyleFn = (assignment, theme) => {
  switch (assignment) {
    case "B": return { stroke: theme.ink, strokeWidth: 3 };
    case "M": return { stroke: theme.ink, strokeWidth: 2.6 };
    case "V": return { stroke: theme.ink, strokeWidth: 1.2 };
    case "F": return { stroke: theme.ink, strokeWidth: 1, dasharray: "1 3", opacity: 0.4 };
    default: return { stroke: theme.ink, strokeWidth: 1.2, dasharray: "2 3", opacity: 0.55 };
  }
};

// Tool-color convention, one solid color per assignment — aligns with Origami
// Simulator's undriven color (origamisimulator.org: M red, V blue, B black,
// undriven magenta). Subsumes the old `colorLineStyle`. `unassigned` here is
// hardcoded magenta rather than theme.unassigned (amber) specifically to match
// that convention; other presets keep theme.unassigned.
export const cpLineStyle: LineStyleFn = (assignment, theme) => {
  switch (assignment) {
    case "B": return { stroke: theme.boundary, strokeWidth: 3 };
    case "M": return { stroke: theme.mountain, strokeWidth: 2 };
    case "V": return { stroke: theme.valley, strokeWidth: 2 };
    case "F": return { stroke: theme.flat, strokeWidth: 1.5, opacity: 0.5 };
    default: return { stroke: "#d946ef", strokeWidth: 2, opacity: 0.8 };
  }
};

// Selectable line-style presets, keyed by the CLI's `--style` value.
export const PRESETS: Record<string, LineStyleFn> = {
  yr: yrLineStyle,
  mono: monoLineStyle,
  cp: cpLineStyle,
};

export const DEFAULT_THEME: Theme = {
  boundary: "#1f2937",
  mountain: "#dc2626",
  valley: "#2563eb",
  flat: "#94a3b8",
  unassigned: "#f59e0b",
  paperFill: "#f8fafc",
  front: "#fafaf7",
  back: "#dbe4ee",
  construction: "#6366f1",
  ink: "#0f172a",
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
};
