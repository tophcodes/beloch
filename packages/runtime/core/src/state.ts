import type { FoldScene } from "@beloch/scene";

// What a selection names. A crease is its bundle (ADR-0014), so the identity
// is the crease id and never one of its segments; a paper boundary has no id
// to carry and is named by its edge ("ab").
export type EntityRef =
  | { kind: "crease"; creaseId: string }
  | { kind: "edge"; name: string };

export type View = "cp" | "folded";
export type HiddenMode = "hide" | "dashed" | "depth";

export interface PresentationOptions {
  view: View;
  hidden: HiddenMode;
}

export const DEFAULT_OPTIONS: PresentationOptions = { view: "folded", hidden: "hide" };

export interface State {
  // The document slot. Who fills it is the composition's business: the eval
  // module after a run, a card from the FOLD embedded in its markup, a tour
  // from a program evaluated at build time.
  scene: FoldScene | null;
  // Statement index, 0 to statements.length. 0 is the sheet before any
  // statement ran; n means every statement has been applied.
  step: number;
  options: PresentationOptions;
  // The settled selection. A card lights several named entities at once and
  // the playground lights one; both are policies over this one list, and the
  // core imposes neither.
  selection: EntityRef[];
  // The entity under the pointer. Transient: it survives no step change and
  // it yields to a settled selection.
  hover: EntityRef | null;
}

export const initialState: State = {
  scene: null,
  step: 0,
  options: DEFAULT_OPTIONS,
  selection: [],
  hover: null,
};
