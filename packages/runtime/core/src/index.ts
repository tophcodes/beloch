import { initialState, type State } from "./state";
import type { Event } from "./events";
import { reduce } from "./reduce";
import { renderCommand, type RenderCommand } from "./render";

export * from "./state";
export * from "./events";
export * from "./render";
export { reduce } from "./reduce";

// Called after every dispatch with the new state and what it says to draw.
export type Listener = (state: State, render: RenderCommand | null) => void;

export interface Runtime {
  readonly state: State;
  // Derived on every read, so a renderer never has to ask whether what it
  // holds is still current.
  readonly render: RenderCommand | null;
  dispatch(event: Event): void;
  // Returns the function that stops the subscription.
  subscribe(listener: Listener): () => void;
}

export function createRuntime(): Runtime {
  let state = initialState;
  let listeners: Listener[] = [];
  return {
    get state() {
      return state;
    },
    get render() {
      return renderCommand(state);
    },
    dispatch(event: Event) {
      state = reduce(state, event);
      const render = renderCommand(state);
      // Notify over a copy: a listener may subscribe or unsubscribe while it
      // runs, and the round it was told about is the one that already
      // happened.
      for (const listener of [...listeners]) listener(state, render);
    },
    subscribe(listener: Listener) {
      listeners = [...listeners, listener];
      return () => {
        listeners = listeners.filter((l) => l !== listener);
      };
    },
  };
}
