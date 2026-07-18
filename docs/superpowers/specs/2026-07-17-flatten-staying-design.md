# flatten stayer anchoring: order convention + `(staying)` (design)

## Status

Approved direction (2026-07-17, with Toph). Supersedes issue #52's
two-pipeline-union plan (`collapse_pipeline ~mirror` + dedup) — that plan
compensated in the evaluator for information the language never stated. This
design states it. Builds on `fix/flatten-anchor-parity` (flat-hinge
taco-tortilla check `ab8aa12`, segment guard `f3361d7`); **deletes** the
improper-anchor reversed-rank fallback (`1a4f6d9`).

Empirical grounding: `notes/2026-07-17-flatten-parity-origin.md` — sector
parity keyed to `sort_ccw`'s absolute angular origin starves the stacking
enumeration (16 of 24 sector chains at the fish's second ear, the missing 8
reversal-closed and containing the physically true chain).

## A′ amendment (2026-07-18, approved)

The flatten **tier system is removed entirely**. Grounded in
`.superpowers/sdd/task-51-report.md`: pooling the two tiers into one selection
stage (issue #51's ask) makes the `OppositeRay` position class strictly
dominate the `LineNew` class in the `{toward}` centroid-dot at every
rabbit-ear/swivel-rabbit vertex, so the genuine ear becomes unselectable by any
`{toward}` — the tier mask was load-bearing, and no in-scope rule reconciles
"fish-wants-OppRay" with "rabbit-ear-wants-LineNew" while both are derived. A′
resolves this by never deriving the OppositeRay at all:

- **Derive produces `LineNew` candidates ONLY** (`Flatten.candidates`). An
  OppositeRay completion lies on a given crease's own line — it is
  constructible/material — so it is **stated as a further element**, not
  derived. The fish base becomes an even-count statement with no derive:
  `flatten (--l1) (--l2) (--ray & .a) (--ray & .c) {toward .d}`. (The two-ear
  fish is two such ears; each ear's odd 3-ray form derives its genuine LineNew
  rabbit-ear crease — unchanged by A′, still green.)
- **Tier machinery removed**: the `` `Tier1``/`` `Tier2 `` tags, the
  partition/mask (`deciding = if tier1 <> [] then tier1 else tier2`), and all
  tier references in errors/spec prose. Selection is the existing three stages
  over the now single-class pool.
- **Stayer-region rule amended to ≤1**: at most one ray — given or emergent
  alike — may lie strictly inside the leading pair's stayer arc; that ray is
  the splitter `{toward}` picks a side of. Two or more inside → the combination
  dies. This replaces the asymmetric "any given ray inside kills, emergent
  allowed" rule. A consequence, correct under A′: a bare `(--ray)` 3-ray
  statement whose lone given ray sits inside the arc is no longer killed for
  that alone, so both segment combinations can close and the statement is
  genuinely ambiguous — the existing `&`-suggestion error fires (the migration
  is to give the spine an explicit `&`, i.e. the even fish form).

Task-51 Blocker B (the `--l4 has no material segment` #48 kernel wall) was
specific to the reverted *pooling* experiment; it does **not** manifest under
A′ — the two-ear fish (`flatten-two-ears-sequential.bel`, derive-13) stays
green with the classic `faces = 12` assertions.

## Motivation

Determinism by convention, not solution-space guessing. Toph: `()` items
state constraints that filter the solution space down to a few realizations;
`{}` selects among what survives. The one fact the solver was missing — which
material does not move — becomes part of what the statement says, and the
sector-parity bookkeeping anchors on it geometrically. The arbitrary
east-origin loses all semantic load; the mirror-world bug becomes
inexpressible rather than compensated.

Design principle (standing directive, 2026-07-17): existing tests, goldens,
and spec prose do not constrain this design. Spec §4.9's "the stayer is the
lowest face-up sector of the solved stack" was agent-invented, not a user
decision, and is replaced wholesale.

## Language design

### Grammar

```
flatten_stmt  := [ CREASE_NAME "=" ] "flatten" flatten_item+
flatten_item  := "(" flatten_elem ")"
               | "(" over_flap "over" over_flap ")"
               | "(" "staying" flap_operand ")"
               | "{" "toward" point_operand "}"
flatten_elem  := line_operand [ "mountain" | "valley" ]
over_flap     := point_operand | "#[" point_operand+ "]"
```

- **Element order is semantic.** The first two *elements* (non-element items
  — `over`, `staying`, `{toward}` — do not count and remain position-free)
  determine the stayer by convention (below). The spec's "items may appear in
  any order, interleaved freely" is dropped for elements.
- **`(staying <flap>)`** replaces the reserved `standing` clause slot. A bare
  point `.a` is short for `#[.a]`; the operand is the full `flap_operand`
  (point, line, `#[...]`) exactly as `moving` takes (§4.6). At most one per
  statement; a second is a parse error (`only one staying clause per
  flatten`).
- **`standing` is removed entirely** — grammar rule, `standing folds are not
  yet supported` error, and the spec's standing paragraph. The 3D standing
  end state returns under its own name when 3D lands (ADR 0015 / #48); no
  successor name is chosen now.

### The stayer convention

**Definition.** The *stayer* is the material that does not move: identity
isometry, front face up, exactly where it lay before the flatten. Its final
stack position is a *consequence* of the M/V pattern, not part of the
definition — a rabbit ear stacks everything on top of its stayer, but a
mountain at the stayer's edge folds the neighbor *underneath* it. (The old
"lowest face-up of the solved stack" had the implication backwards: that was
a derivation heuristic, not a definition.)

**Convention.** Without `(staying …)`, the stayer region is the <180° arc at
the vertex between the *folded rays* of the first two elements. With
`(staying X)`, X's material is the stayer and element order carries no
stayer meaning (a `staying` that merely restates the convention is a lint
candidate, never an error — Example-Discipline line: redundancy is not an
error, contradiction is).

**Vertex.** O is the common interior endpoint of all resolved element
segments, as today (checks 8ff). The convention adds no separate vertex rule;
`.(--c1 * --c2)` and the shared-endpoint rule agree wherever both apply.

### Segment inference — `&` becomes mostly unnecessary

A crease bundle whose material carries two segments at O (a through-running
line, subdivided at O) previously *required* `&`. Under the stayer filter the
wrong choices die on their own (Semantics, below), so:

```
flatten (--l1) (--l2) (--ray) {toward .d}
```

resolves fully bare at the fish vertex. `&` stays legal, and stays *required*
only where distinct surviving candidates contradict each other after all
filters — the error then suggests it (Errors, below).

## Semantics: the stayer is a hard filter

> **Stayer rule.** A realization survives iff its unmoved sector lies within
> the stayer region — the <180° arc between the first two elements' folded
> rays (convention), or the sectors carrying the `staying` flap's material
> (explicit).

Consequences, in solver candidate terms (candidate = ray set incl. the
emergent, per M/V pattern):

- **Another element's ray inside the stayer region kills the candidate** —
  material that stays put cannot carry a folding crease. This is what makes
  bare through-crease operands resolve: at the fish vertex, the candidate
  that folds `--ray`'s c-side segment has that ray inside the b/d-bisector
  arc → dead; only the a-side segment survives. No `&` needed. (The c-side
  ray still re-enters as the `OppositeRay` *emergent* — the spine is the
  diagonal's continuation; an emergent inside the stayer region is allowed.)
- **Even ray count** (all rays given): the stayer arc is exactly one fan
  sector → the anchor is unique.
- **Odd ray count** (emergent derived): the emergent may fall inside the
  stayer arc and split it into two fan sectors — one per mirror world. Both
  are legitimate stayer candidates; `()` has filtered to ≤2 and `{toward}`
  selects: the spine extension through O lies in the stayer region, splits
  the paper, and the toward-point picks the side the moving material lands
  on (equivalently: the position-class dot-max already implemented).
- **Collinear first two elements** (opposite rays of one line — both arcs
  180°): the convention cannot pick a side; `(staying …)` is required
  (Errors).

## Solver design

Per candidate and M/V pattern:

1. **Admissible stayer sectors** = fan sectors inside the stayer region
   (1, or 2 iff the emergent splits the conventional arc), or the sectors
   carrying the `staying` material.
2. **Anchor the fan labeling at the stayer**: for each admissible sector
   `s`, rotate the ray labeling so sector 0 := `s`; `sector_isometries`
   then yields `T_s = identity`, face-up *by construction*.
   `effective_valley`, `intra`, `ray_assign`, and `over` all read this
   labeling — consistent automatically. `sort_ccw`'s east origin becomes
   internal enumeration order with zero semantic load.
3. **Anchoring**: root = a face in the stayer sector, base = its
   `face_iso`. Deleted outright: the proper/improper preference walk and
   the improper-anchor reversed-rank fallback (`1a4f6d9`), and #52's
   planned two-world union + signature-dedup-as-world-merge. The in-bounds
   check stays; failing it is an honest `e_out_of_paper` for that
   realization, not a fallback trigger.
4. **Pool and select**: realizations from all admissible stayer anchors
   (≤2 per candidate) join the pool; `{toward}` selects via the existing
   three-stage selection. Signature dedup remains as hygiene against
   pattern-duplicates only.

**Orientation representative — per ray, crease-adjacent.** `effective_valley`
needs the parity of the stayer-side sector at each crease. A single
representative *per sector* (the old first-face-by-index `sector_iso`) is wrong
when a sector is **mixed-orientation**: at the fish's second-ear vertex the
stayer sector holds both the stationary base strip (`det>0`) and the first
ear's folded stack (`det<0`) riding on it, and first-by-index surfaced a folded
`det<0` face, flipping one hinge constraint and starving the true stacking
chain. Instead, for ray `j` the representative is the face in the stayer-side
sector `l = (j-1+n) mod n` whose table polygon has an edge running from O out
along the ray segment — the layer the crease's M/V letter is actually about.
Ties (a through-folded multi-layer crease, not in today's corpus) take the
lowest prior rank and are #48 territory; if none qualifies the code falls back
to first-in-sector rather than raising. This reads parity from the
crease-adjacent base layer, so the mixed sector no longer inverts the constraint.

`valid_srank` is untouched — its checks read layer order through betweenness
and were never parity-sensitive (variant experiment, see the parity note).

## Errors

| situation | error |
|---|---|
| first two elements collinear (no <180° arc) and no `staying` | `` collinear leading creases don't pick a stayer; add (staying <flap>) `` |
| no realization keeps the stayer still (all die on taco/self-int/bounds) | `` no realization keeps the staying flap still `` |
| `staying` flap has no material at the vertex fan | `` the staying flap does not touch the vertex `` |
| surviving candidates still contradict on a segment choice | `` --<name> is ambiguous at the vertex; select a segment with `&` `` |
| second `staying` clause | parse error `` only one staying clause per flatten `` |

Removed: `standing folds are not yet supported` (clause gone). Exact final
wording of new texts settles at implementation; the table's error *cases* are
the contract.

## Migration

- **Element order is now semantic** — every existing `flatten` statement is
  reviewed. The fish statements already lead with the two bisectors (correct
  stayer); their `&` selectors on the first two elements and on `--ray`
  drop.
- **Waterbomb-geometry cases are deleted, not migrated** (Toph: wrong
  anyway): `collapse-all-valley.bel`, `collapse-ambiguous.bel`,
  `collapse-ambiguous-over.bel`, `collapse-standing.bel` (also dead via
  `standing` removal). The remaining error cases (`collapse-duplicate-ray`,
  `collapse-kawasaki`, `collapse-midpaper`) keep their error contracts;
  rebuilt on non-waterbomb geometry if their current geometry trips the
  collinear-stayer error first.
- **Spec §4.9 rewritten**: grammar block, stayer definition (does-not-move,
  not lowest), convention + `staying` clause, `standing` paragraph deleted,
  checks table updated, "items in any order" scoped to non-element items.
- **Issue #52 rewritten** to this model (title and plan); the branch note
  gains a pointer here. **#51 (tier pooling) stays a separate slice**; its
  red trio stays red through this slice.
- `e_midpaper`-killed patterns from the parity note get re-examined after
  the fix (side-finding; interacts with #51).

## Acceptance

- `flatten-two-ears-sequential.bel` green: the true chain (stationary strip,
  wings, ear) is enumerated and survives; ghosts stay dead (taco checks
  unchanged).
- `test_flatten` derive-13 green.
- Single-ear flatten cases (`flatten-rabbit-ear-*`, `flatten-fish-*`) green
  after their statements are migrated to convention order; behavior changes
  beyond stayer determinism are findings to review, not noise.
- New cases: element order is load-bearing (swapped leading elements change
  the result or error); `(staying …)` overrides the convention; redundant
  `staying` is accepted silently; collinear leading elements error without
  `staying`.
- `rg standing` finds no grammar/eval/spec references (only ADR history and
  this doc).

## Non-goals

- **Rabbit-ear sugar** (give two bisectors, infer spine ray + fourth ray by
  symmetry, M-side via `{toward}`): separate slice; this design gives it the
  stayer foundation. Two-layer principle: capability first, sugar follows
  fold frequency.
- **#51 tier pooling** and its three pinned-red tests.
- **3D standing end state** and its future name.
