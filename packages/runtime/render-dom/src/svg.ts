// A render command as SVG markup. The command says what to draw, the theme
// says in which colours, and the scene carries the geometry both of them talk
// about. Pure: a caller that wants markup without a document to put it in
// stops here (the static build of a card does exactly that).
import type { FoldScene, Frame, Mark } from "@beloch/scene";
import { renderCP, renderFolded, renderScene, type Theme } from "@beloch/render-svg";
import type { EntityRef, RenderCommand } from "@beloch/runtime";

// The mark overlay leaves `newestCreaseId` out rather than passing it as
// undefined, so the option stays absent where there is no newest mark.
const overlay = (marks: Mark[], newestCreaseId: number | null) =>
  newestCreaseId === null ? { marks } : { marks, newestCreaseId };

// The construction lines to draw over this picture: the ones the reader
// settled on, minus those the picture already carries as a crease. A named
// line that has been folded is in the drawing as the crease it became, and
// drawing it twice would read as an emphasis nobody asked for.
//
// A construction the reader has not picked is left out. It is geometry the
// program built and the paper does not carry, so every one of them on screen
// at once is a second drawing over the first; the one that was asked about is
// the one worth showing.
//
// `upToStatement` dates the creases of a flat sheet, which carries every
// crease of the final state and draws only the ones scored by this statement.
// A folded frame is the state at its step, so its own edges answer directly.
function constructionLabels(
  scene: FoldScene,
  command: RenderCommand,
  frame: Frame,
  upToStatement: number | null,
): string[] {
  const creased = new Set<string>();
  for (const prov of frame.edgesProvenance) {
    if (!prov?.name) continue;
    if (upToStatement !== null && prov.statement !== null && prov.statement > upToStatement) continue;
    creased.add(prov.name);
  }
  const picked = new Set(labelledNames(scene, command));
  return command.constructions
    .filter((name) => !creased.has(name) && picked.has(`--${name}`))
    .map((name) => `--${name}`);
}

// The names the drawing writes out: those of the settled selection, and no
// others. A drawing that labels everything it knows buries the one name the
// reader asked about under the rest, and the reader who asked for none wanted
// the paper. The pointer is deliberately left out: a hover changes several
// times a second, and the labels would flicker with it.
const nameOf = (scene: FoldScene, ref: EntityRef): string | null => {
  switch (ref.kind) {
    case "crease": {
      // A crease the program never named is asked for by its id; the drawing
      // writes out the line that scored it (see `sourceMark`).
      const name = scene.inspect?.creases[ref.creaseId]?.name ?? null;
      return name === null ? `#${ref.creaseId}` : `--${name}`;
    }
    case "construction":
      return `--${ref.name}`;
    case "edge":
      return `--${ref.name}`;
    case "vertex":
      return ref.name === null ? null : `.${ref.name}`;
    default:
      return null;
  }
};

export function labelledNames(scene: FoldScene, command: RenderCommand): string[] {
  if (!command.settled) return [];
  return command.highlight
    .map((ref) => nameOf(scene, ref))
    .filter((name): name is string => name !== null);
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
        labels: constructionLabels(scene, command, scene.cp, null),
        annotate: labelledNames(scene, command),
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
        labels: constructionLabels(scene, command, scene.cp, command.upToStatement),
        annotate: labelledNames(scene, command),
        markOverlay: overlay(command.marks, command.newestCreaseId),
      }).toString();
    case "folded":
      return renderFolded(scene, {
        theme,
        step: String(command.frame),
        hidden: command.hidden,
        labels: constructionLabels(
          scene,
          command,
          scene.steps.find((s) => s.index === command.frame)?.frame ?? scene.cp,
          null,
        ),
        annotate: labelledNames(scene, command),
        // The folded drawing has no marks of its own: the overlay is the only
        // way a dangling mark reaches it, and an empty one draws nothing.
        markOverlay: overlay(command.marks, command.newestCreaseId),
      }).toString();
  }
}
