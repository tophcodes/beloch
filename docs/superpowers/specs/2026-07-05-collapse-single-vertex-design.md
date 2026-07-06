# Single-vertex collapse (`@collapse`) — rabbit ear and friends

Date: 2026-07-05. Status: validated design, pre-implementation.

## Motivation

The rabbit-ear fold is the canonical move Beloch cannot express: two
non-parallel folds executed simultaneously. Each alone is a simple fold; taken
together, their creases meet at a point O and the wedge of paper between them
beyond O is claimed by both folds — paper cannot stretch, so the wedge must
take extra creases and swing through 3D before the sheet lies flat again. The
flat end state exists (Rabbit-Ear Theorem: the three angle bisectors of a
triangle meet at the incenter O, and together with a crease from O
perpendicular to a side the vertex is flat-foldable [hull2020, Thm 8.5]), but
it is not reachable by any sequence of simple folds — the standard example
that flat-foldable ≠ simple-foldable [demaine2007, §14.1.1].

This is a **model extension**, not sugar: a new action kind that jumps from
the (precreased) flat state directly to the flat folded end state, skipping
the 3D intermediate.

## Scope decisions (settled in brainstorm)

1. **Single vertex only.** All folded creases of one `@collapse` share one
   point O. Global multi-vertex flat-foldability is NP-hard [hull2020, §6.6,
   Thm 6.17 — Bern–Hayes 1996]; the single-vertex case is exactly decidable
   and covers rabbit ear, waterbomb/preliminary bases, and (later, at boundary
   vertices) squash-type moves. Multi-vertex collapse (fish/bird base in one
   step) is a follow-up.
2. **Explicit per-crease direction.** The user states mountain/valley per
   element. No M/V inference in the capability layer; intent-style sugar (a
   `rabbitear` def with `toward`) can come later — two-layer principle.
3. **Language defines flat *and* standing end states; evaluator v1 implements
   flat only.** A `standing <flap>` clause is part of the grammar and
   semantics from day one (the language is not the evaluator); the reference
   evaluator rejects it with "standing folds not yet supported" until the 3D
   slice (ADR 0015 rework) lands. No retrofit later.
4. **Redundancy is never an error.** Stating something the kernel could
   derive (a tiebreaker where stacking is unique, a default direction) parses
   and evaluates fine — at most a lint hint (issue #64 category). Only
   *contradiction* is an error.

## Syntax

```
collapse_stmt := "@collapse" element ("and" element)* clauses
element       := "(" element ")"
               | crease_operand ["mountain"]
clauses       := (flap "over" flap)* ["standing" flap]
```

Full form: `@collapse e1 and e2 and … [<flap> over <flap>]* [standing <flap>]`.

- `crease_operand` is the existing material-crease operand (`--name`,
  `at`-projected segments, `#(...)` forms) — exactly what `@fold` accepts.
- `mountain` binds to the immediately preceding element; default is valley —
  the `@fold` convention, applied per element.
- `and` is the list separator (already a token, used in multi-selector `at`).
  No ambiguity: multi-selector `at` is always parenthesized, so a bare `and`
  at element depth is a list separator.
- Parentheses around an element are optional grouping, never required by the
  grammar; they exist for reader clarity on busy elements.
- `over`/`standing` clauses follow the element list (see Semantics).

Rabbit ear, concretely (triangle `.a .b .m` inscribed in the square, bisector
creases `--ba --bb --bm`, ear perpendicular `--e`, `.o` = incenter):

```
@collapse --ba at .a and --bb at .b and --bm at .m
  and (--e at (.o and --(.a .b)) mountain)
```

## Semantics

### Resolution

Each element resolves to exactly **one crease segment** (material resolution
per flap, `at` projection — same machinery as `@fold`). Then:

- All segments share one endpoint O (exact comparison), O strictly interior
  to the paper. Boundary-vertex collapse (squash/petal territory) is a
  follow-up; today it errors.
- Every segment's other endpoint lies on the paper boundary. A folded crease
  ending mid-paper creates a degree-1 vertex that cannot fold flat → error.
- Element count n is even and ≥ 4. n = 2 is a simple fold → error with hint
  "use @fold". Odd n cannot satisfy Maekawa → error.
- Listed segments become folded creases (M/V as stated); unlisted segments of
  the same bundles stay unfolded marks (U). Bundles are already split at O by
  the material `cross` machinery (v0.19), so `at` can select the rays.

### Flat-foldability checks (in order, each with its own error)

At O, with sectors s0..s(n-1) between consecutive rays:

1. **Kawasaki**: alternating sector-angle sum is zero — exact in the qqbar
   kernel [hull2020, ch. 5].
2. **Maekawa** against the stated assignment: |M − V| = 2 [hull2020, ch. 5].
3. **Local validity** of the assignment (big-little-big / Hull's single-vertex
   conditions [hull2020, ch. 8]) — a Maekawa-satisfying assignment can still
   force paper self-intersection.

### State construction

- Faces = sectors around O (each sector carries everything out to the paper
  boundary; paper shape beyond the rays is irrelevant to foldability — only
  the ray angles enter Kawasaki).
- Isometry of sector i = composition of reflections across creases 1..i
  (standard construction, exact). The stayer sector — the one keeping the
  identity isometry — is the table-contact sector: the unique face at the
  bottom of the solved stack (top under `flip` semantics, as with `@fold`).
  Deterministic once the layer order is solved.
  **Deviation (shipped, 2026-07-06):** "bottom of the stack" was wrong — a
  lowest-rank sector with an improper (det<0) transform mirrors the whole
  model (M/V flip). Shipped rule: anchor = lowest-rank *orientation-preserving*
  sector; sector 0 is always identity so one exists. See `SPECIFICATION.md`
  §4.9 (living spec) + final-review finding C2.
  There is **no `moving`
  clause in v1**; if absolute-placement control turns out to be needed
  (holding a different sector fixed), an optional `moving <flap>` can be
  added later without breaking this default.
- **Layer order**: the kernel enumerates valid stackings (single-vertex
  non-crossing condition in the folded angular picture; finite and small).
  Exactly one → done. Several → error "ambiguous stacking (k valid orders)"
  naming the distinguishing flaps, resolved by `over` clauses.
- Reuses the taco-taco/taco-tortilla validity machinery (#47) for the final
  order check.

### Material / layers

`@collapse` operates on the flap stack like `@fold`: v1 rule is
**all-layers** — the stack under the collapse region folds as one unit.
Creases must be material in every affected layer (bind creases are, by
definition). Non-congruent layers through the collapse region → error.
Single-layer paper is the trivial case of this rule.

### Clauses

- **`<flap> over <flap>`** (repeatable): flap operands as in `moving` (a
  point denotes its sector). Orders the two flaps in the final stack.
  Required when stacking is ambiguous; always *allowed* — if redundant it is
  a no-op plus lint hint; if it contradicts every valid stacking it is an
  error.
- **`standing <flap>`** (reserved): the named flap stays unflattened, in the
  symmetric position of the residual 1-DOF mechanism (rabbit ear: the doubled
  wedge stands perpendicular, its mountain crease unfolded). Evaluator v1:
  error "standing folds not yet supported". Exactness note for the 3D slice:
  pinning one dihedral to an algebraic sin/cos makes the remaining dihedrals
  algebraic (spherical-linkage closure is polynomial in sines/cosines), so
  the qqbar kernel can carry standing states.

## Errors (summary)

| condition | error |
|---|---|
| segments share no common point / O on boundary | no common interior vertex |
| n odd, or n = 2 | count (hint: use `@fold` for n = 2) |
| segment ends mid-paper | crease ends inside the sheet |
| Kawasaki fails | vertex not flat-foldable (angles) |
| \|M−V\| ≠ 2 | Maekawa violated by the stated assignment |
| big-little-big / validity fails | assignment forces self-intersection |
| several valid stackings, no/insufficient `over` | ambiguous stacking (k orders) |
| `over` contradicts all valid stackings | contradictory `over` |
| non-congruent layers in collapse region | collapse through unaligned layers |
| `standing` used | not yet supported (evaluator v1) |

Lint (not errors): redundant `over`, other implied clauses (#64 category).

## Examples

1. **`examples/bases/rabbit-ear.bel`** (n = 4, off-center vertex): triangle
   `.a .b .m` on the square (`.m` = top-edge midpoint), three bisectors + ear
   perpendicular precreased, collapse as above. Load-bearing: the resulting
   state is unreachable by `@map`/`@fold`.
2. **`examples/bases/waterbomb.bel`** (or `preliminary.bel`; n = 8, center
   vertex): diagonals + book folds, collapse at the center. Shows n > 4 and
   (expected) the `over` tiebreaker. The correct M/V assignment at the
   8-valent vertex is **not asserted here from memory** — the kernel's checks
   verify it during implementation; cross-check against [hull2020, ch. 5 & 8].

## Testing

- Golden FOLD files for both examples (creasePattern + foldedForm +
  faceOrders).
- Error goldens: one per row of the error table.
- Lint: redundant `over` → hint, not error (if #64 infrastructure exists by
  then; otherwise a spec-noted TODO).
- Property: solved layer orders satisfy the non-crossing condition and the
  taco checks (#47 machinery).
- Render both examples with `tools/fold2svg.mjs` for the PR.

## Follow-ups (explicitly out of this slice)

- `paper triangle` (nicer rabbit-ear demo than the inscribed workaround).
- Multi-vertex collapse (fish base, bird base in one action).
- Boundary-vertex collapse (squash/petal preparation).
- `standing` implementation = the 3D slice (ADR 0015 type rework).
- `rabbitear` sugar def (intent-style, `toward`).
- `not at` ergonomics — only if a real example turns up with no positive
  incidence selector; positive two-selector `at (.o and --(.a .b))` covered
  the known cases.

## Citations

Rabbit-Ear Theorem [hull2020, Thm 8.5]; Kawasaki, Maekawa [hull2020, ch. 5];
single-vertex validity [hull2020, ch. 8]; NP-hardness of global
flat-foldability [hull2020, §6.6, Thm 6.17] (Bern–Hayes 1996 — full paper not
in `refs/`, cited via Hull); simple-fold taxonomy and flat-foldable ≠
simple-foldable [demaine2007, §14.1.1].
