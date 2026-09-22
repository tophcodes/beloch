import type { FoldScene } from "@beloch/scene";
import type { EntityRef, HiddenMode, View } from "./state";

// Events are the reader's intentions, never assignments into the state. A
// consumer dispatches what happened; the core decides what that means.
export type Event =
  | { type: "document/set"; scene: FoldScene }
  // Statement index. Out-of-range values are clamped rather than rejected, so
  // a caller may hand over a remembered step from a shorter program.
  | { type: "step/to"; index: number }
  // The selection the reader arrived at. Whoever resolved several coincident
  // entities into a choice dispatches the result; the core is handed the
  // answer (see @beloch/runtime-pick).
  | { type: "selection/set"; entities: EntityRef[] }
  | { type: "hover/set"; entity: EntityRef | null }
  // Presentation options outlive a document: the reader chose them, and a
  // fresh run is not a reason to put them back.
  | { type: "options/view"; view: View }
  | { type: "options/hidden"; mode: HiddenMode };
