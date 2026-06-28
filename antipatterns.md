# Dead ends & antipatterns

Approaches tried and rejected, with *why*. The most valuable and most neglected
research artifact: when you're stuck in eight months thinking "what if we just…",
check here first. Raw material for the paper's design-discussion section. Append
ruthlessly — a dead end recorded is a dead end you don't walk twice.

(For forward-looking decisions, see `decisions/`. This file is for what *didn't*
work, including things inherited as warnings from the 2018 attempt.)

## Inherited from the 2018 design (OrigamiDL)

- **Layer number = fold depth + 1 (the bookmark heuristic).** Won't hold up.
  Real origami layer order is a *partial order* on faces determined by the folded
  state, not a tree. This is what FOLD's `faceOrders` uses and what the flat-
  foldability literature uses. Tagging vertices with a layer number also breaks
  for fold-line vertices that sit on neither layer. → A proper folded-state model
  with face ordering is required; see the open layer problem.
- **Region ≠ layer (conflation).** A *region* is an area of paper addressed by a
  predicate; a *layer* is a z-ordering of overlapping areas. The 2018 spec used
  `#region` to do both. We likely need both concepts, kept distinct.
- **Accumulate features until expressive, then formalize.** This is how the 2018
  design hit mutual inconsistency at the layer problem and stalled. Replaced by
  the minimal-formal-core approach — see decisions/0003-restart-from-minimal-core.md.
- **"There is a unique fold" (from the axiom phrasing).** False in general:
  axiom 5 has up to 2 solutions, axiom 6 up to 3. Disambiguation must be
  first-class and ergonomic, not an afterthought.

## Rejected approaches (this attempt)

_(none yet — append as they happen)_
