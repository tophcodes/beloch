export interface EdgeProv {
  span: string;
  step: string | null;
}

export interface HostToWebview {
  type: "render";
  creasePatternSvg: string;
  foldedSvgByStep: Record<string, string>; // step id ("" = baseline) -> folded SVG
  steps: (string | null)[]; // ordered step ids incl. null baseline
  constructions: string[]; // named construction names
}

export interface WebviewToHost {
  type: "state";
  view: "cp" | "folded";
  sync: boolean;
  step: string | null; // active step when sync is off
  visibleConstructions: string[];
}

/** The host posts this instead of a render when `beloch fold` fails. */
export interface HostToWebviewDiagnostic {
  type: "diagnostic";
  message: string;
}

/** The host posts this on cursor movement; the webview honors it iff sync is on. */
export interface HostToWebviewCursor {
  type: "cursor";
  step: string | null;
}

/** Parse a `beloch:edges[].span` value into 1-based lines.
 *
 * `Error.span_to_string` (`lib/error.ml`) only encodes the START position as
 * "<file>:<line>:<col>" (e.g. "examples/cube-root.bel:32:1") — no range. This
 * also accepts a "<sl>:<sc>-<el>:<ec>" range form for forward-compatibility /
 * the fixture shape used in tests. File paths may contain ':' (Windows-ish),
 * so both patterns anchor at the end of the string. */
export function parseSpanLine(span: string): { startLine: number; endLine: number } {
  const range = span.match(/:(\d+):(\d+)-(\d+):(\d+)$/);
  if (range) return { startLine: Number(range[1]), endLine: Number(range[3]) };
  const point = span.match(/:(\d+):(\d+)$/);
  if (point) return { startLine: Number(point[1]), endLine: Number(point[1]) };
  return { startLine: 0, endLine: 0 };
}

/** The step id whose creases cover `line` (1-based); the nearest preceding step,
 *  or null before the first step. */
export function stepAtLine(edges: EdgeProv[], line: number): string | null {
  let best: string | null = null;
  let bestLine = -1;
  for (const e of edges) {
    if (e.step == null) continue;
    const { startLine } = parseSpanLine(e.span);
    if (startLine <= line && startLine > bestLine) {
      bestLine = startLine;
      best = e.step;
    }
  }
  return best;
}

/**
 * Which `data-step` attribute values (as fold2svg emits them — the null
 * baseline serializes as `""`, see `render/render-svg/bin/fold2svg.ts`) should
 * be hidden in the crease-pattern view for the given `current` step.
 *
 * `data-step` is GLOBAL provenance: it names the step in which a crease is
 * ULTIMATELY creased in the final pattern, not whether it's present in the
 * currently-viewed frame. So "as of `current`" means hiding every step that
 * comes AFTER `current` in the ordered `steps` array (which includes the
 * null baseline).
 */
export function hiddenStepDataValues(steps: (string | null)[], current: string | null): string[] {
  const currentIndex = steps.indexOf(current);
  if (currentIndex === -1) return []; // unknown step: fail open, hide nothing
  return steps.slice(currentIndex + 1).map((s) => s ?? "");
}
