// Palette lifted verbatim from tools/fold2svg.mjs:200-215, 227, 365, then
// switched from axiom-provenance coloring to FOLD edges_assignment (M/V/B/U/F)
// — provenance is a construction-history detail, not what a folder reading a
// diagram needs.
import type { Assignment } from "@beloch/scene";

export interface LineStyle {
  stroke: string;
  strokeWidth: number;
  dasharray?: string;
}

// Pluggable per-assignment styling: callers can pass their own fn via
// `theme.lineStyle`, or pick one of the two below.
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

// Colored: one solid color per assignment. Simple, no dash decoding required.
export const colorLineStyle: LineStyleFn = (assignment, theme) => {
  switch (assignment) {
    case "B": return { stroke: theme.boundary, strokeWidth: 2.5 };
    case "M": return { stroke: theme.mountain, strokeWidth: 2 };
    case "V": return { stroke: theme.valley, strokeWidth: 2 };
    case "F": return { stroke: theme.flat, strokeWidth: 2 };
    default: return { stroke: theme.unassigned, strokeWidth: 2 };
  }
};

// Yoshizawa–Randlett: solid = boundary/unfolded, dashed = valley, dash-dot =
// mountain, dotted = unassigned [demaine2007, p.6428 — Yoshizawa's notation
// of dotted lines + arrows; exact dash/dash-dot split for M vs V is the
// widely-used convention but not itself sourced in refs/]. Monochrome by
// default (reads via `theme.ink`), default line style.
export const yrLineStyle: LineStyleFn = (assignment, theme) => {
  switch (assignment) {
    case "B": return { stroke: theme.boundary, strokeWidth: 2.5 };
    case "M": return { stroke: theme.ink, strokeWidth: 2, dasharray: "8 2 1 2" };
    case "V": return { stroke: theme.ink, strokeWidth: 2, dasharray: "6 4" };
    case "F": return { stroke: theme.ink, strokeWidth: 1.5, dasharray: "1 3" };
    default: return { stroke: theme.unassigned, strokeWidth: 1.5, dasharray: "2 3" };
  }
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
