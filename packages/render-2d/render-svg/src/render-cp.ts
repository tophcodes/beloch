// Crease-pattern preset: flat geometry, all creases, marks + construction
// overlays. A thin wrapper over renderScene — the drawing lives there.
import type { FoldScene } from "@beloch/scene";
import { SvgDoc } from "./svgdoc";
import { Theme } from "./theme";
import { renderScene } from "./render-scene";

export interface RenderOptions {
  title?: string;
  labels?: string[]; // ["--v", ".e"]; undefined = none
  highlight?: string[]; // entities to emphasise: ["--v", ".e", "#[.p]"]
  theme?: Partial<Theme>;
  legend?: boolean; // default false
}

export function renderCP(scene: FoldScene, opts: RenderOptions = {}): SvgDoc {
  return renderScene(scene, {
    isometry: { kind: "flat" },
    texture: {
      upToStep: "all",
      creases: true,
      marks: true,
      points: true,
      lines: true,
      faces: "outline",
    },
    title: opts.title,
    labels: opts.labels,
    highlight: opts.highlight,
    legend: opts.legend,
    theme: opts.theme,
  });
}
