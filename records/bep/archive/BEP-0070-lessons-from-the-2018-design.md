---
id: BEP-0070
title: "Lessons from the 2018 design (OrigamiDL)"
status: abandoned
---

# BEP-0070: Lessons from the 2018 design (OrigamiDL)

Beloch restarts a language designed in 2018, OrigamiDL. Its specification
stalled at the layer problem. This record keeps the four choices of that
design that Beloch does not repeat. Nobody proposed them again in this
attempt; they are recorded as the proposal the 2018 design made.

## Proposal

<!-- vale Prose.HedgingAdverb = NO -->

- **Layer number = fold depth + 1 (the bookmark heuristic).**
- **Region and layer as one concept.** The 2018 spec used `#region` both
  for an area of paper addressed by a predicate and for a z-ordering of
  overlapping areas.
- **Accumulate features until expressive, then formalize.**
- **"The fold is unique" (from the axiom phrasing).**

## Why abandoned

- **Layer number.** Won't hold up.
  Real origami layer order is a *partial order* on faces determined by the folded
  state, not a tree. This is what FOLD's `faceOrders` uses and what the flat-
  foldability literature uses. Tagging vertices with a layer number also breaks
  for fold-line vertices that lie on neither layer. → A proper folded-state model
  with face ordering is required; see the open layer problem. Fisher reached the
  same conclusion in 1994: "cyclic layering relationships can occur in
  origami … so it would not be possible to simply give each face some kind
  of layer number" [fisher1994, §6.1].
- **Region and layer.** A *region* is an area of paper addressed by a
  predicate; a *layer* is a z-ordering of overlapping areas. We likely need
  both concepts, kept distinct.
- **Accumulate, then formalize.** This is how the 2018
  design hit mutual inconsistency at the layer problem and stalled. Replaced by
  the minimal-formal-core approach (see [[ADR-0003]]).
- **The fold is unique.** False in general:
  axioms 5 and 6 have up to 2 solutions, axiom 7 up to 3. Disambiguation must be
  first-class and ergonomic, not an afterthought.

<!-- vale Prose.HedgingAdverb = YES -->
