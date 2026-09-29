---
title: The OCaml kernel
description: How packages/core represents the states of the model, which statements it realizes, and where it stops short.
tableOfContents:
  minHeadingLevel: 2
  maxHeadingLevel: 2
---

`MODEL.md` says what a Beloch program talks about. This document says how the
kernel in `packages/core` holds that in memory and which of the model's
statements each part realizes. It refers to the model by the ids of its
statements; the model does not refer back. When the two disagree, the model
wins and the kernel has a bug, or the model has a gap and gets a new
statement.

Entries name OCaml modules and functions as they exist today and are updated
with the code. Anything the kernel cannot represent is stated as a ceiling
with the issue that tracks it.

## Sheet

The language offers one sheet, `paper square`, the unit square with the four
corners bound as `.a` to `.d`. The model's sheet
([def-sheet](/model/#def-sheet)) allows any simple polygon. Faces are convex
polygons in counter-clockwise order because `Geom` clips against half-planes
and tests overlap on convex polygons only; a non-convex sheet would enter as
several convex faces joined by hinges of angle $0$.

## State

`Fold_state.t` is abstract and `Fold_state.make` is its only constructor, so
every operation builds a candidate and passes it through `make`: no value of
type `Fold_state.t` exists that is not a legal state. `make` returns
`Error violation` for anything outside the definition of the state and its
non-crossing conditions ([def-noncrossing](/model/#def-noncrossing)); the
`violation` constructors and the conditions they check are listed under
Violations.

::: {.include api="Fold_state.t"}
:::

::: {.include api="Fold_state.make"}
:::

Faces are convex polygons in paper coordinates, one exact 2D isometry each
(`Isometry.t`), the restriction of $f$ to that face. A hinge names the two
faces it joins, its line and its angle in $\{0, \pm 1\}$ units of $\pi$:

::: {.include api="Fold_state.hinge"}
:::

Refinement equivalence ([def-refinement](/model/#def-refinement)) is not
quotiented in the representation: `mark` adds faces and hinges of angle $0$,
and two states equal up to refinement are two different values. Comparisons
across programs are made pointwise on the folded geometry, as in the test
that checks the two preliminary-base routes against each other.

## Rank

The kernel does not store $\lambda$. `Fold_state.rank` is a total order of
all faces, and `Fold_state.rel` reads *above*/*below* for a pair off the rank
only when the two table polygons overlap in positive area; otherwise the pair
is `Apart`. The rank is therefore a linear extension of $\lambda$ in the sense
of the model's remark on linear extensions
([rem-linear-extension](/model/#rem-linear-extension)), and two ranks with the
same restriction to overlapping pairs represent the same state.

Ceiling: a linear extension exists only for acyclic layerings, so states with
cyclic layering, the square twist among them, cannot be represented. Tracked
as [issue #83](https://github.com/tophcodes/beloch/issues/83). Nothing on the
crane path needs such a state.

## History

The model's state does not remember how it was reached. The kernel keeps the
history for output: the FOLD file carries one frame per statement in
`file_frames`, and per edge the statement that scored it in `beloch:edges` and
`beloch:source_line` (`SPECIFICATION.md` §7). No operation reads this record.

## Selection

`Axiom.axis_of` recognises a construction and solves it into its candidates
and the objects it moves; `Axiom.select` runs the four stages of
[def-selection](/model/#def-selection) on them with the side items of the
statement that reads it, and `Axiom.fold_side_of_line` gives `toward` its
meaning on a fold along an existing crease. The comparisons are exact:
squared distances between points and segments, and squared cosines between
lines, in `Num`. The side the selection fixes reaches the write as the
moving side. Where the write has no anchor, `Resolve.placed_fold_plan` and
`Resolve.tip_faces` take every layer on that side as the block or the tip,
and an implied anchor on the side that stays is dropped, because the
alignment it belongs to is carried out by the other object.

The material of a line in an alignment, a `toward` or a `moving` is, for a
crease, the crease's own segments, which can be fewer than all the paper on
its table line ([def-material](/model/#def-material)); for a line bound by
`=`, a paper edge or a mark, all the paper on it. A mark that ends mid-face
therefore counts as its whole chord; what a mark's material should be is
[issue #62](https://github.com/tophcodes/beloch/issues/62).

## Fan

`Flatten_solve.run` reads the rays of a `flatten` from material creases, and
`Collapse` folds the tip of [def-flatten](/model/#def-flatten) on the state
as it stands: it scores no layer itself. A face is placed in a sector when
all of it lies in one wedge of the fan, and a face a ray's half-line runs
through belongs to no sector. The tip grows from the anchor's faces outside
the stayer's wedge over hinges of any angle. A face of the tip that belongs
to no sector fails with `collapse through unaligned layers`, so the rays have
to be marked on every layer of the tip, `into` the same crease where the tip
holds several layers, and on no other layer. An anchor with nothing outside
the stayer's wedge fails with `the anchor flap has no material outside the
staying sector`. `on` reaches the kernel as the paper polygons of the flap it
names, so the anchor survives the scoring of an emergent ray.

The stacking ranks sectors, as `Collapse.linear_extensions` enumerates them.
The faces the fan leaves in place that lie outside the stayer's wedge are
ranked as blocks of their own, one per piece joined by flat hinges, and keep
their order where they overlap one another or the stayer's sector. Two
ceilings remain:

- The faces in the stayer's wedge rank as one block, the tip's and the
  others alike. A tip that has to lie between two layers that both reach
  into the stayer's wedge has no stacking, which is the case on a book fold
  when the rays are marked on both layers and only one corner is the tip
  ([issue #121](https://github.com/tophcodes/beloch/issues/121)).
- The emergent ray of a fan with an odd number of given rays is scored
  through every layer on its side, the layers outside the tip included
  ([issue #122](https://github.com/tophcodes/beloch/issues/122)).

### Checks

The checks of a `flatten`, roughly in evaluation order (see the note below
on checks 12–14). Every message and hint is the evaluator's own text.

| # | check | shipped message | shipped hint |
|---|---|---|---|
| 1 | element is not a material crease | `collapse folds along existing creases; <operand> is not a material crease` | |
| 2 | bare element resolves to zero material segments | `--<name> has no material segment` | |
| 3 | filtered/unioned element matches no segment | `` no segment of <expr> matches `` | |
| 4 | segments don't all share one strictly-interior common endpoint O | `no common interior vertex` | |
| 5 | (`staying` given) the flap's material doesn't touch the vertex fan | `the staying flap does not touch the vertex` | |
| 6 | a face of the tip does not carry the rays: a ray's half-line runs through it unscored, so it lies in no sector | `collapse through unaligned layers` | |
| 7 | the ray count is even and below 4 | `count` | `` use `fold` for n = 2 `` |
| 8 | (odd ray count) no geometric completion closes the vertex at all, on either side | `vertex not flat-foldable toward that side` | |
| 9 | a segment's far endpoint is not on the paper boundary (would leave a degree-1 vertex mid-sheet) | `crease ends inside the sheet` | |
| 10 | two elements resolve to the same ray — the same direction from O | `duplicate ray in collapse` | |
| 11 | Kawasaki fails — the reflection composition around O does not close (exact) [[hull2020]](#ref-hull2020) ch. 5 | `vertex not flat-foldable (angles)` | |
| 12 | the leading two elements' folded rays are collinear and no `staying` is given — the convention has no side to anchor | `` collinear leading creases don't pick a stayer `` | `add (staying <flap>)` |
| 13 | no realization keeps the stayer still — every candidate × Maekawa pattern died before a stacking closed | `no realization keeps the staying flap still` | |
| 14 | two different segment combinations (`SPECIFICATION.md` §4.9, Resolution) both survive with valid realizations | `` <name> is ambiguous at the vertex `` | `` select a segment with `&` `` |

Checks 7–11 run against a **candidate ray set** — the given rays, plus one
emergent candidate when the count is odd (Pipeline, below) — and never
depend on M/V: the count floor, Kawasaki closure, duplicate rays, and the
boundary check are all properties of which lines and directions are given,
not of which are marked mountain or valley. A candidate that fails any of
these fails for **every** Maekawa pattern tried against it — there is no
per-pattern variant of checks 7–11. Check 12 belongs to the same
M/V-independent family — the leading pair's collinearity is a fact about the
given rays alone, not about mountain/valley — but the evaluator probes it
once per attempted Maekawa pattern rather than once per candidate
(Pipeline, below): a difference in *where* the code checks it, not in what it
tests. Check 13 is not a single up-front gate: it is the fallback the
evaluator reports once every candidate and every Maekawa pattern has been
tried and none produced a live realization (\|S\| = 0, under Pipeline). Check 14 runs
once every segment combination has been attempted in full, before
`toward` selection is ever reached, a genuine contradiction between
combinations, distinct from the geometric/M/V selection stages that
follow it.

Two checks concern the anchor. They are numbered after the others so that
the numbers above keep their meaning.

| # | check | shipped message | shipped hint |
|---|---|---|---|
| 15 | (`on` given) no face of the named flap lies under the vertex | `the on flap does not lie under the vertex` | |
| 16 | the anchor has no face outside the stayer's wedge, so the tip is empty | `the anchor flap has no material outside the staying sector` | |

### Pipeline

Kawasaki's Theorem [hull2020, §5.3, Thm 5.17] says a single
interior vertex with consecutive sector angles `α₀ … α₂ₙ₋₁` is flat-foldable
iff the alternating angle sum is zero — exactly the condition
`Collapse.closure_ok` already checks as a reflection-composition identity (no
angle type needed). The odd-count case turns that check around: given an
**odd** number `k` of rays sharing a vertex O, the product of their `k`
reflections has `det = −1` and so is *itself* a reflection; its axis is a
line through O, and inserting it as one more ray makes the full `k + 1`-ray
composition close.

**Admissible stayer sectors.** Every candidate ray set is tried against each
fan sector that lies inside the stayer region (`SPECIFICATION.md` §4.9, State construction):
normally exactly one, unless the emergent ray itself falls inside the
leading pair's arc and splits it in two — then both halves are admissible,
and each is a genuinely different physical fold (a mirror world), not a
duplicate to dedup away. A collinear leading pair (both candidate arcs
exactly 180°) admits no sector at all without `staying` — check 12. The
evaluator rotates the ray labeling so the sector under test becomes sector 0
before the fan construction runs, which is what anchors `T_0 = identity` on
the stayer (`SPECIFICATION.md` §4.9, State construction).

1. **Count rays.** Odd → `Flatten.candidates` generates every geometric
   completion that could close the vertex: it tries every angular gap
   between the sorted given rays as the insertion point, keeps the
   candidates whose axis genuinely falls in its own gap, and tags each
   `LineNew` (a genuinely new line) or `OppositeRay` (the far side of an
   already-given line — degenerate in direction, not in position: it is
   still a real, non-constructible crease). None found → check 8, under Checks.
   Even → no candidate; the given rays are the whole ray set.
2. **Enumerate.** Each **segment combination** (`SPECIFICATION.md` §4.9,
   Resolution: one
   chosen segment per element, when a crease carries more than one at O) is
   tried independently. One guard runs before pattern search: *only when
   the statement has more than one combination to choose from*, another
   element's given ray landing strictly inside the stayer arc kills that
   combination — stayed material cannot carry a
   folding crease. This gate is what makes bare through-crease operands
   resolve without `&` (`SPECIFICATION.md` §4.9, Resolution): at the fish vertex, the
   combination that folds `--ray`'s far segment has that ray inside the
   leading pair's arc and dies here, leaving only the near segment. A
   single-combination statement has no alternative to fall back on, so a
   mis-ordered leading pair there is *not* caught this way — it runs the
   full pipeline and dies later as an ordinary `` collapse folds a flap off
   the paper (no seating keeps it in the sheet) ``, the same failure any
   other infeasible fold produces (see
   `packages/core/tests/cases/collapse/flatten-order-load-bearing.bel`).
   For each surviving combination, at each admissible stayer sector
   (above), the tip is found first: the anchor's faces outside the stayer's
   wedge and every face joined to them by hinges outside that wedge. A face
   of the tip that lies in no sector fails the sector with check 6, and an
   empty tip with check 16; both are M/V-independent. Otherwise enumerate every Maekawa-consistent completion of the *unpinned*
   slots (\|M − V\| = 2 over the rays; a pinned `mountain`/`valley` fixes
   its own slot — a pattern that can't satisfy Maekawa at all is never
   tried) and try each through the collapse oracle: Kawasaki closure
   (checks 7–11, already candidate-level and shared across every pattern),
   the stayer sector's admissibility (checks 12–13), then, per pattern, Maekawa
   itself, self-intersection, and `over`. A failing pattern contributes one
   of `` Maekawa violated by the stated assignment `` / `` assignment
   forces self-intersection `` / `` collapse folds a flap off the paper (no
   seating keeps it in the sheet) `` / `` contradictory `over` `` to a
   failure pool; a succeeding one becomes a **realization**, deduped
   against the others by observable stacking signature (two attempts that
   place and stack every face identically count once). If literally nothing
   survives across every combination and every admissible sector, that is
   check 13, `` no realization keeps the staying flap still ``.
3. **Segment-choice ambiguity** (check 14). If **more than one** segment
   combination independently produced a non-empty realization pool, the
   statement stops here: `` <name> is ambiguous at the vertex; select a
   segment with `&` ``, naming the element that had the multiple segments.
   Only a single winning combination's pool ever reaches selection —
   `toward` never resolves a segment-choice contradiction, only a fold
   direction.
4. **Decide by \|S\|** (S = every surviving realization of the winning
   combination, pooled across candidates and, per candidate, across every
   admissible stayer sector):

   - **Tier rule** (applied before counting): a `LineNew` realization always
     outranks an `OppositeRay` one — S is the `LineNew` pool if it is
     non-empty, the `OppositeRay` pool otherwise. A lone `LineNew` survivor
     decides even if several `OppositeRay` realizations also close.
   - \|S\| = 0 → infeasible, checked in priority order:
     `` collapse folds a flap off the paper (no seating keeps it in the
     sheet) `` if any candidate failed that way; else whichever of
     `` collapse through unaligned layers ``, `` the anchor flap has no
     material outside the staying sector ``, `` collinear leading creases
     don't pick a stayer ``, or `` no realization
     keeps the staying flap still `` appears first in the failure pool
     (checks 6, 16, 12, 13); else, odd count, `` the derived crease does not
     close the vertex ``; else (even count) the pool's own dominant
     failure — the first that isn't `` assignment forces self-intersection
     ``, falling back to that, or to `` Maekawa violated by the stated
     assignment `` if no pattern was even tried.
   - \|S\| = 1 → fold it. A `toward` item present is redundant, never an error.
   - \|S\| > 1 → **selection** (`SPECIFICATION.md` §4.9, Selecting among
     survivors).

## Annotations

An annotation never changes the geometry (ADR 0029), and the kernel holds to
that in two places. `Parse.parse` runs `Annotation.check`, which needs no
state. The evaluator reads an annotation's arguments with
`Annotation.resolve` when it reaches the annotation, and keeps the result
until the next statement takes its log entry. Some reads change the context
on their way: a filter on a crease that is still a mark subdivides the sheet
along it first, and every crease name a read looks up is recorded as a
reference. `Annotation.resolve` therefore reads inside a guard that puts the
state, the crease-id counter, the crease bindings and the references back as
it found them.

A test in `packages/core/tests/test_annotation.ml` replaces every annotation
of a program with spaces, which keeps every source span, and compares the two
FOLD documents without `beloch:annotations`.

## Violations

One constructor per check `Fold_state.make` runs, each carrying the model
statement it enforces. `Bad_index` and `Bad_line` reject a malformed
representation and answer to no statement of the model.

::: {.include api="Fold_state.violation"}
:::
