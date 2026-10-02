// Folded-occlusion preset: step-k geometry with layer occlusion.
// A thin wrapper over renderScene — the drawing lives there.
import type { FoldScene, Vec2 } from "@beloch/scene";
import { orientationAt, pickStep, SceneError } from "@beloch/scene";
import { SvgDoc } from "./svgdoc";
import { renderScene } from "./render-scene";
import type { MarkOverlay } from "./render-scene";
import type { RenderOptions } from "./render-cp";
import { makeLayout, type Layout } from "./layout";
import { turnFrame } from "./isometry";

// `legend` is ignored: the folded view draws no fold kinds, so a legend of
// them would describe lines the drawing does not have.
export interface FoldedOptions extends RenderOptions {
  view?: "top" | "bottom" | undefined; // default "top"
  hidden?: "dashed" | "hide" | "depth" | undefined; // default "hide"
  step?: string | undefined;   // frame index (numeric string); undefined/out-of-range → final state
  markOverlay?: MarkOverlay | undefined; // project these marks onto the step's faces (newest highlighted)
  quiet?: boolean | undefined;        // see SceneOptions.quiet
  layout?: Layout | undefined;        // see SceneOptions.layout
  // true: turn the drawing by the `@orient` in force at the step
  // (orientationAt). A turned drawing takes its frame from the turned step
  // alone: a square around its bounding box, so it sits centered and fills
  // the canvas. Absent, the drawing keeps the table's axes and the scene's
  // frame, which a view that overlays it on another drawing of the scene needs.
  orient?: boolean | undefined;
}

// The frame of a square centered on the bounding box of the vertices, with
// the box's longer side as its span.
function centeredLayout(vertices: Vec2[]): Layout {
  const xs = vertices.map((v) => v[0]), ys = vertices.map((v) => v[1]);
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2, cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  const half = Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)) / 2;
  return makeLayout([[cx - half, cy - half], [cx + half, cy + half]]);
}

export function renderFolded(scene: FoldScene, opts: FoldedOptions = {}): SvgDoc {
  const step = pickStep(scene, opts.step);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  const turn = opts.orient ? orientationAt(scene, step.index) : 0;
  const layout = opts.layout ?? (turn === 0 ? undefined : centeredLayout(turnFrame(step.frame, turn).frame.vertices));
  return renderScene(scene, {
    isometry: { kind: "step", index: step.index, turn },
    texture: {
      // The frame IS the state at this step: every crease in it was scored
      // at or before this step, so a statement filter would remove nothing.
      upToStatement: "all",
      creases: true,
      marks: false,
      points: true,
      lines: true,
      faces: "filled",
    },
    view: opts.view,
    hidden: opts.hidden,
    title: opts.title,
    labels: opts.labels,
    annotate: opts.annotate,
    dots: opts.dots,
    quiet: opts.quiet,
    highlight: opts.highlight,
    theme: opts.theme,
    markOverlay: opts.markOverlay,
    layout,
  });
}
