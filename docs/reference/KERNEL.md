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

A program opens one sheet ([[reference/beloch#sheets]]): the square of a
side length, or the flap a shape trims. `Sheet.t` holds the unfolded state the
program starts from and the outline of the sheet, its boundary sides in paper
coordinates. The model's sheet ([[reference/model#def-sheet|def-sheet]]) is any simple
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
the outline.

## State

`Fold_state.t` is abstract and `Fold_state.make` is its constructor, so
every operation builds a candidate and passes it through `make`: no value of
type `Fold_state.t` exists that is not a legal state. `make` is two steps,
`Fold_state.geometry` and `Fold_state.with_rank`; a caller that validates
many layer orders of one set of faces and hinges takes the steps apart and
derives the placements once. `Fold_state.with_order` is the second step for
a layer order given as pairs (Layer order, below). `make` returns
`Error violation` for anything outside the definition of the state and its
non-crossing conditions ([[reference/model#def-noncrossing|def-noncrossing]]); the
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

Refinement equivalence ([[reference/model#def-refinement|def-refinement]]) is not
quotiented in the representation: `mark` adds faces and hinges of angle $0$,
and two states equal up to refinement are two different values. Comparisons
across programs are made pointwise on the folded geometry, as in the test
that checks the two preliminary-base routes against each other.

## Layer order

`Fold_state.t` stores $\lambda$ (spec `architecture`, "The kernel stores the
layer order as a side per pair of overlapping faces"): for every two faces
whose table polygons overlap in positive area (`Geom.convex_overlap`;
touching is no overlap), which of the two lies above. Two faces that do not
overlap have no entry. `Fold_state.above` and `Fold_state.rel` read one
pair, `Fold_state.order` lists every pair, and `Fold_state.same_order`
compares two states pair by pair. No operation reads a height of a face.

Four functions build the layer order of a state:

- `Fold_state.make` and `Fold_state.with_rank` take a stacking, a
  permutation of the faces from the bottom up, as the input form. They keep
  the side of every overlapping pair and nothing else of the stacking, so two
  stackings with the same restriction to overlapping pairs give the same
  state ([[reference/model#rem-linear-extension|rem-linear-extension]]).
- `Fold_state.with_order` takes the pairs. It is the only way to build a
  state whose layers lie in a cycle. A test builds the square twist with it:
  9 faces, 12 folded hinges and 28 overlapping pairs, in which the four
  corner faces lie in a cycle.
- `Fold_state.orders` searches the pairs. The caller gives the side of the
  pairs it knows and the pairs it fixes, and gets every state whose other
  pairs satisfy the conditions below. Every write that folds finds its
  layer order with it: `flatten`, `squash` and `reverse` (Fan, below) and
  `fold`.

::: {.include api="Fold_state.with_rank"}
:::

::: {.include api="Fold_state.with_order"}
:::

The checks on the pairs are three conditions of the model:

- The order condition ([[reference/model#cond-order|cond-order]]): no three
  faces whose table polygons share a region of positive area lie in a cycle.
  Three faces suffice: all faces over one point of the table overlap
  pairwise, and such an order has a cycle only if it has a cycle of three.
  The kernel computes the shared region exactly, and only for a triple that
  lies in a cycle. `with_rank` skips the check, since a stacking holds no
  cycle.
- The taco-tortilla condition
  ([[reference/model#cond-taco-tortilla|cond-taco-tortilla]]), in its form
  for a face that crosses a folded hinge and in its form for a flat hinge
  collinear with a folded one.
- The taco-taco condition
  ([[reference/model#cond-taco-taco|cond-taco-taco]]).

The taco conditions ask whether a face lies between two others, and the
kernel answers that only for a face that overlaps both. Two folded hinges on
one table line whose face pairs open to opposite sides of the line share no
region, and no condition relates them
[@hullzakharevich2023, §2.1, "Taco-Taco Property"; @akitaya2016, §2].

A fold computes the pairs of the new state (`Axis_fan.fold_blocks`, the fan
at the point at infinity of its axis; Fan, below). Two
staying faces keep their side, and two faces of one moved block exchange
sides. A block placed `Top` lies above every staying face it lands on, and
a block placed `Bottom` below them; these sides fix every pair, and
`Fold_state.orders` checks the one state they give. A block placed `Over` or
`Under` faces lies directly on each of them; the three conditions (spec
`layer-order`, "Three conditions decide the side of a layer the moved paper
lands on") fix the pairs they decide, and `Fold_state.orders` decides the
rest. A face
that `subdivide` cuts
passes its sides on to its pieces.

`Fold_state.orders` works in two steps. It first relates the sides it has to
decide: a face that covers part of a hinge's crease lies on the same side of
both faces of the hinge. At a folded hinge this is the taco-tortilla
condition, and at a hinge of angle 0 the two faces are one uncreased sheet
([[reference/model#def-flat-state|def-flat-state]]). The sides this leaves
open fall into classes whose members turn together. The search then sets one
class after the other, to one value and to the other, and gives up a partial
order as soon as the sides set so far break the order condition or a taco
condition. One ceiling: the order condition and the taco-taco condition
reject a partial order and set no side, so the work doubles with every class
that none of them rejects.

One more ceiling: `with_order` checks no condition at a hinge of angle 0. A
list of pairs that puts a face above one face of such a hinge and below the
other, across the hinge, passes. Every state an operation builds keeps its
faces on one side of such a hinge. Tracked as
[issue #284](https://github.com/tophcodes/beloch/issues/284).

## History

The model's state does not remember how it was reached. The kernel keeps the
history for output: the FOLD file carries one frame per statement in
`file_frames`, and per edge the statement that scored it in `beloch:edges` and
`beloch:source_line` ([[reference/fold]]). No operation reads this record.

## Selection

`Axiom.axis_of` recognizes a construction and solves it into its candidates
and the objects it moves; `Axiom.select` runs the four stages of
[[reference/model#def-selection|def-selection]] on them with the side items of the
statement that reads it, and `Axiom.fold_side_of_line` gives `toward` its
meaning on a fold along an existing crease. The comparisons are exact:
squared distances between points and segments, and squared cosines between
lines, in `Num`. The side the selection fixes reaches the write as the
moving side. `Resolve.placed_fold_plan` takes every layer on that side as
the block unless `up to` names a flap, then closes the block under hinges
off the axis and outward up to the target, as
[[reference/model#def-fold|def-fold]] states; where the write has no anchor
`Resolve.tip_faces` takes every layer on that side as the tip. An implied
anchor on the side that stays is dropped, because the
alignment it belongs to is carried out by the other object.

`Axiom.line_material` reads the bundle of a line in an alignment, a
`toward` or a `moving`: for a crease its own segments, for a mark its
extent, and for a paper edge all the paper on it.
A state does not split its faces along a mark: `Fold_state` keeps each
extent as a record in paper coordinates beside the faces, and
`Fold_state.mark_material_segments` cuts the records into one table piece
per face they cross, so a fold across a mark splits its bundle with the
faces. A point that folds onto a line is tested against all the paper on
the line's table line. Where a line would carry its point but its bundle
stops short of the place that lands there, and nothing else keeps the fold
from carrying out the construction, `Axiom.select` fails with that place,
`--x does not reach (x, y), the point of its line that lands on .p`, and
hints `extend --x to (x, y)`.

## Fan

`Flatten_solve.run` reads the rays of a `flatten` from material creases and
hands them to `Flatten_solve.solve`, which folds them at a point of the
paper (spec `multifold`, "A fan folds at a point of the paper"); `Collapse`
folds the tip of
[[reference/model#def-flatten|def-flatten]] on the scored state. The vertex
is the one paper point over the table vertex that a piece of every
element passes through (`Fan_paper.vertex`). Where several paper points
qualify, the anchor of a squash picks the one on it, and a flatten fails
with `the vertex lies at several points of the paper`. `Collapse` takes
the layers that meet at the vertex as its anchor: Kawasaki's condition
runs where they surround the vertex, and the staying sector has to hold a
face of them.

A given ray folds the pieces its element names, and the statement scores
no other layer with it. An odd fan scores its emergent ray from the
vertex through the layers that meet at the vertex: the faces at the
vertex's paper point that the ray's half-line enters, and every face a
flat hinge joins to one of them that it enters (`Fan_paper.line_faces`).
`Fold_state.subdivide_fan` scores the ray from the vertex into its crease
on those faces. The pieces carry the flatten as the statement that scored
them.

The tip is read off the paper (`tip_rule_for` in `Flatten_solve`). A hinge
of the fan is a piece of a ray's crease on its half-line that ends at the
vertex's paper point, one of the pieces its element names for a given ray.
`Fan_paper.parts` splits the paper along those hinges; a path between two
faces crosses hinges and never runs through a single point. The parts that
hold a face of the staying sector with a staying point stay, or with the
vertex's paper point where the statement names no staying point; the rest
is the tip. A hinge on a ray's table line that does not end at the
vertex's paper point keeps its angle. A layer under the table vertex that
holds a face of the tip and on which no hinge of the fan lies fails the
fan with `the layer of .p lies under the vertex and moves, but no ray of
the fan folds it`, naming the layer by the first point of the program on
it in alphabetical order (`Fan_paper.unfolded_layer`). A squash keeps its
anchor and skips that check. A face of the tip that lies in no sector
fails with `collapse through unaligned layers`, and an empty tip with
`the anchor flap has no material outside the staying sector`.

The emergent ray goes into the crease the program already scored along it
on some layer, when there is exactly one, so that it is one crease on every
layer of the tip; otherwise into a new crease, or into the crease `into`
names.

`Collapse.mk_sector_geoms` gives each hinge of the tip on a ray a role
(spec `multifold`, "The fan tries each hinge no item fixes both ways"). A flat
hinge of a ray's crease folds. A folded hinge of a ray's
crease keeps or opens, and a hinge of another crease on a ray keeps or
changes; the kernel tries every combination of these, so the work doubles
with each of them. For each combination it moves every face by the
reflections across the changing hinges on a path from a face outside the
tip, found breadth-first, and drops the combination when two paths to a
face disagree or nothing moves. Kawasaki's and Maekawa's conditions at the
vertex run only where the anchor surrounds the vertex on the paper;
elsewhere `Fold_state.make` checks that the paths close.

The layer order of the folded fan is a search over the sides of pairs of
faces (`Fold_state.orders`; Layer order, above), whose units the verb
gives (spec `layer-order`, "A verb gives the units of its fan's layer
search"). For `flatten` and `squash` the faces that share one
motion form a unit, a piece, and the faces the fan leaves in place are one
piece; `reverse` gives the units of its opening (Reverse, below). Two
faces of one unit that overlap keep their side, exchanged where the motion
turns the unit over. The side of two overlapping faces of different units
is open. The letter of an element fixes the side of the two faces at
a hinge of its crease (Sectors, below), and the search decides the rest by
the non-crossing conditions. A face of one piece can land between two faces
of another: on a book fold with the rays marked on both layers, the upper
corner folds in between the upper and the lower layer. The search reads no
order of two faces that lie apart, and it finds a state whose layers lie in
a cycle: `packages/core/tests/cases/collapse/flatten-square-twist.bel`
folds the square twist [@hull2020, §6.5, Fig. 6.12] with one `flatten` of
four fans.

### Fans

`Flatten_fans.run` folds a `flatten` of fan items (spec `multifold`, "flatten
folds several fans in one motion"). It cuts every crease a ray item names into
the paper first,
then resolves each ray item to a line: a line operand to its material
segments, a construction to the line `Axiom.select` keeps, under a fresh
crease id. A fan with `at` has its table vertex at the table position of
that point and its paper vertex at the point; a fan without it, at the one
paper point where the pieces of its named creases pass over the one table
point every ray item passes through. The rays are the halves of those
lines from the vertex: of a segment through the vertex the halves that
hold every point a `&` keeps, of a construction the halves along which a
face lies. A crease that `mark` recorded between two points and that cuts
no face from edge to edge gives its recorded segments, so a ray can start
at a vertex inside a face and end at the other end of the segment. For
two fan items whose rays leave the segment between their vertices out,
and no `up to`, the statement adds it to both under one crease id, the
crease the output clause binds.

A fan with `(up to <flap>)` stands for one fan per layer under its table
vertex, from the topmost down to the layer that holds a face of the flap.
A layer is the faces under the vertex that hold one paper point there,
and it lies above another where one of its faces lies above one of the
other's. Each of those fans stands at the paper point of its layer and
takes the rays of the item. A letter names the side of the paper a crease
folds toward, so a layer that faces the other way than the topmost one
takes each letter the other way round. Where a staying part holds a face
of the stack, the parts that hold the other layers' faces in the same
region stay with it. Of the states, the statement keeps those in which
two faces of the stack in one region that overlap before and after lie
the same way round, or the other way round where the fan turns them over;
an `over` item exempts its pair.

The faces are sorted into regions, one per combination of wedges around
the vertices, with `Collapse.sector_of_poly_opt` per vertex; a face a ray
runs through belongs to none. A ray ends at its far point: a face that only
the line beyond that point runs through lies in the wedge that holds a
point inside the face. Each ray folds the faces of its bundle: for a named
crease, the pieces on the ray that pass through the vertex's paper point
and the pieces on their paper lines beyond it; for a construction, the
faces `Fan_paper.line_faces` gives; for the crease between two vertices,
the faces the paper segment between them runs through. A ray whose named
crease has no piece through the vertex's paper point fails with `<ray>
passes through no point of the vertex`. The statement scores each ray
from its vertex to its far point on the faces of its bundle. A face that
holds the paper points of two vertices or more inside it is cut along all
its rays at once (`Fold_state.subdivide_segments`), into the cells its
edges and the rays enclose, since no single ray cuts such a face from
edge to edge. The hinges of the rays on their bundles split the paper
into parts. The staying part is the one part that holds every staying
point, on a face or its edge; without `staying` the statement fails with
`flatten needs (staying .p)` before any state is solved. The other parts are the tip, and the layer check of one fan applies. On the
petal fold this folds the kite creases in the front layer and in the
layer behind it, which the side edge joins to it, and the crease between
the vertices in the front layer: the state that two reverse folds and a
valley fold reach.

`Collapse.geoms_of` takes the regions as its sectors and finds the motions
and the layer orders as for one fan. The letters of a fan run through Maekawa's
parity only where the layers of its bundles surround its vertex. More than
one state left is an error. One ceiling remains: a statement derives a crease between
vertices only for two fans; with more, the program names each such crease
in both fans.

### Squash

`Squash.eval` folds a `squash` through the same solver
([[reference/model#def-squash|def-squash]]). It reads the folded hinges on the
spine's crease with `Resolve.bundle_segments`, keeps the one whose one paper
end lies on no raw edge (`Fold_state.on_raw_edge`) and whose target lies on
the flap's side of the spine's line, and takes the flap of the upper face at
that hinge as the anchor. The axis is the one of the two angle bisectors of
the spine's line and the target's line (`Geom.angle_bisectors`) that
reflects the spine's far end onto the target's ray. The kernel scores the
axis with `Fold_state.subdivide` as a half-line from the vertex, once on
the anchor's layer and once on the layer under it: two creases on one table
ray, so that the fan has four elements, the spine, the two pieces of the
axis and the target's crease on the anchor's layer, and an even count seeks
no emergent ray. The fan passes the two pieces of the axis, the flanks of
the opened spine, with the letter valley, as a letter item of `flatten`
passes its letter (spec `squash`, "A squash folds both flanks as valleys"). Of
the states the fan folds flat in,
the squash keeps those whose flanks both fold as valleys; with one flank a
mountain the same creases fold a swivel fold, which the explicit fan reaches
with letters. The stayer is a point of the anchor's material beyond the
target's line, away from the spine. Where the anchor has no such
material, `Squash.own_hinges` folds the squash without the solver
(spec `squash`, "The layers a flap is hinged to hold its squash"): the tip is
every piece of the two flaps at the spine, the
hinges of the spine and of the axis change, each hinge on the target's
line between the tip and a face outside it keeps or changes, and
`Collapse.geoms_of` and `Collapse.pipeline_solve` give the states as for a
fan. More than one state fails with `` squash is ambiguous: <n>
realizations ``. Where the squash finds no single state and the flap of
the lower face at the spine has material beyond the target's line, it
fails with the message that names the side: seen from the other side that
flap is the anchor and its material beyond the line holds the squash. The fan passes the spine with the letter valley too: the
spine opens and takes no letter, and a free letter would count each state
once per letter. With a target point, the target's
crease is the one named crease whose paper line passes through the vertex
and the target on the anchor's layer, materialized for the fan. Once the fan has folded, the two pieces
become one crease, the one the output clause binds: `--s` is the whole axis,
and a filter by flap, `--s & #[.p]`, picks its piece on one layer. The trace records the fan as that of a `flatten`,
and the checks of the fan report with `squash` in place of `flatten`.

| message | hint |
|---|---|
| `<l> has no material segment` | |
| `the spine of a squash lies on one crease; <l> names several` | |
| `no folded edge lies on <l>; a squash opens a spine` | |
| `both ends of the spine on <l> lie inside the paper; which one is the vertex is not decided` | |
| `the spine on <l> runs from edge to edge; a squash needs a vertex` | |
| `<target> does not reach the vertex (x, y) of the spine` | |
| `<target> lies on the spine's line` | |
| `<target> lies beyond the spine; the flap cannot reach it` | |
| `squash is ambiguous: <n> flaps have a spine on <l> that lands on <target>` | `name the flap by its spine: (<l> & --e onto <target>) or …` |
| `the target of a squash is one crease; <target> names several` | |
| `no crease lies on the line from the vertex through <p>` | `mark it first` |
| `several creases lie on the line from the vertex through <p>` | |
| `no segment of <target> runs on the flap from the vertex to where the spine lands` | `mark it first` |
| `the flap has no material beyond <target>; nothing holds the squash` | |
| `the axis of the squash does not cross the flap` | |
| `the squash of <l> onto <target> folds from the other side of the model` | `flip first` |

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
| 6 | a face of the tip does not carry the rays after the scoring: it lies outside the layers under the fan and a ray's half-line runs through it, so it lies in no sector | `collapse through unaligned layers` | |
| 7 | the ray count is even and below 4 | `count` | `` use `fold` for n = 2 `` |
| 8 | (odd ray count) no geometric completion closes the vertex at all, on either side | `the derived crease does not close the vertex` | |
| 9 | a ray's far end lies inside a face of its flap, off its raw edges and folded edges; a flat crease there does not end the ray (it would leave a vertex of degree 1 inside the flap) | `crease ends inside the sheet` | |
| 10 | two elements of one crease resolve to the same ray (the same direction from O) | `duplicate ray in collapse` | |
| 11 | Kawasaki fails: where the anchor surrounds O on the paper, the reflection composition around O does not close (exact) [@hull2020](#ref-hull2020) ch. 5; elsewhere no combination of the hinges the fan may change closes its paper paths, which surfaces as check 13 | `vertex not flat-foldable (angles)` | |
| 12 | the statement has no `staying` item (spec `multifold`, "A flatten names the part that stays") | `` flatten needs (staying .p) `` | `name a point in the part that stays` |
| 13 | no realization keeps the stayer still: every candidate × Maekawa pattern died before a stacking closed, the paper-path closure of check 11 included | `no realization keeps the staying flap still` | |
| 14 | two different segment combinations ([[reference/beloch-writes#flatten-and-flip]]) both survive with valid realizations | `` <name> is ambiguous at the vertex `` | `` select a segment with `&` `` |

Checks 7 and 9–11 run against a **candidate ray set**: the given rays, plus
one emergent candidate when the count is odd (Pipeline, below); check 8 is
the odd count finding no candidate at all. They never depend on M/V: the
count floor, the boundary check, duplicate rays and Kawasaki closure are
properties of which lines and directions are given, not of which are marked
mountain or valley. Check 11 runs here only where the anchor surrounds O on
the paper. Elsewhere its test, whether some combination of the hinges the
fan may change closes the paper paths (spec `multifold`, "A fan moves each piece
by the changing hinges on its paper path"), runs per admissible
stayer sector after checks 16 and 6, and a fan that fails it reports
`` no realization keeps the staying flap still ``. A candidate that fails any of them fails for **every**
Maekawa pattern tried against it, and checks 7–11 have no per-pattern
variant. With an odd count their own messages never reach the program: when
no candidate survives, the evaluator reports
`` the derived crease does not close the vertex `` for all of them, unless a
more specific failure stands in the pool (Pipeline, step 4). Check 12
runs once per statement, before any candidate is tried. Check 13 is the
fallback the evaluator reports once every candidate and every Maekawa
pattern has been tried and none produced a live realization (\|S\| = 0,
under Pipeline). Check 14 runs once every segment combination has been
attempted in full: a genuine contradiction between combinations, distinct
from an ambiguity among the states of one combination.

One check concerns the anchor. It is numbered after the others so that
the numbers above keep their meaning. Numbers 5 and 15 stay unused: they
checked a staying point and the flap of `on` against the anchor, and a
`flatten` has no anchor (spec `multifold`, "A fan folds at a point of the paper").

| # | check | shipped message | shipped hint |
|---|---|---|---|
| 16 | the anchor has no face outside the stayer's wedge, so the tip is empty | `the anchor flap has no material outside the staying sector` | |

Four checks concern the stayer (spec `multifold`, "staying names the part that
holds every point"). A candidate fan that fails 17,
18 or 19 contributes no states, and the message surfaces when no candidate
fan contributes any.

| # | check | shipped message | shipped hint |
|---|---|---|---|
| 17 | no sector's closed wedge holds every point of `staying` | `no sector of the fan holds every staying point` | |
| 18 | more than one sector's closed wedge holds them | `the staying points lie in more than one sector` | `add a point inside the sector that stays` |
| 19 | the one sector holds no face of the anchor | `the staying sector holds no material of the anchor` | |
| 20 | the candidate states left for the selection hold different sectors still | `flatten is ambiguous: its candidates hold different sectors still` | `add (staying .p) with .p in the sector that stays` |

The evaluator runs the checks in this order. Checks 1–3 run per element, in
source order, and check 4 once the elements are resolved. Check 12 runs before
the segment combinations. Each segment
combination runs check 8 (odd count only), and each candidate fan of it
checks 7, 9, 10 and 11, then the stayer: checks 17, 19 and 18. Per admissible
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

**Admissible stayer sectors.** Every candidate ray set is tried against the
one fan sector whose closed wedge holds the table images of the staying
points ([[reference/model#def-flatten|def-flatten]], checks 17 to 19). The
evaluator rotates the ray labeling so the sector under test becomes sector 0
before the fan construction runs, which is what anchors `T_0 = identity` on
the stayer (Sectors, below).

1. **Count rays.** Odd → `Flatten.candidates` generates every geometric
   completion that could close the vertex: it tries every angular gap
   between the sorted given rays as the insertion point, keeps the
   candidates whose axis falls in its own gap, and tags each
   `LineNew` (a new line) or `OppositeRay` (the far side of an
   already-given line: degenerate in direction and not in position, it is
   still a real, non-constructible crease). None found → check 8, under Checks.
   Even → no candidate; the given rays are the whole ray set.
2. **Enumerate.** Each **segment combination** ([[reference/beloch-writes#flatten-and-flip]]: one
   chosen segment per element, when a crease carries more than one at O) is
   tried independently. For each surviving combination, at each admissible stayer sector
   (above), the tip is found first: the parts of the paper the fan's hinges
   separate from the staying sector's faces (Fan, above). A face
   of the tip that lies in no sector fails the sector with check 6, and an
   empty tip with check 16; both are M/V-independent. Otherwise enumerate every Maekawa-consistent completion of the *unpinned*
   slots (\|M − V\| = 2 over the rays; a pinned `mountain`/`valley` fixes
   its own slot; a pattern that can't satisfy Maekawa at all is never
   tried) and try each through the collapse oracle: Kawasaki closure
   (checks 7–11, already candidate-level and shared across every pattern,
   where the anchor surrounds O), the stayer sector's admissibility
   (checks 12, 13 and 17–19), the closure of the paper paths where the
   anchor does not surround O, then, per pattern, Maekawa itself where it
   does, self-intersection, and `over`. An `over` pair holds where the face
   of its upper point overlaps the face of its lower point and lies above
   it; no other face of their pieces is compared (spec `multifold`, "An over
   item orders the faces of its two points"). A failing
   pattern contributes one
   of `` Maekawa violated by the stated assignment `` / `` assignment
   forces self-intersection `` / `` contradictory `over` `` to a
   failure pool; a succeeding one becomes a **realization**, deduped
   against the others by observable stacking signature (two attempts that
   place and stack every face identically count once). If literally nothing
   survives across every combination and every admissible sector, that is
   check 13, `` no realization keeps the staying flap still ``.
3. **Segment-choice ambiguity** (check 14). If **more than one** segment
   combination independently produced a non-empty realization pool, the
   statement stops here: `` <name> is ambiguous at the vertex; select a
   segment with `&` ``, naming the element that had the multiple segments.
   Only a single winning combination's pool is decided on.
4. **Decide by \|S\|** (S = every surviving realization of the winning
   combination, pooled across candidates and, per candidate, across every
   admissible stayer sector):

   - S holds the realizations of `LineNew` and `OppositeRay` candidates
     alike; the tag ranks none of them (spec `multifold`, "Every item of a
     flatten is a condition on its states").
   - `(emergent beside .p)` keeps the realizations whose emergent ray
     lies in a wedge of the given rays, sorted counter-clockwise around O,
     that holds the table point of `.p` or has it on a bounding ray
     (spec `multifold`, "emergent beside names the wedge of the emergent ray").
     Leaving no realization where there were some is `` no state has its emergent ray beside
     <point> ``.
   - \|S\| = 0 → infeasible, checked in priority order: whichever of
     `` collapse through unaligned layers ``, `` the anchor flap has no
     material outside the staying sector ``, `` no realization
     keeps the staying flap still `` or the message of check 17, 18 or 19
     appears first in the failure pool
     (checks 6, 16, 13, 17–19); else, odd count, `` the derived crease does not
     close the vertex ``; else (even count) the pool's own dominant
     failure: the first that isn't `` assignment forces self-intersection
     ``, falling back to that, or to `` Maekawa violated by the stated
     assignment `` if no pattern was even tried.
   - \|S\| = 1 → fold it.
   - \|S\| > 1 → an error with a hint (Ambiguity, below).

### Sectors

The faces of the tip are the sectors around O. The isometry of sector $i$
is the composition of the reflections across the rays that bound sectors
$0$ to $i$, counter-clockwise from sector 0, and the evaluator rotates the
ray labeling so that the stayer is sector 0 before the composition runs;
its isometry is the identity, front face up, by construction, and no
sector is anchored orientation-reversed.

`Collapse.effective_valley` reads the letter of a ray off one face in the
stayer-side sector next to that ray. A sector can hold faces of both
orientations: at the second ear of the fish the stayer sector holds the
base strip face up and the first ear's folded stack face down on top of
it, and the first face by array index can be the wrong one and turn a
hinge constraint around. The face the evaluator takes is the one whose
table polygon has an edge from O along the ray's own segment, the layer the
letter is about. Where an element names hinges in several layers, its letter
holds at each hinge whose face on the clockwise side of the ray lies above no
such face of another hinge the element names; the other hinges take the
letter the layer order gives them.

### Ambiguity

More than one realization is `` flatten is ambiguous: <n>
realizations ``. `Flatten.suggest` writes its
hint from the pattern each realization came from, the letter of every
given ray: for up to four realizations an item per realization, a letter no
other realization shares or two that together part it, and above four the
ray whose letter splits them most evenly. A several-fan flatten builds the
same hint. `Collapse` has a
single-result contract of its own, `` ambiguous stacking (<k> orders) ``,
which `flatten` never reaches: it calls `collapse_all` and pools every
realization; the message survives in the module's own tests.

### Reverse

`Action.eval_reverse` realizes [[reference/model#def-reverse|def-reverse]] with
`Reverse.attempts`, the state as it stands, and no scoring of its own
beyond the axis.

The tip is `Resolve.tip_faces`: the anchor's faces with a piece on the moving
side, or every such face when there is no anchor, closed under hinges whose
table segment reaches strictly beyond the axis. The openings are read off
the pairs of overlapping faces. For each spine line, a table line that
carries a folded hinge between two faces of the tip reaching beyond the
axis, the faces of the tip joined by hinges off that line, or by flat
hinges on it, form groups. Two groups of which each lies below the other,
directly or through other groups, by a face that lies below an overlapping
face, merge. A lower half is a set of groups, neither empty nor all, that
holds every group lying below one of its own; it is an opening where some
hinge of the tip crosses from it to the rest, and one of the hinges that
cross reaches beyond the axis. Every hinge that crosses is folded and lies
on the spine line, so a cut crossed by a flat hinge is none.

The fan of a reverse fold is built once, for every opening, by
`Axis_fan.make`. `Fold_state.reverse_fan` cuts each face of the tip that the axis crosses,
with a flat hinge of the new crease between its two pieces, and
`Collapse.geoms_of` moves the pieces beyond the axis by the creases on their
paper paths (spec `multifold`, "A fan moves each piece by the changing hinges on
its paper path"). The cut hinges fold, a hinge that lies on the
axis between the tip and a face that stays changes, and every other hinge
keeps its angle, the hinges on the spine's line included. Every piece beyond
the axis moves by the reflection across it, so one folded state serves
every opening. The vertex of the fan, where the axis meets the spine's
line, plays no part in this, and a reverse fold whose axis runs parallel to
its spine folds the same way. `fold` and `unfold` fold through the same
fan, with their moving set as the tip and one opening (spec `multifold`, "A
fold is the fan at the point at infinity of its axis"). An `unfold` selects a
tip the axis cuts nowhere, so its fan scores no crease.

Each opening is a stacking of that state (`Fold_state.fold_opening`), with
the faces numbered as a fold of the two blocks numbers them: a block placed
at the bottom, the faces that stay, the other block. The units of the layer
search are the faces that stay and each of the two blocks (spec `layer-order`,
"A reverse fold gives three units per opening"):
two faces of one block keep their side, exchanged since the block turns
over, and the lower block lies below the upper one. For `inside`, the lower
block lies over the faces of its body that no face of the body overlaps from
above, and the upper block under the faces of its body that no face of the
body overlaps from below; the three conditions (spec `layer-order`, "Three
conditions decide the side of a layer the moved paper lands on") fix the sides
they decide, and `Fold_state.orders` decides the rest. For `outside`, the
lower block lies below every face that stays and the upper block above
them, and the search only checks the result. The body of a block is its
faces that the axis cuts, whose stationary pieces stay. Where one body is
empty the opening is removed, and where a face of the upper body lies below
a face of the lower body that it overlaps, it is removed as interleaved.

A letter item names hinges by the segments `&` selects from a crease; the
hinges of the tip among them are the ones it constrains. An opening keeps
the letter where each such hinge has it after the fold: the letter it had
before where the hinge does not cross the opening, the other one where it
does. The hinges on the axis are left to the placement.

The states of the kept openings are compared with `Fold_state.rel`: two that
order every overlapping pair of faces alike are one state
([[reference/model#def-flat-state|def-flat-state]]), and the kernel returns
it. More than one state fails with a hint that
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

## Unfold

`Action.eval_unfold` realizes [[reference/model#def-unfold|def-unfold]] on the state
as it stands; its axis is the current table line of the crease it names. The
moving set with a depth is `Fold_state.select_scope`, the selection a fold
with `up to` uses, from the flap `up to` names or else the flap `moving`
names. With `toward` alone, `select_scope` runs from the flap of the
`toward` point in the other direction, and the moving set is every face with
material on the moving side outside its result. The block is reflected with
`Axis_fan.fold_blocks`, placed `Top`, or `Bottom` with `(moving … down)`; it cuts
no face, so the write adds no hinge, and each hinge on the axis between a
moving and a staying face goes to angle $0$.

`fold` refuses its line where `Fold_state.paper_on_both_sides` is false: every
vertex of every face lies on the line or on one side of it.

| message | hint |
|---|---|
| `unfold needs to know which layers turn over the line` | `name a layer that turns with (moving .p), or one that stays with (toward .p)` |
| `a layer that unfold moves runs across the axis, so part of it would not cross it; unfold turns layers over whole` | `fold along the line to crease that layer` |
| `a layer that unfold moves lies flat beside a layer that stays across the axis, …` | `fold along the line: it folds the flat hinges on it and opens the folded ones` |
| `no hinge on the axis lies between a layer that moves and one that stays, so unfold would open none` | `name fewer layers with moving or up to, or a layer that stays with toward` |
| `the layer of <p> that toward names would turn with the moving layers` | |
| `turning these layers over would pierce layer <n>` | `turn the layers the other way with (moving … down) or (moving … up), or name more of them` |
| `unfold takes no (mountain): the direction of its layers goes on moving, as (moving … down)` | `write (moving .p down) to turn the layers below .p with it` |
| `fold takes no direction on moving: …` | `drop it; a fold places its layers with (mountain)` |
| `every layer lies on one side of this line, …, write unfold` (from `fold`) | `unfold (…) (moving .p) turns the layers of .p over the line` |

## Flip

`Fold_state.flip` realizes [[reference/model#def-flip|def-flip]] with the
reflection across the vertical line through the middle of the footprint,
the table polygons of all faces taken together, reverses the face array
and turns every pair of the layer order over. Which line it reflects across is immaterial
for the state up to a motion of the table ([[reference/model#lem-flip|lem-flip]]);
the output enumerates faces by index, so the reversed array is what a
reader of the file sees.

## Annotations

An annotation never changes the geometry (spec `annotations`, "An annotation
never changes the geometry"), and the kernel holds to
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
FOLD documents without `beloch:annotations` and `file_author`.

## Violations

One constructor per check that `Fold_state.make`, `Fold_state.with_rank`
and `Fold_state.with_order` run, each carrying the model statement it
enforces. `Bad_index` and `Bad_line` reject a malformed representation and
answer to no statement of the model. `Bad_rank` rejects a stacking given to
`make` or `with_rank`, and `Bad_order` the pairs given to `with_order`.
`Layer_cycle` reports three faces that share a region and lie in a cycle.

::: {.include api="Fold_state.violation"}
:::
