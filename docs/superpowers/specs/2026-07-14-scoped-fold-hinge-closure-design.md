# Scoped-fold hinge-closure check

**Date:** 2026-07-14
**Status:** design
**Depends on:** the inline-assertion test format (`tests/cases/`, `expect error`).

## Problem

A scoped fold (`fold … up to <landmark>`) folds only some layers. The evaluator
computes the moving set (`select_scope`) purely from layer reachability to the
landmark, then reflects those faces (`fold_with_records ~moving_parents`) with
**no check that the scoped fold is physically realisable**. When the moving
flap is joined to a stationary layer along a hinge that is **not** on the fold
axis, folding only the flap is impossible — the paper would tear. The evaluator
silently produces the torn state (and, since commit `cc3184a`, renders it
cleanly by splitting the off-axis shared corner instead of degenerating).

Repro (identical to the `up to` tutorial example and `examples/fold-top-flap.bel`):

```
paper square
fold map .d onto .a          ; hinge at y = 0.5 joins the two layers
fold map .c onto .d up to .c ; axis x = 0.5 ⟂ that hinge → the top-right flap
                             ; is pinned to the bottom layer off-axis → tear
```

The evaluator emits 3 faces with `.b` fixed and `.c` at `(0,0)` — a state that
cannot be folded from flat paper.

## Hinge-closure rule

A scoped fold clips each in-scope face at the axis: the face's **move_side**
portion moves, its **stay_side** residual stays (`fold_with_records`). So
`moving_parents` is a coarse *per-face* eligibility flag, not "this whole face
moves." The tear condition must therefore look only at the hinge material that
actually lifts off — the portion on the **move side** of the axis.

A scoped moving set is **hinge-closed** (validly foldable) iff, for every
existing crease segment with faces `(l, r)` where `moves(l) ≠ moves(r)`, no part
of the segment lies strictly on the **move side** of the fold axis:

    moves(l) ≠ moves(r)  ∧  (side(axis, ta) = move_side ∨ side(axis, tb) = move_side)
      ⇒  TEAR (reject)

Endpoint-check suffices: the move-side open halfplane is convex, so if neither
endpoint is strictly on the move side, no interior point is. A hinge fully on
the **stay** side contributes only stationary material (no tear); a hinge **on
the axis** is a valid shared fold line.

This is exact and layer-aware: two *stacked* faces that share no crease segment
are independent layers (no constraint); a hinge bordering only the stationary
residual of an in-scope face is **not** a tear (the earlier, coarser "off-axis"
rule wrongly rejected valid parallel-hinge folds — see the false-positive found
in review).

Default (non-scoped) folds partition by the axis halfplane, so their mover/
stayer boundaries are on the axis by construction — the check is a no-op for
them and only bites scoped (`up to`) folds.

## Implementation

### `lib/fold_state.ml` — pure predicate
```
val scoped_fold_hinge_closed :
  t -> axis:Geom.line -> move_side:int -> moving_parents:bool array ->
  (unit, Geom.point * Geom.point) result
```
Iterate crease segments (over `all_crease_ids` → `crease_segments`, which
already give `faces = (l, r)` and table endpoints `ta`/`tb`). For each segment
with `moving_parents.(l) <> moving_parents.(r)` (guard `r >= 0`): let
`sa = Geom.side_of_line axis ta`, `sb = Geom.side_of_line axis tb`. If
`sa = move_side || sb = move_side` → `Error (ta, tb)` (a hinge whose material
on the move side would tear). Else continue. All clear → `Ok ()`. `move_side`
is the same value handed to `select_scope`/`fold_with_records` in this branch.

### `lib/eval.ml` — call site
In the `up to` branch (`Some tgt`), after `select_scope` returns
`Ok moving_parents` and **before** `fold_with_records`, call the predicate. On
`Error (ta, tb)` → `Error.fail span` with a message like:

    the moving flap is still joined to a stationary layer along the segment
    <ta>–<tb>, which is not on the fold axis — it cannot fold on its own
    (that would tear the paper). Move those layers too, or fold along a
    crease that lies on the axis.

Hard error (matches `check_straight`'s `Error.fail` style). No auto-widening,
no warning-and-produce.

## Testing

- **Negative (the bug):** `tests/cases/fold/up-to-tear.bel` — the repro above —
  `; expect error "tear"` (or a stable substring of the message).
- **Positive control (must pass):** a valid *parallel-hinge* scoped fold —
  where the moving flap's crease is parallel to the existing hinge so the
  folded portion does **not** contain the hinge — with positive assertions
  (`faces = …`, a landing `=`). **This example must be found/constructed and
  confirmed to eval AND pass the check.** If no valid `up to` fold can be
  constructed, that is a critical finding (the feature is unsound, not just
  the examples) — escalate before proceeding.
- Unit test in `tests/test_fold_state.ml` exercising the predicate directly on
  a hand-built state (one on-axis hinge → Ok, one off-axis → Error).

## Blast radius & triage (coupled — the check cannot land alone)

Turning the check on makes every tearing scoped fold error, which breaks:

- **Goldens:** `examples/fold-top-flap.bel`, `examples/crease-all-fold-some.bel`
  (same y=0.5 ⟂ x=0.5 geometry — tears), and possibly
  `examples/fold-top-two.bel` (different geometry — **verify empirically**).
  The golden test would flip these to error-goldens.
- **Site build:** the `up to` tutorial `site/src/content/docs/tutorials/layers.mdx`
  uses `up-to.bel` (= fold-top-flap) → `<Beloch>` evals at build time → the
  build fails once the check rejects it.

Triage (using the new test format for the hard split):
1. Move the tearing examples out of `examples/` into
   `tests/cases/fold/*-tear.bel` as `; expect error` cases (they become
   regression tests for the check, not showcases).
2. Replace the tutorial's `up-to.bel` with the **valid** parallel-hinge example
   (the positive control) and rewrite the surrounding prose to teach a real
   scoped fold.
3. Regenerate/prune the affected goldens.

## Sequencing (keep me in the loop)

1. Implement the predicate + eval wiring + unit test.
2. Run the FULL suite and eval **every** `up to` example; report which error
   (tears) vs pass (valid), and confirm a positive-control valid example
   exists. **Stop here for review** — the triage touches docs + goldens and
   depends on these empirical results.
3. Triage: move tears → `tests/cases`, fix the tutorial, prune goldens.
