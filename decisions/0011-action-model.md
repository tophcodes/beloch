---
id: "0011"
title: "Beloch is an action model (folding), not only crease-pattern construction"
date: 2026-06-29
status: accepted
---

# 0011 — Beloch is an action model (folding), not only crease-pattern construction

## Context
Beloch v0.0–v0.4 was a crease-pattern *construction* language: Huzita-Justin axioms
on the flat sheet, evaluated order-independently into a flat crease pattern. The
planned mountain/valley *annotation* slice exposed two facts: (1) there is no mountain
fold on a flat desk — M/V is relative to a side, not intrinsic to the act of folding;
(2) the original intent was to describe the *actions* performed on real paper, including
folding through all layers of an already-folded stack.

A landscape check (2026-06-29) found the combination unoccupied: a textual action
sequence + exact constructible arithmetic through the fold + action-derived layer
ordering + dual FOLD (`creasePattern` + `foldedForm`) output. The nearest "competitor"
(Kleinlaut) is fabricated AI content; the Haskell axiom eDSL overlaps only the axiom
layer.

## Decision
Beloch is an **action model**: a `.bel` program is an imperative sequence of folding
actions on a stateful sheet. The flat crease pattern and mountain/valley become *derived*
outputs. The Huzita-Justin axioms remain the "where is the crease" primitive. Geometry
stays exact (`Num`); arbitrary/animated fold angles use constructible-rational
approximation. The folded state is the standard FOLD `foldedForm` (faces + per-face
isometry + an addressable layer stack). Superposition axioms 2 & 5 unify under
`map … onto …`.

Surface syntax: the original `@axiom [moving .p] [mountain]` marker was retired in
the mark/fold revision (see the note below). A crease is now
**motion × disposition × extent**: a *motion* (`map … onto …`, `through`, `perp`)
is a pure read that produces a line value, and a *disposition* verb (`mark`,
`fold`, `collapse`, `flip`) is the write that touches the paper. Fold direction is
`toward` / implied `moving`; the segment filter is `&` and region sets are `#[…]`.

Full design and the staged "ladder" (simple fold → layer selection → unfold/maneuvers):
`docs/superpowers/specs/2026-06-29-action-model-folding-design.md`. The surface-syntax
revision that retired `@` is
`docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md` (and the
bundle-algebra selection design for `&` / `#[…]`); the deeper action-model questions
it raised were tracked and resolved in #23.

## Consequences
- Breaking syntax change (`fold`/`bisect` → `map … onto …`); acceptable pre-1.0.
- The mountain/valley *annotation* slice is obsolete.
- Engineering/rigid-panel thickness is out of scope; thickness is a display-only offset.
- The folded-state runtime and its output land in a later, separately-designed plan.
