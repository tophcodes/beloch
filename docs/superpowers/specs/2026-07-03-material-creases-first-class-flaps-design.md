# Beloch — Material Creases & First-Class Flaps (#26 + #28) Design

- **Issues:** [#26](topology in `Fold_state`), [#28](crease reference semantics),
  and the principled retirement of the [#27](precrease U/0°) tactical patch.
- **Status:** approved in brainstorm 2026-07-03; ADRs + implementation to follow.
- **Context:** `Fold_state.t` today is a bag of convex faces plus a pairwise
  order matrix (`fold_state.ml:9`) — no edges, no persistent crease identity, no
  face adjacency. Crease assignments live in an append-only side list of
  geometric chords (`crease_record`), and the edge set is *reconstructed at
  emission* by geometric matching (`fold_emit.ml:42-77`). Named creases are
  frozen table-space lines, bound once at eval and never updated by later folds
  or `flip` (`eval.ml:254`) — while named points are material and track through
  every fold. Two independent design reviews flagged that point/crease split as
  the core inconsistency of the current language.

## The decision in one line

Make **creases** and **flaps** first-class, material entities — carried in paper
coordinates, moving with the paper exactly like named points already do — and
address a flap by the points sitting on it (`#(.a .b .c)`).

---

## 1. The model

Three kinds of thing, unified under the action model (ADR-0011): everything the
user names is **material** — it lives in paper coordinates and is carried through
each fold's isometry.

- **Points** — already material. Unchanged.
- **Creases** — today a frozen table-space `Geom.line`, bound once. Become
  **material**: carried as *pieces*, one straight segment per flap the crease
  cuts. `flip` and later folds move the pieces automatically because each piece
  rides its flap's isometry. No special handling anywhere.
- **Flaps** — today anonymous, addressable only as "the flap containing `.p`"
  (`moving .p`). Become **first-class faces** with identity. A `#area` *is* one
  such flat flap.

A **crease** and a **flap edge** are the same entity seen from two sides: a
crease piece is the edge shared between two flaps. This is what lets one
data-model move (PR 1) serve both #26 (topology) and #28 (reference semantics).

---

## 2. Syntax — two new operand forms

Both fit the existing parenthesized operand family:

| Existing | Meaning |
|----------|---------|
| `.(--l1 --l2)` | point where two lines cross |
| `--(.a .b)` | line through two points |

New:

| New | Kind | Meaning |
|-----|------|---------|
| `#(.a .b .c)` | flap operand | the **unique current flat flap** with all listed points on it |
| `--(--d #(.a .b .c))` | line operand | the straight segment of crease `--d` lying on that flap |

**Flap resolution rule.** `#(.a .b .c)` = the unique current face whose closed
polygon contains every listed point. **Error if zero** ("those points aren't all
on one flap") **or more than one** ("ambiguous; add another point"). Corner
points are shared by adjacent flaps, but listing all corners of a flap picks it
uniquely — e.g. corner `b` lies on both triangles of a bd-split square, yet only
one flap contains all of `a`, `b`, `d`. This is why the user's mental notation
`#abd` / `#bcd` disambiguates: the point *set* is unique to the flap even when
individual points are not.

The area operand names **paper**, never a layer. (`antipatterns.md:19` — the 2018
`#region` conflated area-of-paper with z-ordering; we keep them distinct. A
`#area` is a region of paper; layer order stays in the `order` matrix.)

---

## 3. Crease reference semantics (the #28 answer)

Resolving a named crease `--d` to a fold axis:

1. Gather `--d`'s pieces (one straight segment per flap it cuts), each mapped to
   its current table-space position via its flap's isometry.
2. **If the pieces are collinear** in table space → return that line. This is the
   common case; every simple program that never folds across a named crease is
   unaffected.
3. **If a later fold bent them** (pieces no longer collinear) → **error**:
   > `--d is no longer straight after folding; pick a flap, e.g. --( --d #(.a .b .c) )`

The area operand is the **escape hatch**, not a dead end: `--(--d #(.a .b .c))`
restricts `--d` to a single flat flap, which is straight by construction and
always resolves to a valid fold line.

Rejected alternatives (brainstorm): *snap back to the original line* (today's
frozen behavior — the reviewed-and-flagged inconsistency); *silently pick one
piece* (guesses which flap — the ambiguity the `#(...)` operand exists to make
explicit).

---

## 4. `flip` and spec §4.7 — no rewrite needed

Under material creases, `flip` needs **no** crease handling: pieces ride their
flaps' isometries, so a global reflection moves them like any other material
mark. Spec §4.7's rationale — "which line `flip` reflects across is irrelevant;
only the substantive effect matters" — stays **true**, because creases are now
material like points and the internal axis cancels out of every material
comparison. This is the decisive advantage over the rejected option (b) (frozen
"desk construction lines"), under which the flip axis would have become
observable and §4.7 would have needed correction.

---

## 5. Internals (engineering choice, not a language decision)

**Relational edge records.** `Fold_state.t` gains an `edges` structure. Each edge
carries:

- its two endpoints in **paper** coordinates,
- the (one or two) bordering **flap ids**,
- assignment (`M` / `V` / `U` / `B`),
- a **stable crease id** (identity across face splits),
- provenance (`State.provenance option`).

Flaps reference their edge ids per boundary side; **adjacency = shared edge id**.

This:

- gives creases persistent **identity** (the #27 fix, §6);
- gives **adjacency** for free (the taco checks' prerequisite, deferred to the
  pocket slice);
- becomes the **referent** a named crease resolves against (§3);
- **retires the emit-time reconstruction** — `fold_emit` currently re-derives
  edges by `on_segment` matching against the chord list (`fold_emit.ml:42-49`);
  with edges first-class it serializes them directly.

Not chosen: a full half-edge/DCEL (overkill for convex flat-folds; a large
rewrite of `subdivide`/`fold_with_records`/`flip`); mirroring FOLD's arrays
in-memory (conflates persistent identity with the serialization format).

**No kernel surface.** This work adds zero new `Num` primitives and consumes the
kernel only through `Geom`/`Isometry`, using the field-arithmetic + sign layer
(`mul`/`sub`/`add`/`div`/`sign`/`compare`/`equal`). Flap resolution, straightness
(collinearity) tests, and isometry application all bottom out there; the exotic
ops (`Num.sqrt`, `Num.real_roots`) live only in the axiom-6/7 cubic machinery,
which this design never touches. It is therefore orthogonal to the FLINT kernel
migration — no file overlap (`num.ml`/`poly.ml`/`mpoly.ml` untouched), interface-
only coupling, and neither effort blocks the other.

---

## 6. Principled #27 (retiring the tactical patch)

#27 (precrease folded → U/0° instead of M/V) is **already fixed** tactically
(commit `0f2f55a`, #34): when a whole face abuts the fold axis, `fold_with_records`
emits an M/V record that must out-match the stale `U` chord at emit time
(`fold_state.ml:222-228`). That works by **geometric bookkeeping** — two chords
in an append-only list racing to be matched by collinearity — which is exactly
the "assignment keyed to cutting geometry, not a crease entity" pattern #26
exists to remove.

With the entity: a precrease is **one crease entity**; folding on it **upgrades
its assignment U→M/V in place**. One source of truth, no duplicate record, no
emit-time collinearity race. This is a **mechanism swap with no output change** —
not a new fix. Regression bar: identical FOLD output for the #27 example program
and all existing tests.

---

## 7. Staging — two PRs, two ADRs

### PR 1 — the plumbing (#26 + principled #27)

Introduce the first-class faces/edges entity; retire the #27 tactical hack in
favor of in-place assignment upgrade; kill the emit-time reconstruction.

- **No new language surface, no behavior change.** Same FOLD output for every
  existing program.
- **Verification:** all current test outputs byte-stable (modulo face-array
  order, which `flip`/fold already permute); the #27 example still emits V/180.
- ADR: *first-class topology in `Fold_state`* (the edge/flap entity, adjacency,
  identity).

### PR 2 — the language (#28 + areas)

On top of the entity: make creases material (per-flap resolution, bent→error) and
ship the escape-hatch syntax **in the same PR** — shipping the error without the
escape hatch is a regression with no recovery.

- New operands: `#(.a .b .c)`, `--(--d #(.a .b .c))`.
- Bent-crease error with the escape-hatch hint.
- **Verification:** a program that folds across a named crease and reuses it
  bare → errors with the hint; the same reference via `--(--d #(...))` resolves
  and folds; existing programs that never fold across a named crease unchanged.
- ADR: *crease reference semantics after later folds and flips* (material
  creases; §4.7 preserved; the bent-crease rule).

---

## 8. Out of scope

- **Taco-taco / taco-tortilla validity checks.** This work hands them the
  adjacency they need (§5); the pocket slice implements them.
- **Layer selection / region-as-predicate.** A `#area` here is a single flat
  flap named by contained points, not a predicate over paper. Richer region
  selection (the other half of the `antipatterns.md:19` "region ≠ layer" note)
  is deferred until a concrete model demands it.
- **Non-flat / partial folds**, reverse folds, sinks, unfold — later slices that
  reuse this entity.
- **Explicitly declared / fold-labelled flaps.** Rejected in brainstorm:
  declared handles fight the "one flat flap" model (a later fold splits them);
  fold-returns-tuples is unwieldy. Naming stays purely by contained points.

## 9. Testing strategy

- **PR 1 (refactor, output-invariant):** golden-file regression over the example
  corpus — every `.bel` produces the same FOLD (modulo face order); the #27
  precrease program emits V/180; adjacency queries on a taco-shaped state return
  the expected neighbor pairs (new, exercises the entity even though the checks
  that consume it are deferred).
- **PR 2 (new semantics):** bent-crease reuse errors with the hint; the
  `--(--d #(...))` restriction resolves to the expected line and folds; `#(...)`
  resolution errors on zero-flap and multi-flap point sets; a fold-then-flip
  program that reuses a still-flat crease resolves correctly (material tracking
  through `flip`).
