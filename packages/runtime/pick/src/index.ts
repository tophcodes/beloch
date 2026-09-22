// Coincident lines: the candidate list and the chooser.
//
// A crease folded onto another crease, or onto a paper edge, shares its
// coordinates with it, and one line is drawn for all of them. Which one the
// reader meant cannot be answered from the pixel, so they are asked. That
// affordance is the playground's; the card and the tour never open it and
// compose without this module.
//
// DOM-free like the core: the panel, the rows and the highlight are the
// view's, and this module holds only what is being offered.
import type { EntityRef, Runtime } from "@beloch/runtime";
import { decide, type PickIntent, type PickOutcome } from "./decide";

export * from "./decide";

export interface PickState {
  // The entities a coincidence offered, in the order the view reported them.
  candidates: EntityRef[];
  // Whether the reader has been asked. A hover fills the candidate list for a
  // preview without asking; a click opens the choice and waits.
  open: boolean;
}

export const initialPickState: PickState = { candidates: [], open: false };

export interface Pick {
  readonly state: PickState;
  // What the view saw under the pointer. Returns what it means, so the caller
  // can light the candidates or anchor its panel; a settled answer is
  // dispatched into the core from here.
  report(entities: readonly EntityRef[], intent: PickIntent): PickOutcome;
  // The reader picked the candidate at `index`, which is settled and returned
  // so the caller can say something about it. An index nothing is offered at
  // settles nothing, because the list came out of the view's markup.
  choose(index: number): EntityRef | null;
  // Take the question back without answering it. The selection is the core's
  // and stays as it was.
  close(): void;
}

export function createPick(runtime: Runtime): Pick {
  let state = initialPickState;
  let scene = runtime.state.scene;
  // A different document is a different set of entities, so what was offered
  // about the old one no longer names anything.
  runtime.subscribe((next) => {
    if (next.scene === scene) return;
    scene = next.scene;
    state = initialPickState;
  });
  return {
    get state() {
      return state;
    },
    report(entities, intent) {
      const outcome = decide(entities);
      // A report with nothing in it is no statement about anything: the reader
      // pointed at paper, an open choice stands and so does the selection.
      if (outcome.kind === "none") return outcome;
      state =
        outcome.kind === "several"
          ? { candidates: outcome.candidates, open: intent === "settle" }
          : initialPickState;
      if (intent === "settle") {
        // A coincidence clears the selection: the reader has asked about this
        // spot and has not answered yet, so the old answer was about another.
        runtime.dispatch({
          type: "selection/set",
          entities: outcome.kind === "one" ? [outcome.entity] : [],
        });
      }
      return outcome;
    },
    choose(index) {
      const entity = state.candidates[index];
      if (!entity) return null;
      state = initialPickState;
      runtime.dispatch({ type: "selection/set", entities: [entity] });
      return entity;
    },
    close() {
      state = initialPickState;
    },
  };
}
