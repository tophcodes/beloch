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

A program opens one sheet ([Sheets](/language/#sheets)): the square of a
side length, or the flap a shape trims. `Sheet.t` holds the unfolded state the
program starts from and the outline of the sheet, its boundary sides in paper
coordinates. The model's sheet ([def-sheet](/model/#def-sheet)) is any simple
polygon. Faces are convex polygons in counter-clockwise order because `Geom`
clips against half-planes and tests overlap on convex polygons only; a
non-convex sheet enters as several convex faces joined by hinges of angle $0$.

The square of side $s$ is one face with its corners at $(0,0)$, $(s,0)$,
$(s,s)$ and $(0,s)$. `Sheet.trim` builds a trimmed sheet from the faces of the
flap in paper coordinates, every face in place, with the flat hinges and the
marks that lie on them. A flat hinge of a crease the shape body folded in any
of its states merges its two faces into one where their union is convex. Where
the union is not convex the hinge stays as a join edge, which divides the
sheet into convex faces and is no crease of it: `Sheet.t` lists its crease in
`joins`, the output assigns it `J`, and no name of the body carries over to
it. A flap whose
boundary is more than one loop has a hole and is refused.

Three operations read the sheet and nothing else of its shape. Clipping a line
to the sheet clips it to every face of the unfolded state and takes the two
furthest-out points. The output assigns `B` to an edge that lies on a side of
the outline. A collapse keeps the realizations whose faces lie on the table
inside the convex hull of every table polygon of the state before the collapse
(ADR 0046).

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
moving side. `Resolve.placed_fold_plan` takes every layer on that side as
the block unless `up to` names a flap, and where the write has no anchor
`Resolve.tip_faces` takes every layer on that side as the tip. An implied
anchor on the side that stays is dropped, because the
alignment it belongs to is carried out by the other object.

The material of a line in an alignment, a `toward` or a `moving` is, for a
crease, the crease's own segments, which can be fewer than all the paper on
its table line ([def-material](/model/#def-material)); for a line bound by
`=`, a paper edge or a mark, all the paper on it. A mark that ends mid-face
therefore counts as its whole chord; what a mark's material should be is
[issue #62](https://github.com/tophcodes/beloch/issues/62).

## Fan

`Flatten_solve.run` reads the rays of a `flatten` from material creases,
scores them on the layers under the fan, and `Collapse` folds the tip of
[def-flatten](/model/#def-flatten) on the scored state. The layers under
the fan are the faces whose table image meets the anchor's in positive
area. `Fold_state.subdivide_fan` scores each ray along its half-line from
the vertex into the ray's own crease: a face that holds the vertex inside
it is cut into the wedges between consecutive rays at once, and every other
face a half-line crosses is cut along it. The pieces carry the flatten as
the statement that scored them. A program therefore marks the rays on one
layer, and the flatten carries them onto the others.

The tip is read off the state scored through every layer under the fan,
with `Collapse.tips` for each admissible stayer sector, and the rays are
then scored again on the state before the flatten, in each face that holds
a face of the tip; the other layers keep their faces whole. Sectors whose
tips hold different faces are solved on states of their own. A face is
placed in a sector when all of it lies in one wedge of the fan, and a face
a ray's half-line runs through belongs to no sector. The tip grows from the
anchor's faces outside the stayer's wedge over hinges of any angle. A face
of the tip that still belongs to no sector, one outside the layers under
the fan that a half-line runs through, fails with `collapse through
unaligned layers`. An anchor with nothing outside the stayer's wedge fails
with `the anchor flap has no material outside the staying sector`. `on`
reaches the kernel as the paper polygons of the flap it names, so the
anchor survives the scoring.

An odd fan scores its emergent ray with the given rays, the same way. The
emergent ray goes into the crease the program already scored along it on
some layer, when there is exactly one, so that it is one crease on every
layer of the tip; otherwise into a new crease, or into the crease `into`
names.

`Collapse.mk_sector_geoms` gives each hinge of the tip on a ray a role
(ADR 0044). A flat hinge of a ray's crease folds. A folded hinge of a ray's
crease keeps or opens, and a hinge of another crease on a ray keeps or
changes; the kernel tries every combination of these, so the work doubles
with each of them. For each combination it moves every face by the
reflections across the changing hinges on a path from a face outside the
tip, found breadth-first, and drops the combination when two paths to a
face disagree or nothing moves. Kawasaki's and Maekawa's conditions at the
vertex run only where the anchor surrounds the vertex on the paper;
elsewhere `Fold_state.make` checks that the paths close.

The stacking ranks units, as `Collapse.linear_extensions` enumerates them. A
unit of the tip holds the faces of one wedge that share one motion; the
first motion in a wedge keeps the wedge's number, so on one sheet the units
are the wedges. The stayer's unit holds the faces of the stayer's wedge the
tip hangs from: every piece of the wedge, joined by flat hinges inside it, that is
hinged to a face of the tip, and the whole wedge when none is. Every other
face the fan leaves in place, inside the stayer's wedge or outside it, is
ranked in a block of its own, one per piece joined by flat hinges, and keeps
its order where it overlaps another face that stays. The tip can land
between two such layers: on a book fold with the rays marked on both
layers, the upper corner folds in between the upper and the lower layer.
One ceiling remains: the pieces of the stayer's wedge the tip hangs from
rank as one block, so a tip hinged to two of them cannot land between them.

### Checks

The checks of a `flatten`. Every message and hint is the evaluator's own
text. The numbers name the checks and keep their meaning as checks are
added; the order the evaluator runs them in follows the tables.

| # | check | shipped message | shipped hint |
|---|---|---|---|
| 1 | element is not a material crease | `collapse folds along existing creases; <operand> is not a material crease` | |
| 2 | bare element resolves to zero material segments | `--<name> has no material segment` | |
| 3 | filtered/unioned element matches no segment | `` no segment of <expr> matches `` | |
| 4 | segments don't all share one common endpoint O, or O lies on the sheet's raw edge in some layer (read on the paper, whatever the sheet's shape and wherever folding placed it) | `no common interior vertex` | |
| 5 | (`staying` given) a point of `staying` lies on no face of the anchor | `<point> does not lie on the anchor` | `name a point on the flap the fan folds` |
| 6 | a face of the tip does not carry the rays after the scoring: it lies outside the layers under the fan and a ray's half-line runs through it, so it lies in no sector | `collapse through unaligned layers` | |
| 7 | the ray count is even and below 4 | `count` | `` use `fold` for n = 2 `` |
| 8 | (odd ray count) no geometric completion closes the vertex at all, on either side | `the derived crease does not close the vertex` | |
| 9 | a ray's far end lies inside a face of its flap, off its raw edges and folded edges; a flat crease there does not end the ray (it would leave a vertex of degree 1 inside the flap) | `crease ends inside the sheet` | |
| 10 | two elements of one crease resolve to the same ray (the same direction from O) | `duplicate ray in collapse` | |
| 11 | Kawasaki fails: where the anchor surrounds O on the paper, the reflection composition around O does not close (exact) [[hull2020]](#ref-hull2020) ch. 5; elsewhere no combination of the hinges the fan may change closes its paper paths, which surfaces as check 13 | `vertex not flat-foldable (angles)` | |
| 12 | the leading two elements' folded rays are collinear and no `staying` is given; the convention has no side to anchor | `` collinear leading creases don't pick a stayer `` | `add (staying .p)` |
| 13 | no realization keeps the stayer still: every candidate × Maekawa pattern died before a stacking closed, the paper-path closure of check 11 included | `no realization keeps the staying flap still` | |
| 14 | two different segment combinations (`SPECIFICATION.md` §4.9, Resolution) both survive with valid realizations | `` <name> is ambiguous at the vertex `` | `` select a segment with `&` `` |

Checks 7 and 9–11 run against a **candidate ray set**: the given rays, plus
one emergent candidate when the count is odd (Pipeline, below); check 8 is
the odd count finding no candidate at all. They never depend on M/V: the
count floor, the boundary check, duplicate rays and Kawasaki closure are
properties of which lines and directions are given, not of which are marked
mountain or valley. Check 11 runs here only where the anchor surrounds O on
the paper. Elsewhere its test, whether some combination of the hinges the
fan may change closes the paper paths (ADR 0044), runs per admissible
stayer sector after checks 16 and 6, and a fan that fails it reports
`` no realization keeps the staying flap still ``. A candidate that fails any of them fails for **every**
Maekawa pattern tried against it, and checks 7–11 have no per-pattern
variant. With an odd count their own messages never reach the program: when
no candidate survives, the evaluator reports
`` the derived crease does not close the vertex `` for all of them, unless a
more specific failure stands in the pool (Pipeline, step 4). Check 12
belongs to the same M/V-independent family (the leading pair's collinearity
is a fact about the given rays alone) and runs once per candidate, after
checks 7–11 and before any Maekawa pattern is tried. Check 13 fails a
candidate whose leading pair admits no stayer sector, and it is also the
fallback the evaluator reports once every candidate and every Maekawa
pattern has been tried and none produced a live realization (\|S\| = 0,
under Pipeline). Check 14 runs once every segment combination has been
attempted in full, before `toward` selection is ever reached: a genuine
contradiction between combinations, distinct from the geometric/M/V
selection stages that follow it.

Two checks concern the anchor. They are numbered after the others so that
the numbers above keep their meaning.

| # | check | shipped message | shipped hint |
|---|---|---|---|
| 15 | (`on` given) no face of the named flap lies under the vertex | `the on flap does not lie under the vertex` | |
| 16 | the anchor has no face outside the stayer's wedge, so the tip is empty | `the anchor flap has no material outside the staying sector` | |

Four checks concern the stayer (ADR 0048). A candidate fan that fails 17,
18 or 19 contributes no states, and the message surfaces when no candidate
fan contributes any.

| # | check | shipped message | shipped hint |
|---|---|---|---|
| 17 | no sector's closed wedge holds every point of `staying` | `no sector of the fan holds every staying point` | |
| 18 | more than one sector's closed wedge holds them | `the staying points lie in more than one sector` | `add a point inside the sector that stays` |
| 19 | the one sector holds no face of the anchor | `the staying sector holds no material of the anchor` | |
| 20 | the candidate states left for the selection hold different sectors still | `flatten is ambiguous: its candidates hold different sectors still` | `add (staying .p) with .p in the sector that stays` |

The evaluator runs the checks in this order. Checks 1–3 run per element, in
source order, and check 4 once the elements are resolved; then check 15,
when `on` is given, and check 5, when `staying` is given. Each segment
combination runs check 8 (odd count only), and each candidate fan of it
checks 7, 9, 10 and 11, then the stayer: check 12 or 13 under the
leading-pair convention, checks 17, 19 and 18 under `staying`. Per admissible
stayer sector follow check 16, check 6 and, where the anchor does not
surround O, the paper-path closure of check 11; then per Maekawa pattern
the pattern's parity, where the anchor surrounds O, and the stacking. Check 14 runs once every combination has been tried, and check 20
once one combination's states reach the selection.

### Pipeline

Kawasaki's Theorem [hull2020, §5.3, Theorem 5.17] says a single
interior vertex with consecutive sector angles `α₀ … α₂ₙ₋₁` is flat-foldable
iff the alternating angle sum is zero. That is exactly the condition
`Collapse.closure_ok` already checks as a reflection-composition identity (no
angle type needed). The odd-count case turns that check around: given an
**odd** number `k` of rays sharing a vertex O, the product of their `k`
reflections has `det = −1` and so is *itself* a reflection; its axis is a
line through O, and inserting it as one more ray makes the full `k + 1`-ray
composition close.

**Admissible stayer sectors.** Every candidate ray set is tried against each
fan sector that lies inside the stayer region (`SPECIFICATION.md` §4.9, State construction):
normally exactly one, unless the emergent ray itself falls inside the
leading pair's arc and splits it in two; then both halves are admissible,
and each is a different physical fold (a mirror world), not a
duplicate to dedup away. A collinear leading pair (both candidate arcs
exactly 180°) admits no sector at all without `staying` (check 12). With
`staying`, the admissible sector is the one sector whose closed wedge holds
the table images of its points (checks 17 to 19). The
evaluator rotates the ray labeling so the sector under test becomes sector 0
before the fan construction runs, which is what anchors `T_0 = identity` on
the stayer (`SPECIFICATION.md` §4.9, State construction).

1. **Count rays.** Odd → `Flatten.candidates` generates every geometric
   completion that could close the vertex: it tries every angular gap
   between the sorted given rays as the insertion point, keeps the
   candidates whose axis falls in its own gap, and tags each
   `LineNew` (a new line) or `OppositeRay` (the far side of an
   already-given line: degenerate in direction and not in position, it is
   still a real, non-constructible crease). None found → check 8, under Checks.
   Even → no candidate; the given rays are the whole ray set.
2. **Enumerate.** Each **segment combination** (`SPECIFICATION.md` §4.9,
   Resolution: one
   chosen segment per element, when a crease carries more than one at O) is
   tried independently. One guard runs before pattern search: *only when
   the statement has more than one combination to choose from*, another
   element's given ray landing strictly inside the stayer arc kills that
   combination: stayed material cannot carry a
   folding crease. This gate is what makes bare through-crease operands
   resolve without `&` (`SPECIFICATION.md` §4.9, Resolution): at the fish vertex, the
   combination that folds `--ray`'s far segment has that ray inside the
   leading pair's arc and dies here; only the near segment remains. A
   single-combination statement has no alternative to fall back on, so a
   mis-ordered leading pair there is *not* caught this way; it runs the
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
   its own slot; a pattern that can't satisfy Maekawa at all is never
   tried) and try each through the collapse oracle: Kawasaki closure
   (checks 7–11, already candidate-level and shared across every pattern,
   where the anchor surrounds O), the stayer sector's admissibility
   (checks 12, 13 and 17–19), the closure of the paper paths where the
   anchor does not surround O, then, per pattern, Maekawa itself where it
   does, self-intersection, and `over`. A failing pattern contributes one
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
   Only a single winning combination's pool ever reaches selection:
   `toward` never resolves a segment-choice contradiction, only a fold
   direction.
4. **Decide by \|S\|** (S = every surviving realization of the winning
   combination, pooled across candidates and, per candidate, across every
   admissible stayer sector):

   - **Tier rule** (applied before counting): a `LineNew` realization always
     outranks an `OppositeRay` one: S is the `LineNew` pool if it is
     non-empty, the `OppositeRay` pool otherwise. A lone `LineNew` survivor
     decides even if several `OppositeRay` realizations also close.
   - \|S\| = 0 → infeasible, checked in priority order:
     `` collapse folds a flap off the paper (no seating keeps it in the
     sheet) `` if any candidate failed that way; else whichever of
     `` collapse through unaligned layers ``, `` the anchor flap has no
     material outside the staying sector ``, `` collinear leading creases
     don't pick a stayer ``, `` no realization
     keeps the staying flap still `` or the message of check 17, 18 or 19
     appears first in the failure pool
     (checks 6, 16, 12, 13, 17–19); else, odd count, `` the derived crease does not
     close the vertex ``; else (even count) the pool's own dominant
     failure: the first that isn't `` assignment forces self-intersection
     ``, falling back to that, or to `` Maekawa violated by the stated
     assignment `` if no pattern was even tried.
   - \|S\| = 1 → fold it. A `toward` item present is redundant, never an error.
   - \|S\| > 1 → **selection** (`SPECIFICATION.md` §4.9, Selecting among
     survivors).

## Reverse

`Action.eval_reverse` realizes [def-reverse](/model/#def-reverse) with
`Fold_state.reverse_attempts`, the state as it stands, and no scoring of
its own beyond the axis.

The tip is `Resolve.tip_faces`: the anchor's faces with a piece on the moving
side, or every such face when there is no anchor, closed under hinges whose
table segment reaches strictly beyond the axis. The openings are read off
the rank: the faces of the tip in rank order, and a cut between two
consecutive ones is an opening where every hinge between two faces of the
tip that crosses it is folded, all of them lie on one table line, and one
of them reaches beyond the axis. A cut crossed by a flat hinge is none.

Each opening is folded with `Fold_state.fold_blocks`: the lower block over
the topmost face of its body and the upper block under the bottommost face
of its body for `inside`, the lower block at the bottom and the upper block
on top for `outside`. The body of a block is its faces that the axis cuts,
whose stationary pieces stay. Where one body is empty the opening is
removed, and where the two bodies' ranks overlap at all, overlapping on the
table or not, it is removed as interleaved: the kernel's test is stricter
than the model's.

A letter item names hinges by the segments `&` selects from a crease; the
hinges of the tip among them are the ones it constrains. An opening keeps
the letter where each such hinge has it after the fold: the letter it had
before where the hinge does not cross the opening, the other one where it
does. The hinges on the axis are left to the placement.

The states of the kept openings are compared with `Fold_state.rel`: two that
order every overlapping pair of faces alike are one state
([def-flat-state](/model/#def-flat-state)). Of one state, the kernel stores
the rank of the opening that keeps the new hinges on the axis shortest in
the stack, the sum over them of the rank distance between their two faces;
ties go to the lowest opening. More than one state fails with a hint that
names one letter item per state: a hinge on the spine's line whose letter
differs from its letter in every other state, named by its crease and a
named point that lies on its segment alone, or `.p` with the paper point
where it lies when no named point does.

| message | hint |
|---|---|
| `reverse needs a tip folded along one spine; the moving material does not split into two halves` | |
| `the tip opens at <n> places` | `add one letter, which keeps one opening: (--e & .q mountain) or …` |
| `the two halves are hinged to interleaved layers; that is not a reverse fold` | |
| `the letter names no hinge of the tip` | |
| `reversing the tip would pierce layer <n>` | |
| `reversing the tip would pierce another layer` | |

The first is the failure when no opening gives a state and none was
removed as interleaved or by a violation. Otherwise the lowest such opening
names the failure: interleaved bodies, or the violation its fold met.

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
