import type { FoldScene } from "@beloch/scene";

// What a selection names. A crease is its bundle (ADR-0014), so the identity
// is the crease id and never one of its segments; a paper boundary has no id
// to carry and is named by its edge ("ab"). A face and a vertex are the two
// other things a reader can point at, carried by the index the document gives
// them, with a vertex's name beside it where the program gave it one.
export type EntityRef =
  | { kind: "crease"; creaseId: string }
  | { kind: "edge"; name: string }
  | { kind: "face"; index: string }
  | { kind: "vertex"; index: number; name: string | null };

// Which of the two pictures of a state to draw: the flat sheet with its
// creases, or the folded result.
export type View = "cp" | "folded";

// What becomes of a segment lying under a higher layer: dropped, drawn
// dashed, or drawn with an opacity that falls off by how deep it is buried.
export type HiddenMode = "hide" | "dashed" | "depth";

// How a caller wants the current state drawn. These are arguments to a
// drawing request rather than state: the only reader of either is a renderer,
// and the <Beloch> card draws both views of one document side by side, so a
// single state has to answer two requests that differ here.
export interface RenderOptions {
  view: View;
  hidden: HiddenMode;
}

export interface State {
  // The document slot. Who fills it is the composition's business: the eval
  // module after a run, a card from the FOLD embedded in its markup, a tour
  // from a program evaluated at build time.
  scene: FoldScene | null;
  // Statement index, 0 to statements.length. 0 is the sheet before any
  // statement ran; n means every statement has been applied.
  step: number;
  // The settled selection. A card lights several named entities at once and
  // the playground lights one; both are policies over this one list, and the
  // core imposes neither.
  selection: EntityRef[];
  // The entity under the pointer. Transient: it yields to a settled
  // selection.
  hover: EntityRef | null;
}

// Before any document arrives. A consumer may render this: renderCommand
// answers null, which is the honest drawing of nothing.
export const initialState: State = {
  scene: null,
  step: 0,
  selection: [],
  hover: null,
};
