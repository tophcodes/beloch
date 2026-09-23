import type { Event } from "./events";
import type { EntityRef, State } from "./state";

// Step range: 0 is the sheet before any statement ran, n means every write has
// been applied. The stepper walks the writes (ADR 0026), so a binding statement
// is no stop of its own.
const clampStep = (index: number, writes: number): number =>
  Math.max(0, Math.min(index, writes));

// Whether two references name the same thing. A consumer holding a list of
// them needs this to answer "is it already in", which is what a reader toggling
// one value at a time asks on every click.
export const sameEntity = (a: EntityRef | null, b: EntityRef | null): boolean => {
  if (a === null || b === null) return a === b;
  if (a.kind !== b.kind) return false;
  if (a.kind === "crease" && b.kind === "crease") return a.creaseId === b.creaseId;
  if (a.kind === "edge" && b.kind === "edge") return a.name === b.name;
  if (a.kind === "face" && b.kind === "face") return a.index === b.index;
  if (a.kind === "construction" && b.kind === "construction") return a.name === b.name;
  // A vertex is the same vertex at the same index; the name rides along for a
  // reader and adds nothing to the identity.
  if (a.kind === "vertex" && b.kind === "vertex") return a.index === b.index;
  return false;
};

// Order carries meaning here: a consumer that lights several entities decides
// what the list means, and two orders are two answers.
const sameEntities = (a: EntityRef[], b: EntityRef[]): boolean =>
  a.length === b.length && a.every((e, i) => sameEntity(e, b[i]!));

// The only writer of state. Pure, so a test drives a whole interaction
// sequence and reads the result without a view existing.
//
// An event that changes nothing returns the state object it was given. That
// is what lets a renderer answer "did anything move" with `===`: a pointer
// resting on one crease sends a hover per mouse event, and redrawing on each
// of them would restart a running animation.
export function reduce(state: State, event: Event): State {
  switch (event.type) {
    case "document/set": {
      if (state.scene === event.scene) return state;
      // A different document invalidates what was said about the old one: the
      // entities a selection named may be gone, and the step range changed.
      return {
        ...state,
        scene: event.scene,
        step: event.scene === null ? 0 : event.scene.writes.length,
        selection: [],
        hover: null,
      };
    }
    case "step/to": {
      // Without a document there is no range to clamp against, so the step
      // has nothing to mean yet.
      if (!state.scene) return state;
      const step = clampStep(event.index, state.scene.writes.length);
      if (step === state.step) return state;
      return { ...state, step };
    }
    case "selection/set":
      if (sameEntities(state.selection, event.entities)) return state;
      return { ...state, selection: event.entities };
    case "hover/set":
      if (sameEntity(state.hover, event.entity)) return state;
      return { ...state, hover: event.entity };
    default:
      // An event this version does not know leaves the state as it was. The
      // union makes that unreachable in typed code; a composition loading a
      // newer module against an older core would otherwise blank the state.
      return state;
  }
}
