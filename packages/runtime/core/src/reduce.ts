import type { Event } from "./events";
import type { State } from "./state";

// Statement index range: 0 is the sheet before any statement ran, n means
// every statement has been applied.
const clampStep = (index: number, statements: number): number =>
  Math.max(0, Math.min(index, statements));

// The only writer of state. Pure, so a test drives a whole interaction
// sequence and reads the result without a view existing.
export function reduce(state: State, event: Event): State {
  switch (event.type) {
    case "document/set":
      // A new document invalidates what was said about the old one: the
      // entities a selection named may be gone, and the step range changed.
      return {
        ...state,
        scene: event.scene,
        step: event.scene.statements.length,
        selection: [],
        hover: null,
      };
    case "step/to": {
      // Without a document there is no range to clamp against, so the step
      // has nothing to mean yet.
      if (!state.scene) return state;
      return { ...state, step: clampStep(event.index, state.scene.statements.length) };
    }
    case "selection/set":
      return { ...state, selection: event.entities };
    case "hover/set":
      return { ...state, hover: event.entity };
    case "options/view":
      return { ...state, options: { ...state.options, view: event.view } };
    case "options/hidden":
      return { ...state, options: { ...state.options, hidden: event.mode } };
    default:
      // An event this version does not know leaves the state as it was. The
      // union makes that unreachable in typed code; a composition loading a
      // newer module against an older core would otherwise blank the state.
      return state;
  }
}
