import type { Mark } from "@beloch/scene";
import type { EntityRef, HiddenMode, State } from "./state";

// What to draw of the current document, as plain data. The core decides it,
// a renderer executes it, and a headless test reads it without a view
// existing. It names no colours and no geometry: a theme is the renderer's,
// and the frames are in the scene the state already holds.
export interface RenderCommon {
  highlight: EntityRef[];
}

export type RenderCommand =
  // A document with no fold and no mark statement has no timeline. Its one
  // drawing is the crease pattern, whichever view is selected.
  | (RenderCommon & { kind: "cp-only" })
  // The flat sheet carrying the creases scored up to `upToStatement`, plus
  // the marks still dangling at it. -1 is the sheet before any statement.
  | (RenderCommon & {
      kind: "flat";
      upToStatement: number;
      marks: Mark[];
      newestCreaseId: number | null;
    })
  // The folded state at one frame of the scene. Frame 0 is the flat sheet.
  | (RenderCommon & {
      kind: "folded";
      frame: number;
      hidden: HiddenMode;
      marks: Mark[];
      newestCreaseId: number | null;
    });

export function renderCommand(state: State): RenderCommand | null {
  const { scene, step, options } = state;
  if (!scene) return null;
  // A settled selection outranks the pointer: once the reader has picked a
  // line, moving the cursor away must not take the answer with it.
  const highlight: EntityRef[] =
    state.selection.length > 0 ? state.selection : state.hover ? [state.hover] : [];
  if (scene.statements.length === 0) return { kind: "cp-only", highlight };
  // Step 0 is the sheet before any statement ran, so it carries no
  // statement's creases and no marks.
  const stmt = step === 0 ? null : scene.statements[step - 1] ?? null;
  const marks = stmt ? stmt.keptMarks : [];
  const newestCreaseId = marks.at(-1)?.creaseId ?? null;
  if (options.view === "cp") {
    return { kind: "flat", upToStatement: step - 1, marks, newestCreaseId, highlight };
  }
  return {
    kind: "folded",
    frame: stmt ? stmt.frameIndex : 0,
    hidden: options.hidden,
    marks,
    newestCreaseId,
    highlight,
  };
}
