// What a hit report means, decided before any of it reaches the core.
//
// The view is the only side that knows what was drawn where, so it does the
// hit test and hands over the result. Turning that list into an answer is the
// same decision in every consumer, which is why it lives here rather than in
// each one's pointer handler.
import type { EntityRef } from "@beloch/runtime";

// Whether the reader is pointing at the drawing or has clicked it. A hover
// offers, a settle decides; the candidates a coincidence produces are the
// same either way, which is what lets a hover preview the choice a click
// would open.
export type PickIntent = "hover" | "settle";

export type PickOutcome =
  // The drawing shows nothing here. Not the same as a miss: a segment buried
  // under a higher layer is honestly absent from a drawing that does not draw
  // it (see pick-visibility in the view).
  | { kind: "none" }
  | { kind: "one"; entity: EntityRef }
  // Several entities share this pixel, so the reader has to say which.
  | { kind: "several"; candidates: EntityRef[] };

// The order the report came in is the order the choice offers, because the
// view ranked it by what it knows about the drawing (layer order, for one).
export function decide(entities: readonly EntityRef[]): PickOutcome {
  if (entities.length === 0) return { kind: "none" };
  if (entities.length === 1) return { kind: "one", entity: entities[0]! };
  return { kind: "several", candidates: [...entities] };
}
