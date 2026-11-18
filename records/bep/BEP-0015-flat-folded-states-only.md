---
id: BEP-0015
title: "Flat folded states only (2D isometries); 3D is a goal, not a carried feature"
date: 2026-07-03
status: accepted
---

# BEP-0015: Flat folded states only (2D isometries); 3D is a goal, not a carried feature

The architecture part of this decision is [[ADR-0063]].

## Context
The current model therefore produces **flat folded states**: every fold is a ±180°
reflection, the whole sheet stays in the table plane, and the only third dimension
is stacking order (`faceOrders`). This is the **all-layers simple-fold** model, the
most restricted class in Demaine and O'Rourke's simple-fold taxonomy (one-layer /
all-layers / some-layers) [demaine2007, §14.1.1].

Nothing in `docs/decision/` recorded this scope, and the design doc's "already carried"
phrasing invited building on a 3D guarantee that does not exist.

## Decision
Record flat-only as the **current, deliberate scope** of the evaluator: 2D
isometries, flat folded states, `faceOrders` for stacking.

Until that rework lands, the honest statement is: **flat-only today, 3D is where
we're aiming**; the staging is fine, but the capability is not carried by the 2D
state.

## Alternatives considered
- **Drop 3D as a goal, commit to flat-only permanently.** Rejected: 3D folded output
  is explicitly wanted (animation, non-flat display angles, the own rendering
  engine). This BEP records a limitation, not a preference against 3D.

## Consequences
- For the paper: the current guarantee is the all-layers simple-fold model
  [demaine2007, §14.1.1], stated as such, with no implied 3D generality.
