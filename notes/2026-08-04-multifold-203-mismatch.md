# Multifold: the 406-vs-203 mismatch, resolved

Investigation of a mismatch found during the initial pipeline pass: the
k=2/no-AL10 pipeline produced 406 strict symbols against the paper's
203 [alperin2006, l. 541–542], with 205 extras and 2 missing (AL4a9,
AL4ab). Every discrepancy is now accounted for, and a corrected ruleset
reproduces the fixture's no-AL10 slice **symbol-for-symbol: 203 = 203**
(verification at the end).

## Verdict

Three independent defects, one residual caveat:

1. **`Combo.separable` is too narrow.** Definition 10's separability
   [alperin2006, l. 467–468] is *sequential*, not a 2+2 bipartition: if any
   sub-multiset of single-fold alignments determines one fold on its own,
   the combo is two 1FAs in sequence. Kills **160** extras.
2. **Fold-equivalence (Def. 12) in the presence of AL1 is not
   canonicalized.** AL1 forces the folds perpendicular, under which AL5/AL8
   rewrite to single-fold alignments, AL4 degenerates to "fold = existing
   line", and AL9 becomes inconsistent. Every AL1+{AL4,AL5,AL8,AL9} combo
   is equivalent to a separable, already-counted, or degenerate one. Kills
   **40** extras.
3. **The line-reflection equations lose the isotropic denominator.**
   Reflection across an isotropic line ($x_f^2 + y_f^2 = 0$) is undefined; for
   pure line-reflection alignments (AL4, AL9) that factor cancels out of
   the cleared chart denominators, leaving a spurious positive-dimensional
   component that Rabinowitsch saturation misses. Saturating $x_f^2 + y_f^2$
   for both folds recovers the **2 missing** symbols (AL4ab with count 3 =
   the paper's $c_x = 3$ [alperin2006, l. 694], AL4a9 with count 2) and
   explains AL13a9's multiplicity artifact.
4. **Five extras have no principled kill** (AL2ab8, AL2a7a8, AL2a7b8,
   AL2a7a9, AL2a7b9). Two of them (AL2a7a8/7b8) have no real solutions at
   either parameter stream — consistent with elimination at the paper's
   step 5, which needs a solution to evaluate a Jacobian at [alperin2006,
   l. 539]. The other three satisfy every rule the paper states. All five
   share an exact syntactic profile, encoded here as rule R4 and flagged
   **empirical**.

## The corrected rules, stated precisely

Let kinds {AL2, AL3, AL6} be the *single-fold* alignments (each mentions
exactly one fold, via its suffix), and note that AL1, AL7, AL8, AL9
constrain only the composition $\rho = F_a \circ F_b$ (see R4 below).

- **R1 (separability, replaces `Combo.separable`).** A combo is separable
  iff it contains ≥ 2 single-fold alignments with the same suffix.
  (Their equations sum to ≥ 2, so that sub-multiset is itself a 1FA fixing
  that fold from given objects alone; the remaining 2 equations, with that
  fold now an ordinary line, are a 1FA for the other fold — every alphabet
  alignment becomes a one-fold alignment once one fold is a known line.)
- **R2 (AL1 reduction, new).** Reject any combo containing AL1 together
  with any of AL4, AL5, AL8, AL9.
- **R3 (algebra fix, `Symeq`/pipeline).** Add $x_a^2 + y_a^2$ and $x_b^2 + y_b^2$
  to the cleared denominators passed to `Msolve.classify` (equivalently:
  every alignment that reflects across fold f must list f's isotropic
  factor among its denominators; today only point reflections and AL10 do).
- **R4 (empirical, new).** Reject any combo that contains AL8 or AL9 and
  no alignment of kinds {AL3, AL4, AL5, AL6, AL10}.

Filter: `Zero_dim { count >= 1; multiplicity_free }` as before. Under R3
the strict/lax distinction disappears entirely (no multiplicity failures
remain among the 251 surviving candidates).

## Why — the paper evidence

### R1: Definition 10 is sequential decomposition, not a 2+2 partition

Definition 10: "A two-fold axiom is separable iff its alignments can be
partitioned into two sets, each of which is a one-fold axiom" [alperin2006,
l. 467–468]. The Abe-trisection example immediately following [alperin2006,
l. 470–473] fixes the intended reading: L1 folds P onto Q (O2 — a 1FA from
given objects only), then L2 folds Q onto l *and P onto L1* (O6 — a 1FA
that uses the *first fold line* as one of its given lines). The partition
is ordered: S1 determines fold x from givens alone; S2 determines fold y
with $L_x$ available as an ordinary line. The current `Combo.separable`
demands S2 mention only fold y, which the paper's own example violates —
O6's second alignment references L1.

In the alphabet, only AL2/AL3/AL6 constrain one fold from givens alone, so
S1 must be ≥ 2 same-suffix alignments from these kinds. No condition on S2
is needed: once fold x is a known line, every remaining alignment is a
one-fold alignment for fold y (AL4y ↦ A2, AL5y ↦ A4, AL8 ↦ A1 on the
derived point $F_x(P)$, AL9 ↦ A2 on the derived line, AL7 ↦ A4 via
involution, AL1 ↦ A3 against $L_x$, AL10 ↦ A4/A5 on the derived objects),
and its 2 remaining equations make it a 1FA. The one exception, {AL2x,
AL2x}, is not a valid 1FA (the paper's Table 1 "N/A" cell — inconsistent
for nonparallel lines, redundant for parallel [alperin2006, l. 320–325])
but is generically unsolvable, so R1 subsuming it is harmless.

Checks: the fixture's no-AL10 slice contains **zero** symbols matching R1;
exactly **160** of the 205 extras match it.

### R2: equivalence under folding, conditioned on AL1

Definition 12 allows applying $F_{F1}$ or $F_{F2}$ to both sides of alignments
[alperin2006, l. 476–479]. AL1 ($F_a(L_b) \leftrightarrow L_b$) forces $a \perp b$ — its
componentwise equations factor as (coincident fold) $\cup$ (perpendicular), and
the coincident branch is not a new fold line [alperin2006, l. 285]. With
$a \perp b$: $F_a(L_b) = L_b$, $F_b(L_a) = L_a$, and $\rho = F_a \circ F_b$ is the half-turn
about $a \cap b$. Consequences, alignment by alignment:

- **AL5a ≡ AL3b**: $F_a(P) \in L_b \iff P \in F_a(L_b) = L_b$ (apply F_a to both
  sides, then use AL1).
- **AL8 ≡ AL3a + AL3b on the midpoint**: $F_a(P_1) = F_b(P_2) \iff \rho(P_1) = P_2 \iff$
  $a \cap b = \text{midpoint}(P_1, P_2)$, i.e. both folds pass through a derived point.
- **AL4a degenerates**: $L_b = F_a(L)$ with $L_b \perp L_a$ forces $L \perp L_a$, hence
  $F_a(L) = L$, i.e. **fold b coincides with the given line L** — not a new
  fold line [alperin2006, l. 285], and "any combination in which a single
  alignment fully specifies one of the fold lines will be separable"
  [alperin2006, l. 482–483]. Verified numerically: AL13a4a's unique
  solution has fold b = $(41/23, -53/31)$ = AL4a's given line, exactly.
- **AL9 is inconsistent**: $\rho(L_1) = L_2$ needs $L_1 \parallel L_2$, generically false.
  (Under R3 the AL1+AL9 systems indeed classify `No_solutions`.)

So each of the 40 AL1-extras reduces, alignment-for-alignment, to either a
R1-separable combo (24 of them, e.g. AL13ab5a ≡ AL1+3a+3b+3b), a combo
already in the paper's list (10 of them, e.g. AL12a5a7a ≡ AL12a3b7a,
AL15a7aa ≡ AL13a7bb after $a \leftrightarrow b$), or a degenerate one (the 6 containing AL4).
Consistently, the paper's AL1-combos pair only with {AL2, AL3, AL6, AL7,
AL10} — never AL4/5/8/9 [alperin2006, listing l. 545 ff.].

### R3: the isotropic component in pure line-reflection systems

The paper's point-reflection formula divides by $X_F^2 + Y_F^2$ [alperin2006,
eq. (1), l. 198–201]; reflection is undefined on isotropic mirrors. Our
`reflect_point_raw` keeps that factor in its denominator, so point-folding
alignments already saturate it away. But in `reflect_line_raw` the factor
cancels: the image line's homogeneous triple (num_X, num_Y, den) has chart
denominator $\mathrm{den} = x_f^2 + y_f^2 - 2l_X \cdot x_f - 2l_Y \cdot y_f$, which does **not**
vanish on the isotropic locus. On $x_f^2 + y_f^2 = 0$ the triple becomes
proportional to $(x_f, y_f, 1)$ — an isotropic mirror sends *every* line to
the same image — so the cross-multiplied line-equality equations of AL4
and AL9 vanish identically on the curve {fold a = fold b, isotropic}.
That component is 1-dimensional and survives Rabinowitsch saturation of
the chart denominators. AL4a9 and AL4ab are exactly the two candidates
whose every reflection is a line reflection, hence the only two whose
systems retain the component: msolve reports `Positive_dim` and the
pipeline drops them, even though both are genuine axioms — AL4ab is the
paper's own trisection example [alperin2006, §6.1, l. 694–698].

With $x_a^2 + y_a^2$, $x_b^2 + y_b^2$ added to the saturation product:

| symbol | before | after |
|---|---|---|
| AL4ab | Positive_dim | Zero_dim, count 3, mult-free — matches $c_x = 3$ [alperin2006, l. 694] |
| AL4a9 | Positive_dim | Zero_dim, count 2, mult-free |
| AL3ab9 (control) | count 4 | count 4 — matches $c_x = 4$ [alperin2006, l. 709] |
| AL13a9 | Zero_dim count 2, **not** mult-free | `No_solutions` |

No other classification among the surviving candidates changes.

### R4: the five unexplained extras — honest status

AL2ab8, AL2a7a8, AL2a7b8, AL2a7a9, AL2a7b9. Shared structure: AL2 is a
pure *direction* constraint, and each of AL1/AL7/AL8/AL9 constrains only
the composition $\rho = F_a \circ F_b$ (AL7a $\iff P \in \rho(L)$; AL8 $\iff \rho(P_2) = P_1$; AL9 $\iff$
$\rho(L_2) = L_1$). The five are precisely the strict-solvable combos built
solely from {AL2} $\cup$ {AL7, AL8, AL9} containing a 2-equation $\rho$-alignment —
no alignment ever ties a fold's *position* to a given point or line, which
is what R4 encodes.

What the evidence supports:

- **AL2a7a8, AL2a7b8**: both solutions form a complex-conjugate pair at
  stream_a *and* stream_b — consistent with structural non-realness. The
  paper's step 5 evaluates a Jacobian "at a solution" [alperin2006,
  l. 539]; with no real solution there is nothing to evaluate at, and a
  2FA must define fold lines in the Euclidean plane [Def. 9, l. 453–455].
  Semi-principled exclusion.
- **AL2ab8, AL2a7a9, AL2a7b9**: real, zero-dimensional, multiplicity-free,
  minimal, distinct, non-separable under every reading of Definition 10,
  exactly 4 equations. AL2ab8's unique solution is rational and was checked
  geometrically (Q-construction) — nothing degenerate. No rule stated in
  the paper excludes them. They cannot be distinguished by any solution
  invariant from included combos: AL2ab7aa (in the paper's list) has the
  same block-triangular structure, the same count 1, the same rationality.
- The omission is in A-L's *enumeration*, not the typesetting: the prose
  statistic "the first 310 2FAs … ending with AL3a7bbb" [alperin2006,
  l. 652–653] matches the printed listing exactly (AL3a7bbb is entry 310),
  so the listing is what their program produced.

Conclusion: R4 reproduces Alperin–Lang exactly and has a crisp syntactic
statement, but for AL2ab8/AL2a7a9/AL2a7b9 it is a *reproduction* rule, not
a derived one — those three look like valid non-separable 2FAs missing
from the paper's list (or excluded by an unstated criterion of their
Mathematica implementation). Anyone extending this work past reproduction
should revisit them.

## Classification of all 205 extras and 2 missing

- **160 extras** — R1 (sequential separability). E.g. AL12a3a5a: {AL2a,
  AL3a} is O4 for fold a; {AL1, AL5a} then folds b given a.
- **40 extras** — R2 (AL1 reduction):
  - 24 reduce to R1-separable combos (AL12a3b5b, AL12a5ab, AL12a5b6b,
    AL12a5b7a, AL12a5b7b, AL12a8, AL13a5a6b, AL13a5aa, AL13a5ab,
    AL13a5b6b, AL13a5b7a, AL13a5b7b, AL13a8, AL13ab5a, AL15a6ab,
    AL15a6b7a, AL15a6b7b, AL15a8, AL15aa6a, AL15aa7a, AL15aa7b, AL15aab,
    AL15ab6a, AL16a8);
  - 10 are Def-12 duplicates of listed symbols (AL12a5a7a ≡ AL12a3b7a,
    AL12a5a7b ≡ AL12a3b7b, AL13a5a7a ≡ AL13ab7a, AL13a5a7b ≡ AL13ab7a,
    AL15a6a7a ≡ AL13a6b7b, AL15a6a7b ≡ AL13a6b7a, AL15a7aa ≡ AL13a7bb,
    AL15a7ab ≡ AL13a7ab, AL15a7bb ≡ AL13a7aa, AL15ab7a ≡ AL13ab7a);
  - 6 are degenerate, fold = existing given line (AL13a4a, AL13a4b,
    AL14a5b, AL14a6a, AL14a7a, AL14a7b).
- **5 extras** — R4 (2 semi-principled via non-realness, 3 unexplained;
  see above).
- **2 missing** (AL4a9, AL4ab) — R3, spurious isotropic component.

$160 + 40 + 5 = 205$ ✓; $406 - 205 + 2 = 203$ ✓.

## AL13a9 (the strict-only rejection)

Structural, not parameter-accidental — but not multiplicity either. AL1
forces the folds perpendicular, making $\rho$ a half-turn; AL9 then demands
$\rho(L_1) = L_2$, impossible for generic (non-parallel) $L_1, L_2$. The genuine
solution set is empty; what msolve counted (count 2, with multiplicity)
was entirely the spurious isotropic component of AL9's cleared equations.
Under R3 the system classifies `No_solutions` at both streams. The
strict/lax "multiplicity" signal was an artifact of that component, and
with R3 in place no candidate anywhere in the sweep fails
`multiplicity_free` — the strict and lax filters coincide.

## What must change, in which module

- **`combo.ml`** — replace `separable` with R1: separable iff some fold
  has ≥ 2 single-fold alignments (kinds AL2/AL3/AL6, same suffix). The
  `folds_mentioned`/`Both` machinery and the 2+2 bipartition go away.
- **`combo.ml`** (`candidates`) — add R2 (drop AL1 × {AL4, AL5, AL8, AL9})
  and R4 (drop AL8/AL9-combos with no alignment of kinds
  {AL3, AL4, AL5, AL6, AL10}), each with a comment citing this note; R4
  explicitly marked empirical. *Post-implementation amendment:* R4 was
  deliberately NOT added to `candidates` -- it lives in
  `Combo.matches_published_list`, applied explicitly by
  `Pipeline.run_twofold_published`, so the empirical rule stays visible
  rather than silently baked into the candidate pool.
- **`symeq.ml`** — include the folding fold's isotropic factor
  $x_f^2 + y_f^2$ among the cleared denominators for AL4 and AL9 (the two
  pure line-reflection alignments; AL7 already carries it via its point
  side, AL1/AL2 perform no reflection). Alternatively add both folds'
  isotropic factors unconditionally in `equations_denoms_of`; the sweep
  is insensitive to the difference.
- **`pipeline.ml`** — no change beyond picking up the above; the strict
  filter is already correct (and lax becomes equivalent).
- **`test_pipeline.ml`** — `test_twofold_no_al10` should then pass as
  written.

## Verification

Throwaway probe (`probe_final.ml`, run under `tools/`, deleted after this
note; not committed) reimplemented R1–R4 on top of the existing library
functions and re-ran the full no-AL10 sweep at stream_a:

```
candidates (no AL10, current separable): 635
after R1: 336   after R2: 264   after R4: 251
mine=203 expected=203
extras=0 missing=0
SYMBOL-EXACT MATCH: 203 = 203
```

- Diff against the fixture's no-AL10 slice: **empty in both directions**
  (symbol-exact).
- No fixture symbol violates R1, R2, or R4.
- No surviving candidate fails `multiplicity_free`.
- Spot verifications along the way: AL4ab count 3 (= paper's cx),
  AL3ab9 count 4 (= paper's cx), AL13a4a's fold b lands exactly on AL4a's
  given line, AL2a7a8/7b8 complex at both parameter streams, AL13a9
  `No_solutions` at both streams.

## Addendum (2026-08-04): realness is parameter-dependent

A later pass (Task-8 "Fix round 2") added a fourth strict-filter conjunct,
`real_count >= 1`, on top of the R1-R3 rules above: Definition 9 defines a
two-fold axiom as fixing fold lines "on a finite region of the Euclidean
plane" [alperin2006, l. 453-455], and `Msolve.classify`'s new `real_count`
field (parsed from msolve's real-solutions isolating-box section) made it
possible to check that directly, per solution, per parameter stream. The
narrow, intended consequence worked exactly as predicted: AL2a7a8 and
AL2a7b8 (§R4 above) turned out to be complex-conjugate-only at *both*
{!Symeq.stream_a} and {!Symeq.stream_b}, and now die on the realness check
rather than needing R4 at all.

But the same change had a much larger, unintended consequence: the
k=2/no-AL10 slow run stopped reproducing 203 — **174** at `stream_a`, **180** at
`stream_b`. Diffing against the fixture: 0 extras, but **29** genuine
paper-listed symbols missing at `stream_a` and **23** at `stream_b`, with
only **12** symbols in common between the two missing sets. Every one of
these has `count >= 1`, `multiplicity_free = true`, `real_count = 0` **at
the failing stream only** — the same one-parameter-point sign-correlation
artifact already documented for the one-fold pipeline's `A4+A5` (Huzita-
Justin O5: a tangent-line-to-a-parabola problem with 0 or 2 real solutions
depending on which side of the parabola the fixed point lands, and
`stream_a`/`stream_b`'s strictly alternating signs happen to always land it
on one particular side), now hitting AL5/AL8-family constructions (also
degree ≥ 2, tangent/cubic-type) at k=2's larger scale.

### Why single-parameter-point realness is unsound as a filter

`real_count` is computed at exactly one generic parameter point — whichever
one the caller's `Symeq.param_stream` happens to draw. But Alperin-Lang's
enumeration is a claim generic **over ℂ**: whether a 2FA is realizable is a
question about the construction's algebraic structure, not about whether one
arbitrary numeric instantiation happens to land on the real side of a
tangency. A construction whose real/complex split depends on the parameters
(exactly the O5-type shape above) is real for *some* choices of given points
and complex for *others*; sampling a single point and treating a `0` there
as "this construction has no real form" conflates a parameter-dependent
fact with a structural one. The 29-vs-23-vs-12 numbers make this concrete:
if `real_count = 0` were tracking a genuine structural property of the
symbol, both streams would agree on which symbols it hits (as AL2a7a8/7b8 do
— see below). They don't: 17 of `stream_a`'s 29 and 11 of `stream_b`'s 23 are
each other's exclusive property, which is the signature of a coordinate
artifact, not a fact about the construction.

### Decision: realness is REPORTED, not FILTERED

`Pipeline.strict_keep` reverts to `count >= 1 && multiplicity_free` (no
`real_count` conjunct) — the same filter as before Fix round 2. The
`real_count` field itself stays on `Msolve.zero_dim` (parser, captures, and
unit tests unchanged): it is genuine, informative data about one probed
point, just not a sound admission criterion on its own. `Pipeline` now logs
every strict-surviving symbol whose solution has `real_count = 0` at the
run's stream to stderr, tagged "complex-only at this stream" — visible
without being silently dropped. `Pipeline.onefold_stream` (the decorrelated
stream introduced in Fix round 2 to route around O5's `stream_a`/`stream_b`
artifact) is gone: with the realness conjunct removed, `run_onefold` on
plain `Symeq.stream_a` again yields exactly the 7 HJAs (A4+A5 included,
logged as complex-only at that stream rather than excluded), so the
workaround has nothing left to work around.

### What a sound existential-realness analysis would require

Reducing this from "reported" to "filtered" correctly would need an
argument that is generic over the parameter space, not evaluated at one
point — e.g.:

- **Multi-parameter probing**: evaluate `real_count` at many independent,
  well-separated generic streams and only treat a symbol as structurally
  non-real if it is complex-only at *all* of them (necessary but still not
  sufficient — see below).
- **Semialgebraic reasoning**: characterize, for each symbol's equation
  system, the region of parameter space (a semialgebraic set, e.g. via
  cylindrical algebraic decomposition or real quantifier elimination) on
  which the solution is real, and ask whether that region is generic
  (full-dimensional / dense) or a measure-zero exception — the actual
  content of Alperin-Lang's "on a finite region of the Euclidean plane"
  when read as a claim about the construction rather than about one
  instance of it.

Neither is implemented here; this addendum documents the gap rather than
closing it.

### AL2a7a8/AL2a7b8: semi-principled, not proven

Multi-stream agreement is necessary evidence for structural non-realness,
even if it falls short of the semialgebraic argument above. AL2a7a8 and
AL2a7b8 are the one case in this sweep with that property: complex-conjugate
solutions at *both* `stream_a` and `stream_b`, unlike the stream-inconsistent
29/23 artifact set. That is why §R4 above still calls them a "semi-
principled exclusion" rather than a proven one — two points of agreement is
stronger than one, but is not a proof that no real-parameter instantiation
of AL2a7a8/AL2a7b8 exists. `Combo.matches_published_list` (R4) still needs
to exclude both explicitly, since neither the reverted strict filter nor any
other rule here does; R4's total burden is back to the original 5 (AL2ab8,
AL2a7a8, AL2a7b8, AL2a7a9, AL2a7b9), of which 2 (AL2a7a8/7b8) have this
semi-principled non-realness story and 3 (AL2ab8, AL2a7a9, AL2a7b9) remain
genuinely unexplained, exactly as in the original §R4 accounting above.
