// Crease-pattern preset: flat geometry, all creases, marks + construction
// overlays. A thin wrapper over renderScene — the drawing lives there.
import type { FoldScene } from "@beloch/scene";
import { SvgDoc } from "./svgdoc";
import { Theme } from "./theme";
import { renderScene } from "./render-scene";

export interface RenderOptions {
  title?: string | undefined;
  labels?: string[] | undefined; // ["--v", ".e"]; undefined = none
  annotate?: string[] | undefined; // whose names the drawing writes out; undefined = every name it carries
  highlight?: string[] | undefined; // entities to emphasise: ["--v", ".e", "#[.p]"]
  theme?: Partial<Theme> | undefined;
  legend?: boolean | undefined; // default false
}

export function renderCP(scene: FoldScene, opts: RenderOptions = {}): SvgDoc {
  return renderScene(scene, {
    isometry: { kind: "flat" },
    texture: {
      upToStatement: "all",
      creases: true,
      marks: true,
      points: true,
      lines: true,
      faces: "outline",
    },
    title: opts.title,
    labels: opts.labels,
    annotate: opts.annotate,
    highlight: opts.highlight,
    legend: opts.legend,
    theme: opts.theme,
  });
}
