# 2026-07-05 — `toward` as fold direction, not bisector selector

Outcome of questioning spec §4.5's error "`. p` lies on `--l1` or `--l2`
(ambiguous)". The error is an artifact of the *sector semantics* (pick the
bisector whose open angular sector contains `.p`), which itself was a
defensive choice in the axiom-5 slice (`2026-06-29-axiom5.md`), not a
considered one. Converged: replace it with **direction semantics**.

## The model

`--l1` (the folded line) divides the sheet into two sides. `toward X` names
the **target side**: the fold must move the swinging material of `--l1` onto
X's side of `--l1`. X is a point today; anything strictly on one side of
`--l1` (point, line, face) works in principle.

Formally: a candidate crease `b` is selected iff the image under reflection
across `b` of the *moving material* of `--l1` lies on X's side of `--l1`.
One sign computation in the kernel — but it needs the material/scope
information (which piece of `--l1` swings), so `toward` couples to fold
scope (`moving`), not to bisector geometry.

## Why this beats sector *and* nearest-bisector

Kite base, `@map --(.d .a) onto --ac toward .b`:

- **Sector** picks the −22.5° line (`.b` sits in that wedge) — the candidate
  that touches the paper only at corner `.a`. Wrong.
- **Nearest** (pick the angularly closer bisector) *also* picks −22.5°
  (22.5° from `.b` vs. 67.5°). Wrong.
- **Direction**: fold along 67.5° sends `.d` to (√2⁄2, √2⁄2) — `.b`'s side ✓;
  fold along −22.5° sends it off-paper left ✗. Unique, and it is the crease
  the folder means.

All natural target references work: `.b`, `.c` (on `--l2` — legal now), edge
midpoints. Only references **on `--l1`** are errors — and in this model such
a `toward` is also semantically meaningless: you point where the fold *goes*,
not where it comes from. (Under sector semantics the whole of `--l2` was an
error locus too; that was the original complaint.)

Visual walkthrough of all three semantics + failure cases was built as an
artifact during the session (decision maps, kite, straddle, perpendicular,
near-parallel).

## Why side-of-l1 alone is not enough: material

For the *infinite* line, each candidate fold sends one ray of `--l1` to each
side — side-of-l1 cannot discriminate. What makes it unique is the
**material**: the crease/edge segment that actually swings (ADR 0014
segments + fold-scope `moving`). In the common case — hinge (the l1∩l2
intersection) at the *end* of the material, e.g. a corner — exactly one
piece swings and direction decides.

## Residual ambiguity: the straddle case

If the intersection lies in the **interior** of `--l1`'s material (diagonal
onto diagonal: M = sheet center), the two candidates swing *different*
halves of `--l1`, and both images are the same segment (M–b) on X's side —
`toward .b` is satisfied by both. Whether it is genuinely ambiguous depends
on `moving`:

- `moving .c` → unique (vertical candidate would swing M–c *away* from `.b`);
- `moving .d` → ambiguous (`.d` is in the top *and* the left flap, so each
  candidate swings its matching half). Error with a clear message.

Sector (corners lie on the lines) and nearest (corners equidistant) fail in
this configuration too, so this is no regression — it is the model's honest
residual case.

## Open questions

- **Bind position** (`--x = map --l1 onto --l2 toward .p`): nothing moves.
  Candidate rule: material = `--l1` clipped to the paper, then the same
  test; hinge-at-endpoint binds (the common case) stay unique. Not settled.
- **Axioms 6/7 selectors** (`toward .x` on `MapThrough`/Beloch fold): same
  rethink applies — candidates there are creases, and a direction reading
  ("which way does `.p` move") may replace the current metric pick. Separate
  pass.
- **Relation to paper-incidence filtering**
  (`2026-07-05-axiom5-paper-incidence.md`): complementary, not competing.
  Incidence filter runs when `toward` is *omitted* (drop zero-length
  candidates); direction semantics defines what `toward` *means* when
  present. Kite needs no `toward` at all once the filter lands.
- **Spec impact**: §4.5 error list ("`.p` lies on `--l1` or `--l2`") is
  wrong under this model — becomes "X lies on `--l1`" plus the straddle
  error. Rewrite when the slice happens. (done: v0.19-dev slice)

## Follow-up (separate topic, raised at the end of the session)

Partial creasing — "crease only a section of the line, select a
segment-bundle to fold": mostly covered by existing pieces (`pinch` for
single-segment creation, `at` for segment selection, `@fold` + fold scope
for folding along existing segments). The genuinely new sub-case would be a
crease *ending mid-face while staying folded* — not flat-foldable, likely
stays out of the language. Needs its own note if pursued.
