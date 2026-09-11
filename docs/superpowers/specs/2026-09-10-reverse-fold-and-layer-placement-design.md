# Reverse fold and layer placement (design)

## Status

Draft for review (2026-09-10, with Toph). Decisions taken in the brainstorm
that this spec builds on, recorded in
`notes/2026-09-10-crane-path-reordered.md`:

- The crane path is Inside Reverse Fold → Bird Base → Crane (route A). The
  end-to-end target of this slice is the preliminary base by the Eos route:
  one diagonal fold and two inside reverse folds.
- The reverse fold is its own verb, defined as Ida's two mirror half-folds
  [ida2020, §7.4.3]. Its mountain/valley letters are derived (ADR 0011), so
  Fisher's `reverse` specifier [fisher1994, §3.3.2] has no counterpart.
- The kernel gets the general layer placement (Ida's `InsertFace`
  [ida2020, App. B.2], Fisher's `tucking A under B`) from the start, and the
  language exposes it on `fold` in the same slice.

## Motivation

`Fold_state.fold` reflects a moving block across a table line and places it
at one of two positions: on top of everything for a valley fold, under
everything for a mountain fold. Every maneuver that puts moved paper *between*
existing layers is unreachable that way: a flap tucked into a pocket, and the
reverse fold, where each half of a tip lands next to its own hinge layer.

Three systems name the same primitive. Eos's general fold command takes
`InsertFace → f`, "insert the moving faces below (above, for a mountain fold)
face f". Fisher's language has a `tuck` command and `tucking A under B` on
multiple folds. eGami lists valley-under and mountain-under as tools distinct
from valley and mountain [fastag2009egami, Table 1]. The placement is the
primitive; the reverse fold is one use of it.

## Language design

### Grammar

```
crease_stmt   += "reverse" markable reverse_spec
               | "reverse" CREASE_NAME "=" axiom reverse_spec
reverse_spec  := [ "moving" flap_operand ] [ "outside" ]

fold_spec     := [ "moving" flap_operand ] [ "up" "to" flap_operand ] [ "mountain" ]
               | [ "moving" flap_operand ] placement
placement     := ( "over" | "under" ) flap_operand
```

- `reverse` is a disposition verb beside `mark`, `fold`, `flatten`, `flip`
  (§4.10): it writes to the paper. It takes the same `markable` as `fold`: a
  motion, computed in the table frame, or an existing material crease. It is
  bindable like `fold`.
- `moving` on `reverse` names the tip (below). It is implied on a map fold
  from the moved point, exactly as for `fold`; a line-construction motion or
  a material crease requires it.
- `outside` selects the outside reverse fold. The default is inside.
- A placed `fold` takes `over` or `under` with a flap operand (the same three
  forms `moving` accepts). `mountain` with a placement is a parse error: the
  placement fixes the direction. `up to` with a placement is a parse error in
  this slice: a placed fold moves the anchor flap only (below).

### What a placed fold does

`fold <axis> moving <A> under <T>` reflects the anchor flap's material beyond
the axis across it, as any fold does, and inserts the moved block into the
stack immediately below the flap `T` instead of at the outside. `over` inserts
immediately above. Everything else about the fold is unchanged: the crease
it scores, the material it subdivides, the derived letters.

- **Moving set.** The faces of the anchor flap(s) with a piece on the moving
  side, closed under coplanar clusters (ADR 0017). No outer-prefix rule: a
  tuck passes through a pocket that opens for it, so the collision-free
  rotation argument that justifies the prefix rule [demaine2007, §14.1] does
  not apply. Whether the end state is a legal flat folded state is decided by
  the kernel's invariants, as for every other write.
- **Direction.** Never stated and never computed as an input. The placement
  fixes the block's rank; the crease's letter is then the derived
  mountain/valley of the finished state (rank and orientation, §4.6, ADR
  0011). Tucking a corner under its own layer reads valley when that layer
  lies face-down, mountain when it lies face-up: the same placement, two
  letters, decided by the paper, not by the keyword.
- **Target resolution.** `T` resolves by incidence to a coplanar cluster. It
  must be stationary, and it must overlap the footprint the moved block lands
  on; a target that covers none of the landing area cannot be inserted
  against.

The plain `fold … mountain` and `fold …` (valley) keep their meaning: they
are the placements "outside, below" and "outside, above" and keep the
outer-prefix moving set.

### What `reverse` does

Take a flap folded along a crease, the *spine*, so that two layers lie on
each other; choose a line across it meeting the spine at O; the *tip* is the
material beyond that line. An inside reverse fold pushes the tip in between
the flap's layers; an outside reverse fold wraps it around them. In both, the
spine beyond O ends up folded the other way.

Beloch defines the end state, in the table frame, as Ida's split-and-merge
[ida2020, §7.4.3] without the split: the tip is cut into two halves at the
spine, both halves are reflected across the line in one operation, and each
half is placed relative to its own hinge layer.

- **Tip.** The connected piece of material beyond the line that carries the
  anchor: the anchor flap(s)' faces with a piece on the moving side, plus
  every face with a piece on the moving side reachable from them through
  hinges lying beyond the line. Other material beyond the line, stacked there
  but not joined to the tip, stays.
- **Halves and spine.** The tip's internal hinge graph is cut at one folded
  hinge; the cut must leave exactly two components, the halves. Each half's
  *hinge layers* are the stationary faces it is cut from along the line. The
  two halves' hinge layers must occupy two separate rank ranges in the
  landing footprint, one entirely above the other; call them the lower body
  and the upper body.
- **Placement, inside.** The half hinged to the lower body is inserted
  immediately above the lower body's topmost layer; the half hinged to the
  upper body immediately below the upper body's bottommost layer. Both land
  in the same gap, each next to its own body.
- **Placement, outside.** The half hinged to the lower body goes under
  everything in the footprint; the half hinged to the upper body on top of
  everything.
- **Which hinge is the spine.** Every folded hinge of the tip that reaches
  beyond the line (its far part is what reverses; a hinge lying entirely on
  the stationary side is no spine, so a line parallel to the crest finds
  none) and whose removal leaves two components is tried; for each, the
  placement above is attempted and the kernel's invariants decide. Exactly one survivor is the fold. None
  is an error, more than one is an error asking to fold less (a selector for
  the spine is deferred; the crane never needs one, since a tip with a single
  crest has a single cut).
- **Letters.** Nothing is stated. Each half flips over and keeps its rank
  position relative to the other half, so at the spine beyond O the backs of
  the paper now face each other where the fronts did: the derived letter
  reverses. The line's own crease reads, on both halves, the letter the
  spine had before the fold for an inside reverse and the opposite letter
  for an outside reverse (Maekawa at O: three of one kind, one of the
  other). For a valley spine that is V, V inside and M, M outside, which is
  the four-way table from the brainstorm: the simple fold keeps the halves
  together and the spine's letter, the reverse folds separate them and
  reverse it.

A reverse fold is not two placed folds in sequence. After one half has moved,
the spine hinge joins a reflected face to an unreflected one along no common
segment, which is a torn sheet; the kernel rejects it. The two halves move in
one operation or not at all. (The brainstorm counted "`reverse` equals two
tucked folds" as an end-to-end test. It is not one; the equivalence holds
inside the kernel, as one multi-block fold, and is tested there.)

### Examples

```
; pocket tuck: fold in half, then tuck the top layer's corner between the layers
paper square
fold map .a onto .d                       ; bottom half up: two layers, hinge on top
fold through .m .n moving .b under .p     ; corner of the top layer, between the layers
                                          ; (.p a point on the top layer's remaining part)
```

```
; preliminary base, Eos route [ida2020, Fig. 7.19, steps 1-3], first fold
; along --bd so the tacos land at .b and .d as in examples/bases/preliminary.bel
paper square
fold map .a onto .c                       ; diagonal --bd, triangle; a lands on c
reverse map .b onto .c                    ; tip b between the layers, crease --h through O
reverse map .d onto .c                    ; tip d likewise, crease --v
```

The second program must produce the preliminary base of
`examples/bases/preliminary.bel`: the same outline and the same per-side
stacking. The diagonal `--bd` is folded once and then reversed beyond O on
both halves, so the `b`- and `d`-quarters are the tacos and the `a`- and
`c`-quarters the flat front and back, as in the `flatten` version. The
diagonal `--ac` is never creased on this route.

## Kernel design

### Placement in `Fold_state.fold`

```ocaml
type placement =
  | Top                 (* outside, above everything in the footprint *)
  | Bottom              (* outside, below everything *)
  | Over of int        (* immediately above this stationary face's child *)
  | Under of int        (* immediately below it *)

val fold :
  ?crease_id:int ->
  blocks:(bool array * placement) list ->
  t -> axis:Geom.line -> move_side:int -> prov:State.provenance option -> t
```

`blocks` replaces `?moving_parents` and `~valley`. Each block is a set of
parent faces to move and where its reflected material goes. The cut,
reflection, new axis hinges, carried hinges and the on-axis toggle are
unchanged and run once over the union of all blocks. The rank rebuild
generalizes step 4 of today's `fold`:

1. Stationary faces keep their relative order.
2. Each block's faces are ordered by reversed parent rank (a rigid half-turn
   reverses a stack), and the block is spliced in as one contiguous run.
3. `Top` and `Bottom` splice at the ends; `Over f` splices immediately after
   `f`'s stationary child, `Under f` immediately before it. Two blocks aimed
   at the same gap from opposite sides keep their sides: the `Over` block
   sits next to its face, the `Under` block next to its face.

`simple_fold` keeps its signature and calls `fold` with one block placed
`Top` for a valley fold and `Bottom` for a mountain fold. A single-block fold
with `Top`/`Bottom` must reproduce today's rank rebuild exactly; the existing
goldens are the check.

`make` runs on the result as for every state. `Taco_taco` and `Taco_tortilla`
are what reject an impossible insertion; the evaluator maps them to the
user-facing messages below.

### `reverse` in the kernel

```ocaml
val reverse :
  ?crease_id:int ->
  t -> axis:Geom.line -> move_side:int -> tip:bool array -> inside:bool ->
  prov:State.provenance option ->
  (t, reverse_failure) result
```

Computes the tip's internal folded hinges that reach beyond the axis,
enumerates the single-hinge cuts with two components, derives each half's hinge layers and the two bodies,
builds the two blocks with their placements, and calls `fold`. Failures:
`No_spine`, `Several_spines of int`, `Bodies_interleaved`, and the `make`
violation of the one candidate that had a placement. Lives in `Fold_state`
next to `fold`; the evaluator's `reverse` handler resolves operands and
reports.

### Evaluator

- `Ast.fold_spec` gains `place : (over_under * flap_arg) option`; the parser
  rejects `mountain` and `up to` beside it.
- A new `Ast.reverse_spec = { moving : flap_arg option; outside : bool }` and
  a `Reverse` statement, resolved through `resolve_markable` like `fold`.
- `Resolve` gains the target-flap resolution for placements (a cluster that
  must be stationary and overlap the landing footprint) and the tip closure
  for `reverse`.
- Derived M/V, FOLD emission and the crease-pattern frame are untouched: the
  letters come from rank and orientation as before.
- Module budget (ADR 0018): `eval.ml` stands at 799 lines against a ceiling
  of 900. The `reverse` handler in `Eval` is a resolve-and-call function like
  `run_fold`; the tip closure and the placement-target resolution live in
  `Resolve`, the spine search and both placements in `Fold_state`. Nothing
  geometric goes into `Eval`.

## Errors

| situation | message |
|---|---|
| `mountain` with `over`/`under` | `a placed fold derives its direction; drop mountain` |
| `up to` with `over`/`under` | `a placed fold moves the anchor flap only; up to is not supported here` |
| target flap moves with the fold | `` the placement target moves with the fold; name a stationary flap `` |
| target does not cover the landing area | `` <T>'s flap does not cover where the moved material lands `` |
| insertion violates the layer invariants | `` placing the moved material under <T> would pierce layer <n> `` (`over` likewise) |
| `reverse` finds no cut | `reverse needs a tip folded along one spine; the moving material does not split into two halves` |
| `reverse` finds several valid cuts | `the tip can be reversed at <n> spines; fold less so that one remains` |
| halves' hinge layers interleave | `the two halves are hinged to interleaved layers; that is not a reverse fold` |
| reverse placement violates the invariants | `` reversing the tip would pierce layer <n> `` |

## Acceptance

1. **Kernel, placement.** `test_fold_state`: a three-layer strip; one block
   placed `Over`/`Under` the middle layer lands in the middle with reversed
   internal order; `Top`/`Bottom` reproduce `simple_fold` bit for bit on the
   existing fold goldens (no golden changes).
2. **Kernel, reverse.** A square folded in half, `reverse` across a line
   through the spine: four faces beyond the line, stack order body-L, tip-L,
   tip-R, body-R for inside and tip-L, body-L, body-R, tip-R for outside;
   `mv` on the spine's far hinge is the opposite of the near hinge; the new
   hinges read V, V (inside) and M, M (outside).
3. **Language, pocket tuck.** The tuck example above as a golden; the same
   fold with `mountain` instead of `under .p` wraps around the outside and
   differs only in `faceOrders`.
4. **Language, Eos route.** The two-`reverse` preliminary base program as an
   example with a golden, plus an e2e test that compares its folded frame
   with `examples/bases/preliminary.bel`'s by *outline and per-side stacking*:
   the set of table polygons agrees as sets, and for every table footprint
   the order of the faces covering it agrees after matching faces by their
   table polygon. Face and order counts are not the criterion (the
   note records why).
5. **Language, letters.** In the Eos-route golden, the diagonal's half-creases
   beyond the two reverse vertices carry the opposite letter from the halves
   near the first fold, with nothing in the source saying so.
6. **Spec.** §4.6 gets the placement paragraph and grammar; a new §4.6a for
   `reverse`; Appendix A and B updated; the version note under the next
   `-dev`.

## Non-goals

- A selector for the spine when several cuts are valid; `up to` on placed
  folds and on `reverse`; the bird base (#32) and the crane (#35).
- Squash, petal, sink, `unfold`: squash and petal are `flatten`-shaped
  (layers separate, several creases at once), a closed sink is no fold at
  all.
- Any motion check. Whether a tuck or a reverse can be performed without
  bending paper is a 3D question (ADR 0015); the kernel validates the flat
  end state only.
- Multi-hinge spines (a tip whose halves are joined along two collinear
  hinges): not needed for the crane, error today.

## Migration

Additive. No existing program changes meaning; no golden changes.
