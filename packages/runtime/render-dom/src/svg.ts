// A render command as SVG markup. The command says what to draw, the theme
// says in which colours, and the scene carries the geometry both of them talk
// about. Pure: a caller that wants markup without a document to put it in
// stops here (the static build of a card does exactly that).
import type { FoldScene, Frame, Mark } from "@beloch/scene";
import { renderCP, renderFolded, renderScene, type Theme } from "@beloch/render-svg";
import type { RenderCommand } from "@beloch/runtime";

// The mark overlay leaves `newestCreaseId` out rather than passing it as
// undefined, so the option stays absent where there is no newest mark.
const overlay = (marks: Mark[], newestCreaseId: number | null) =>
  newestCreaseId === null ? { marks } : { marks, newestCreaseId };

// The construction lines to draw over this picture: the ones the command
// names, minus those the picture already carries as a crease. A named line
// that has been folded is in the drawing as the crease it became, and drawing
// it twice would read as an emphasis nobody asked for.
//
// `upToStatement` dates the creases of a flat sheet, which carries every
// crease of the final state and draws only the ones scored by this statement.
// A folded frame is the state at its step, so its own edges answer directly.
function constructionLabels(
  command: { constructions: string[] },
  frame: Frame,
  upToStatement: number | null,
): string[] {
  const creased = new Set<string>();
  for (const prov of frame.edgesProvenance) {
    if (!prov?.name) continue;
    if (upToStatement !== null && prov.statement !== null && prov.statement > upToStatement) continue;
    creased.add(prov.name);
  }
  return command.constructions.filter((name) => !creased.has(name)).map((name) => `--${name}`);
}

export function commandToSvg(
  scene: FoldScene,
  command: RenderCommand,
  theme: Partial<Theme>,
): string {
  switch (command.kind) {
    case "cp-only":
      return renderCP(scene, {
        theme,
        labels: constructionLabels(command, scene.cp, null),
      }).toString();
    case "flat":
      // The flat sheet carrying the creases scored up to this statement, plus
      // the marks still dangling at it, so a scored line first shows as a mark
      // and turns into a crease at the statement that folds it.
      return renderScene(scene, {
        theme,
        isometry: { kind: "flat" },
        texture: {
          upToStatement: command.upToStatement,
          creases: true,
          marks: true,
          points: true,
          lines: true,
          faces: "outline",
        },
        labels: constructionLabels(command, scene.cp, command.upToStatement),
        markOverlay: overlay(command.marks, command.newestCreaseId),
      }).toString();
    case "folded":
      return renderFolded(scene, {
        theme,
        step: String(command.frame),
        hidden: command.hidden,
        labels: constructionLabels(
          command,
          scene.steps.find((s) => s.index === command.frame)?.frame ?? scene.cp,
          null,
        ),
        // The folded drawing has no marks of its own: the overlay is the only
        // way a dangling mark reaches it, and an empty one draws nothing.
        markOverlay: overlay(command.marks, command.newestCreaseId),
      }).toString();
  }
}
