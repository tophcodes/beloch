// Folded-occlusion preset: step-k geometry, creases up to k, layer occlusion.
// A thin wrapper over renderScene — the drawing lives there.
import type { FoldScene, Mark } from "@beloch/scene";
import { pickStep, SceneError } from "@beloch/scene";
import { SvgDoc } from "./svgdoc";
import { renderScene } from "./render-scene";
import type { RenderOptions } from "./render-cp";

export interface FoldedOptions extends RenderOptions {
  view?: "top" | "bottom";     // default "top"
  hidden?: "dashed" | "hide";  // default "hide"
  step?: string;               // beloch:step label; undefined/unmatched → final state
  markOverlay?: Mark;          // project this one mark onto the step's faces
}

export function renderFolded(scene: FoldScene, opts: FoldedOptions = {}): SvgDoc {
  const step = pickStep(scene, opts.step);
  if (!step) throw new SceneError("no foldedForm frames in scene");
  return renderScene(scene, {
    isometry: { kind: "step", index: step.index },
    texture: {
      upToStep: step.index,
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
    legend: opts.legend,
    theme: opts.theme,
    markOverlay: opts.markOverlay,
  });
}
