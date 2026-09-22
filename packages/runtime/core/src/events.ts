import type { FoldScene } from "@beloch/scene";
import type { EntityRef } from "./state";

// Events are the reader's intentions, never assignments into the state. A
// consumer dispatches what happened; the core decides what that means.
//
// How the state is drawn is not among them: view and hidden mode are
// arguments to renderCommand, because they change no shared state and two
// drawings of one document may differ in both.
export type Event =
  // Null empties the slot: a consumer whose source changed has no document
  // until the next run answers, and what was said about the old one no longer
  // holds.
  | { type: "document/set"; scene: FoldScene | null }
  // Statement index. Out-of-range values are clamped rather than rejected, so
  // a caller may hand over a remembered step from a shorter program.
  | { type: "step/to"; index: number }
  // The selection the reader arrived at. Whoever resolved several coincident
  // entities into a choice dispatches the result; the core is handed the
  // answer (see @beloch/runtime-pick).
  | { type: "selection/set"; entities: EntityRef[] }
  | { type: "hover/set"; entity: EntityRef | null };
