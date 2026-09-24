import { initialState, type State } from "./state";
import type { Event } from "./events";
import { reduce } from "./reduce";

export * from "./state";
export * from "./events";
export * from "./render";
export { reduce, sameEntity, toggleEntity } from "./reduce";

// Called after every dispatch. What the new state says to draw is a separate
// question, asked with renderCommand and the caller's own view and hidden
// mode.
export type Listener = (state: State) => void;

export interface Runtime {
  readonly state: State;
  dispatch(event: Event): void;
  // Returns the function that stops the subscription.
  subscribe(listener: Listener): () => void;
}

// A runtime with no document and no modules. Modules compose onto it by
// dispatching and subscribing; the core imports none of them.
export function createRuntime(): Runtime {
  let state = initialState;
  let listeners: Listener[] = [];
  return {
    get state() {
      return state;
    },
    dispatch(event: Event) {
      const next = reduce(state, event);
      // An event that changed nothing is not news. Telling listeners anyway
      // would redraw on every mouse event a resting pointer sends.
      if (next === state) return;
      state = next;
      // Notify over a copy: a listener may subscribe or unsubscribe while it
      // runs, and the round it was told about is the one that already
      // happened.
      for (const listener of [...listeners]) listener(state);
    },
    subscribe(listener: Listener) {
      listeners = [...listeners, listener];
      return () => {
        listeners = listeners.filter((l) => l !== listener);
      };
    },
  };
}
