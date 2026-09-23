import type { Mark } from "@beloch/scene";
import type { EntityRef, HiddenMode, RenderOptions, State } from "./state";

// What to draw of the current document, as plain data. The core decides it,
// a renderer executes it, and a headless test reads it without a view
// existing. It names no colours and no geometry: a theme is the renderer's,
// and the frames are in the scene the state already holds.
// Carried by every shape of command: the entities the drawing should light,
// already resolved from the selection and the hover.
export interface RenderCommon {
  // The construction lines the program has named by this step, by name. A
  // line the drawing has no other way of showing: one that never becomes a
  // crease is geometry the program built and the paper does not carry.
  // Whether a name is already drawn as a crease is the renderer's to see, so
  // this list is dated by the step and nothing more.
  constructions: string[];
  highlight: EntityRef[];
  // Whether the highlight is the reader's settled answer rather than the
  // pointer passing over a line. A renderer may show a settled entity more
  // than the drawing holds, the buried rest of a crease for one; under the
  // pointer that would put marks under the cursor on the way past every
  // crease.
  settled: boolean;
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

// What to draw of `state`, as `options` asks for it. Null when there is no
// document yet. Pure and cheap, so a consumer showing two views of one
// document calls it twice rather than holding two runtimes.
export function renderCommand(state: State, options: RenderOptions): RenderCommand | null {
  const { scene, step } = state;
  if (!scene) return null;
  // A settled selection outranks the pointer: once the reader has picked a
  // line, moving the cursor away must not take the answer with it.
  const settled = state.selection.length > 0;
  const highlight: EntityRef[] = settled ? state.selection : state.hover ? [state.hover] : [];
  if (scene.statements.length === 0) {
    // No timeline, so every construction the program named is in the drawing.
    return { kind: "cp-only", constructions: scene.namedLines.map((l) => l.name), highlight, settled };
  }
  // Step 0 is the sheet before any statement ran, so it carries no
  // statement's creases and no marks.
  const stmt = step === 0 ? null : scene.statements[step - 1] ?? null;
  const marks = stmt ? stmt.keptMarks : [];
  const newestCreaseId = marks.at(-1)?.creaseId ?? null;
  // A named line is dated by the frame it was bound against, which is the
  // frame the statement in view folds against.
  const frame = stmt ? stmt.frameIndex : 0;
  const constructions = scene.namedLines.filter((l) => l.step <= frame).map((l) => l.name);
  if (options.view === "cp") {
    return {
      kind: "flat",
      upToStatement: step - 1,
      marks,
      newestCreaseId,
      constructions,
      highlight,
      settled,
    };
  }
  return {
    kind: "folded",
    frame,
    hidden: options.hidden,
    marks,
    newestCreaseId,
    constructions,
    highlight,
    settled,
  };
}
