# Real layer ordering — design

**Slice:** replace the naive global stack with a proper per-face partial order.
**Status:** design approved, ready for implementation plan.
**Date:** 2026-07-01

## Problem

A folded state is a set of flat faces whose only 3D structure is their stacking
order. Today (`lib/fold_state.ml`) that order is faked two ways:

- `type t = { faces : face array; layers : int array }` — `layers` is vestigial,
  always `Array.init n (fun i -> i)`. The **array index is the z-order**
  (bottom→top).
- Each fold sets the order by a monolithic block rule
  (`fold_with_records`, line ~140): `if valley then stationary @ moved else
  moved @ stationary` — i.e. *all* moved faces above (valley) / below (mountain)
  *all* stationary faces, globally.
- `lib/fold_emit.ml` then derives FOLD `faceOrders` straight from array index +
  `det_sign`.

A global **total** order is wrong in principle: layer order is a **partial
order** on faces, defined only between faces that overlap when folded. This is
what FOLD's `faceOrders` encodes and what the flat-foldability literature uses
(`refs/hullzakharevich2023.txt` §2, lines 125–149; `antipatterns.md:13–18`
already records this as the intended model and forbids the layer-number/tree
heuristic). The concrete defects:

- **Spurious relations** between faces that never overlap.
- **Fragile reversal**: the moved block must reverse its internal order at the
  crease; the current append/prepend trick happens to get the all-layers case
  right but is not stated as a rule and breaks under partial overlap.
- **No representation for interior insertion** — a total order keyed by array
  index cannot express a flap tucked *between* two layers, which the deferred
  pocket-tuck slice will need.
- **No validity check**: an impossible stack (paper through paper) is silently
  emitted.

## Scope

**In:** simple folds only (`map … onto … moving …` with the `@` modifier). The
moved flap always lands on the **top** (valley) / **bottom** (mountain) of the
region it covers — a full simple fold wraps the flap around the outer edge, so
it clears any overhang; there is no forced interior insertion for simple folds.
The deliverable is the ordering *engine*: a partial-order data model, a
process-determined update rule, and validity guards.

**Out (deferred to the pocket-tuck slice):**
- Explicit pocket/tuck operations (new surface syntax, partial-layer folds that
  reflect only some layers and insert an edge into a gap).
- The **taco-taco** (crease-crease) non-crossing property — it only bites once
  explicit tucks exist.

**Hard constraint:** the ordering representation must not hard-code "top/bottom
only." Interior insertion must be expressible by writing the right relations,
so the pocket slice builds on this without reworking the model.

## Framing

Beloch is an evaluator of a **fold sequence**, not a solver for a static crease
pattern. Each fold is a physical reflection of a contiguous sub-stack about a
line, which **uniquely determines** the resulting order. So the order is
*computed* from the process, not *searched* for. General flat-foldability is
NP-hard (`refs/hullzakharevich2023.txt:31`, Bern–Hayes) — but that is the
static-pattern problem, which Beloch never faces. The three non-crossing
properties become **validation** (catch impossible folds / internal bugs), not
constraints to satisfy by backtracking.

## Data model

Replace `layers : int array` with an explicit pairwise partial order:

```ocaml
type rel = Above | Below | Apart
(* order.(i).(j) is i relative to j:
     Above  — face i is above face j when folded
     Below  — face i is below face j
     Apart  — faces i and j do not overlap on the table -> no constraint
   Invariant: order.(j).(i) = negate order.(i).(j); order.(i).(i) = Apart. *)
type t = { faces : face array; order : rel array array }
```

- `faces` stays an array, but the array index carries **no** z-meaning — it is
  only a handle. All stacking lives in `order`.
- Dense n×n matrix (n is tens of faces): simplicity over a sparse map. One
  triangle is the truth; the other is its negation.
- `face` is unchanged (`{ paper; iso }`).
- `Apart` is defined by geometry: `order.(i).(j)` is `Above`/`Below` iff the
  table polygons of i and j overlap (`Geom.convex_overlap`), else `Apart`.

## Update algorithm

Every operation rebuilds `faces` and `order` together. Face identity is
per-operation; relations are carried through a local parent map.

### Fold (`axis`, `move_side`, `valley`)

1. **Split with parentage.** Walk current faces. Each face yields up to two
   children: a *stay* part (keeps iso) and a *move* part (iso ∘ reflection).
   Record `parent[child]` = original index and `moved[child] : bool`. A face
   wholly on one side yields one child with the matching tag.

2. **Derive each pair's sign.** For children `c` (from parent `p`) and `d` (from
   parent `q`), the new relation is `Apart` unless their new table polygons
   overlap, in which case:
   - **stationary vs stationary** → preserved: `order[p][q]`.
   - **moved vs moved** → reversed (both reflected across the axis):
     `negate order[p][q]`.
   - **moved vs stationary** → the flap wraps onto the top (valley) / bottom
     (mountain), uniformly: moved is `Above` iff `valley`.
   - **hinge pair** (stay and move children of the *same* parent) → same as
     moved-vs-stationary: moved is `Above` iff `valley` where they overlap;
     `Apart` if they don't.

   Same-parent, same-side (can't happen — a parent splits into at most one stay
   and one move) needs no case.

3. **Result** is `{ faces; order }`. No block concatenation, no array-index
   semantics.

The moved-vs-moved reversal (step 2) is the rule the current prepend trick
fakes for the all-layers case; stating it pairwise makes it correct under
partial overlap, which is what a proper λ needs.

### `subdivide` (pre-crease; nothing moves)

Both children keep their iso, inherit the parent's relations verbatim, and are
mutually `Apart` (opposite sides of the crease, coplanar).

### `flip` (turn the sheet over)

Overlaps unchanged; every defined relation negates (`Above ↔ Below`).

## Validation & errors

Validation is a **correctness guard**, not a solver — a physical simple fold is
always realizable, so these should never fire for in-scope programs. A firing
signals an internal bug (or, later, an impossible pocket-tuck).

**Always-on, cheap — order well-formedness (after each op):**
- **Antisymmetry** — matrix is negation-symmetric (assert; free by
  construction).
- **Acyclicity / transitivity** — the `Above` relation over overlapping faces
  has no cycle. Topological check on the overlap graph. A cycle = paper through
  paper → raise `Error.Beloch_error` naming the offending pair.

**Non-crossing guards (this slice):**
- **Tortilla-tortilla (consistency)** — if two faces overlap, the pair has a
  decided order (no overlapping pair left `Apart`). Local per-overlap check.

**Deferred to the pocket-tuck slice:** **taco-tortilla** (face-crease
non-crossing) and **taco-taco** (crease-crease). Both need persistent
crease-adjacency tracking — which face meets which across each fold edge,
carried through splits — the same infrastructure the pocket slice introduces.
Neither can fire for in-scope simple folds, so wiring them now would be
speculative machinery guarding an impossible case.

**Error surface:** violations raise `Error.Beloch_error` with the fold's
provenance span, e.g.
`layer ordering: face 3 would pass through crease (2|5) — taco-tortilla
violation`.

## Emission

`lib/fold_emit.ml` stops deriving `faceOrders` from array index + `det_sign` and
reads `order` directly: for each `i < j` with `order.(i).(j) <> Apart`, emit one
`faceOrder` with the sign fixed by one golden case to match FOLD's convention.

## Testing

Harness: `tests/test_beloch.ml`.

**Unit — known stacks (assert exact `order`):**
- Single valley fold of the flat square → 2 faces, moved `Above` stationary.
- Single mountain fold → moved `Below`.
- `fold-quarter.bel` (fold moves a 2-layer stack) → 4-face order equals the
  hand-derived stack `[s0, s1, m1, m0]` bottom→top, including the moved-vs-moved
  **reversal**.
- A re-fold where moved and stationary only partially overlap → non-overlapping
  pairs are `Apart`, no spurious relation. This is the case the old global total
  order got wrong; it is the regression that justifies the slice.
- `flip` after a fold → every relation negated.

**Property tests** (over all folding `examples/*.bel`): the resulting `order`
satisfies antisymmetry, transitivity, acyclicity; the taco-tortilla and
tortilla-tortilla guards pass silently.

**Regression:** every current example still evaluates; emitted FOLD stays
schema-valid; multi-fold examples re-rendered via `tools/fold2svg.mjs` and the
stacks eyeballed.

**Emission:** `fold_emit` produces `faceOrders` from `order`, agreeing with the
matrix; sign convention pinned by one golden case.

## Files touched

- `lib/fold_state.ml` — new `rel`/`order` model, rewrite of the three update
  paths, validation guards.
- `lib/fold_emit.ml` — emit from `order`.
- `tests/test_beloch.ml` — unit + property + regression tests.
- `bin/main.ml` — unaffected (order is internal).
