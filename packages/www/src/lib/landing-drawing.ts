/** How the landing draws paper: the folding-diagram line styles in the
 *  crease colors, no backdrop, and the drawing cut to the paper's square, so
 *  the band behind it shows through around the paper. */
import { orientationAt, type FoldScene } from "@beloch/scene";
import {
  makeLayout, PAD, SZ, turnFrame, WEB_THEME, yrLineStyle,
  type Layout, type LineStyleFn, type SvgDoc, type Theme,
} from "@beloch/render-svg";
import { evalBelToFold } from "./eval-bel";

/** Valleys dashed and mountains dash-dotted, as a folding diagram draws
 *  them, each in its crease color. */
export const coloredYrLineStyle: LineStyleFn = (assignment, theme) => {
  const style = yrLineStyle(assignment, theme);
  if (assignment === "M") return { ...style, stroke: theme.mountain };
  if (assignment === "V") return { ...style, stroke: theme.valley };
  return style;
};

export const LANDING_THEME: Partial<Theme> = {
  ...WEB_THEME,
  background: "none",
  lineStyle: coloredYrLineStyle,
};

// Half the boundary's stroke width, so the cut keeps the whole outline.
const EDGE = 1.5;

/** The drawing cut to the square the renderer lays the paper in, widened
 *  by `margin` drawing units on every side so a dot on the paper's edge stays
 *  whole. Names and dots beyond that fall away with the rest of the margin. */
export function paperOnly(doc: SvgDoc, margin = EDGE): string {
  const side = SZ + 2 * margin;
  Object.assign(doc.root.attrs, {
    width: side,
    height: side,
    viewBox: `${PAD - margin} ${PAD - margin} ${side} ${side}`,
  });
  return doc.toString();
}

/** The margin a drawing with marked points keeps, so a point on the paper's
 *  edge stays whole at the radius `.l-dots` in landing.css gives it. */
export const DOT_MARGIN = 16;

/** A frame that fits the folded state of one step, the last by default:
 *  the square around its outline, turned by the `@orient` in force there,
 *  so the model fills the drawing instead of the sheet's frame. */
export function fitStep(scene: FoldScene, index?: number): Layout {
  const step = (index === undefined ? undefined : scene.steps.find((s) => s.index === index)) ?? scene.steps.at(-1)!;
  const turn = orientationAt(scene, step.index);
  const vs = turn === 0 ? step.frame.vertices : turnFrame(step.frame, turn).frame.vertices;
  const xs = vs.map((v) => v[0]), ys = vs.map((v) => v[1]);
  const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
  const h = Math.max(x1 - x0, y1 - y0) / 2, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  return makeLayout([[cx - h, cy - h], [cx + h, cy + h]]);
}

// One evaluation per program text and process: the dev server renders the
// page on every request, and the frog alone takes seconds.
const folds = new Map<string, unknown>();

export function cachedFold(source: string): unknown {
  let fold = folds.get(source);
  if (fold === undefined) {
    fold = evalBelToFold(source);
    folds.set(source, fold);
  }
  return fold;
}
