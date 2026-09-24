// Folded-occlusion preset: step-k geometry with layer occlusion.
// A thin wrapper over renderScene — the drawing lives there.
import type { FoldScene } from "@beloch/scene";
import { pickStep, SceneError } from "@beloch/scene";
import { SvgDoc } from "./svgdoc";
import { renderScene } from "./render-scene";
import type { MarkOverlay } from "./render-scene";
import type { RenderOptions } from "./render-cp";

export interface FoldedOptions extends RenderOptions {
  view?: "top" | "bottom" | undefined; // default "top"
  hidden?: "dashed" | "hide" | "depth" | undefined; // default "hide"
  step?: string | undefined;   // frame index (numeric string); undefined/out-of-range → final state
  markOverlay?: MarkOverlay | undefined; // project these marks onto the step's faces (newest highlighted)
}

export function renderFolded(scene: FoldScene, opts: FoldedOptions = {}): SvgDoc {
  const step = pickStep(scene, opts.step);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  return renderScene(scene, {
    isometry: { kind: "step", index: step.index },
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
    highlight: opts.highlight,
    legend: opts.legend,
    theme: opts.theme,
    markOverlay: opts.markOverlay,
  });
}
