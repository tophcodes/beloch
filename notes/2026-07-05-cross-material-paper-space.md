# `cross` is material: crossings live in paper space (v0.19-dev)

**Trigger.** Toph read §4.3's v0.7-dev rule — "the intersection is a table-space
point; it resolves to the material point on the topmost layer (Q2-B)" — and
called it out: we don't want table-space coordinates as values at all.
Everything the language *names* should be paper space.

## The argument that killed Q2-B

Paper is **opaque**. The topmost-layer rule imagined "the point your hand would
touch" — but the topmost face covering the table spot may carry *neither* of the
two creases. You cannot see a mark through a flap; a "crossing" that exists only
because layers overlap on the table shows on **no** layer. Physically, to use a
buried crossing you'd first have to fold the buried crease up to a visible
layer — and in material semantics even that is unnecessary: scars never move
within the sheet, so their crossing exists in paper space regardless of the
current stacking.

Confirmed by the code: `topmost_preimage` picked the top face covering the
table point with no check that either crease lay on it. `fold-top-two.bel`'s
`.q = cross --v --bot` (bottom edge!) resolved to paper `(1/2, 1)` — a point on
the **top** edge of the sheet. The material rule gives `(1/2, 0)`.

## The rule

`cross` intersects the two operands' **paper-space material lines**:

- A crease operand qualifies bare iff all its segments lie on **one** paper
  line (`Fold_state.crease_paper_axis`). Table-bent is fine — a scar subdivided
  by later folds stays collinear *in the paper*. Scored through several layers
  → mirror-image scars on different lines → error, project with `at`.
  (So the old "bent bundle needs `at`" cross-test *inverted*: bare
  `cross --b --v` on a table-bent scar now succeeds.)
- The crossing must lie **on the marks** (some segment's chord, endpoints
  count) — supporting lines meeting beyond the scars is nothing on the sheet.
- `--(.p .q)` operands are paper lines through material points; reference-only
  boundary creases (cut no face) fall back to their birth line. Both only need
  the crossing on the paper.
- Result: `cross` is **fold-state-independent**; only `at` projection reads
  the folded state.

Table space survives *only* as transient geometry inside axiom evaluation
(fold axes align current table positions) — never as a value.

## Fallout

- Def line params: a named-crease argument now passes the `Material` crease
  value through instead of freezing its table line at apply time (`cross`
  inside a body needs marks; ADR 0016 had flagged the freeze as a smell).
- `crease_segment` gained paper endpoints `pa`/`pb`; `topmost_preimage` and
  its `order`-consulting machinery deleted.
- `test_eval_up_to_wrong_side` had silently relied on the table fiction
  (crossing a top-flap hinge with the bottom edge); rewritten with a flat
  precrease.

Spec: §4.3 rewritten, §4.8/§5a.3/§8 touched. See also
`notes/2026-07-03-crease-layer-selection.md` ("all points are material") and
ADR 0014/0016.
