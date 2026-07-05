// Palette lifted verbatim from tools/fold2svg.mjs:200-215, 227, 365.
export interface Theme {
  axioms: Record<string, { color: string; label: string }>; // axiom1..axiom7
  crease: string;          // "#f59e0b" — unnamed/unmatched crease
  boundary: string;        // "#1f2937"
  paperFill: string;       // "#f8fafc"  (CP face fill)
  front: string;           // "#fafaf7"  (folded: paper front)
  back: string;            // "#dbe4ee"  (folded: paper back)
  construction: string;    // "#6366f1"
  ink: string;             // "#0f172a"  (dots, labels, title)
}

export const DEFAULT_THEME: Theme = {
  axioms: {
    axiom1: { color: "#2563eb", label: "axiom 1 · through" },
    axiom2: { color: "#16a34a", label: "axiom 2 · map onto" },
    axiom3: { color: "#db2777", label: "axiom 3 · perp" },
    axiom4: { color: "#ea580c", label: "axiom 4 · project" },
    axiom5: { color: "#9333ea", label: "axiom 5 · map onto" },
    axiom6: { color: "#0d9488", label: "axiom 6 · map through" },
    axiom7: { color: "#7c3aed", label: "axiom 7 · map onto + onto" },
  },
  crease: "#f59e0b",
  boundary: "#1f2937",
  paperFill: "#f8fafc",
  front: "#fafaf7",
  back: "#dbe4ee",
  construction: "#6366f1",
  ink: "#0f172a",
};

export function edgeColor(theme: Theme, assignment: string, axiom: string | null): string {
  if (assignment === "B") return theme.boundary;
  return (axiom && theme.axioms[axiom]?.color) || theme.crease;
}
