# Axiom 7 — the cubic Beloch fold

**Status:** design approved, ready to plan
**Date:** 2026-06-30
**Builds on:** ADR 0012 (real-algebraic number kernel, shipped #19);
`docs/superpowers/specs/2026-06-30-real-algebraic-kernel-design.md` ("Next slice"
section, now superseded by this doc).

## Goal

Ship axiom 7 — *fold one point onto a line while simultaneously folding a second
point onto a second line* — the last Huzita-Justin axiom, and the first that
needs the **cubic**. This is the headline payoff: doubling the cube and angle
trisection become expressible `.bel` programs evaluated exactly.

"Fully general": axiom 7 must work even when its inputs are irrational (e.g. a
crease produced by a prior axiom-5 bisector), which forces completion of the
kernel's deferred algebraic-coefficient root finder. One spec covers both the
kernel completion (Slice 1) and the axiom surface (Slice 2).

## Numbering (resolved, do not re-conflate)

Beloch uses **classic Huzita-Justin numbering** [justin1986 §8.1]. Hull's BOO
list [hull2020 §1.5] inserts "intersection of two lines" as its O2, scrambling
the **low** numbers (Hull O3 = classic axiom 2, Hull O4 = classic axiom 5, Hull
O5 = classic axiom 3) — but the lists **coincide at 6 and 7**. Classic axiom 7 =
Hull O7 [hull2020:990] = two points onto two lines = common tangent to two
parabolas. So `hull2020 §2.4` ("Cubic Curves and Beloch's Fold", p. 45) is the
correctly-numbered geometry source. Tag string stays `"axiom7"`.
See `spec/SPECIFICATION.md` §"A note on axiom numbering" and `antipatterns.md`.

---

## Slice 1 — `Num.real_roots` for algebraic coefficients

### Problem

`lib/num.ml:308` `real_roots` today handles only **rational** coefficients; the
`Alg` case is `failwith "...deferred to the axiom 7 slice"` (`num.ml:312-313`).
Axiom 7's cubic coefficients are built from point/line coordinates, which are
`Alg` when fed by a prior irrational crease. The merged kernel's resultant
machinery (`Poly.resultant`, `Num.select_root`, `defpoly_sum/prod`, `res_interp`)
is all **pairwise** — it eliminates one generator against one other and picks the
single result with a numeric enclosure. `real_roots` needs multi-generator
elimination and returns *many* roots, so that machinery doesn't directly apply.

### Approach (algorithm A — superset-manufacture + exact-eval certify)

Real algebraic numbers are a subfield of ℝ, hence **archimedean** — so rational-
interval isolation is valid here. `bpr2006 §10.4` reaches for Thom encoding only
because it targets *general* (non-archimedean) real closed fields; `Remark 10.74`
confirms the rational-isolation route (Algorithm 10.4) is preferable in practice
when available, which it is for us. Each step maps to a sanctioned primitive:

`real_roots (coeffs : Num.t array) : Num.t list` — real roots of
P(z) = Σ coeffs[i]·zⁱ, ascending:

1. **Normalize.** Drop trailing zero coefficients (`Num.sign`) to find the true
   degree. If every coefficient is `Rat`, take the existing rational path
   unchanged (preserves the fast path; rational-input golden tests stay cheap).
2. **Manufacture a superset ℚ-polynomial `R(z)`** by eliminating every *distinct*
   irrational coefficient's generator [bpr2006 §4.2, classical resultant/norm]:
   - Each distinct `Alg` coefficient `c_k` → independent variable `y_k` with its
     own minimal polynomial `m_k`. P is a ℚ-polynomial in z and the `y_k`.
   - Eliminate the generators one at a time by resultant against `m_k`. The first
     elimination is linear in its `y_k` (a single coefficient slot) → plain
     substitution `Bⁿ·m_k(−A/B)`. Subsequent eliminations face higher degree in
     the remaining generators → general bivariate resultants, computed by
     **recursive evaluate-interpolate** (Collins-style: sample outer variables at
     integers, take numeric `Poly.resultant`, `Poly.interpolate` back) — the same
     two primitives `res_interp` already uses. Terminates at univariate
     `R(z) ∈ ℚ[z]`.
   - `R` need only be a **superset** (its roots ⊇ true roots of P, plus
     conjugate-spurious ones) — the certify step below removes the spurious ones.
3. **Isolate** [bpr2006 §10.2]: `Poly.squarefree_part R` → `Poly.isolate_roots`
   → candidate disjoint ℚ-intervals.
4. **Certify by exact evaluation** [bpr2006 §10.3, sign determination at an
   algebraic point — already the kernel's `Num.sign`]: for each candidate, form
   the `Num` value `Num.make R lo hi`, evaluate P at it via `Num` arithmetic,
   keep iff `Num.sign` of the result is `0`. Refine candidate intervals as needed
   so each isolates a single root of `R` (well-formed `Alg`).
5. **Sort** ascending (`Num.compare`); return.

### New machinery

A small nested-polynomial elimination helper in `lib/poly.ml` (recursive
evaluate-interpolate over `Poly.resultant` + `Poly.interpolate`). No new `Num`
public surface beyond removing the `failwith`. This helper is the slice's risk
center.

### Tests (gate Slice 1 before any geometry)

In `tests/test_beloch.ml` (num group, registered in the suite list):

- **Rational fast-path guard:** an all-`Rat` cubic produces no `Alg` elimination
  work and matches the existing rational result.
- **Single irrational generator:** a cubic with coefficients built from `√2`
  (e.g. `z³ − √2` → one real root `∛(√2)`); assert count, distinctness, and
  `to_float` within `1e-9`.
- **Two independent generators:** coefficients from `√2` *and* `√3` — exercises
  the multivariate elimination path specifically.
- **Casus irreducibilis with irrational coefficients:** a three-real-root
  irreducible cubic whose coefficients are irrational; assert exactly three
  distinct roots, ordered, each `to_float`-correct. (`bpr2006`'s running example
  `x³ − 3x − 1` with rational coeffs already lives in the suite; this is its
  irrational-coefficient sibling.)

---

## Slice 2 — the axiom 7 surface

### Syntax

```
map .p onto --d and .q onto --e
map .p onto --d and .q onto --e toward .x
```

Mirrors axiom 6's optional-`toward` shape. Required changes:

- **Lexer** (`lib/lexer.ml`): add keyword `"and" → AND`. (Note: the kernel design
  doc wrongly claimed this token already existed — it does not.)
- **Parser** (`lib/parser.mly`): declare `AND` token; add two `axiom:`
  alternatives (with and without the `TOWARD` tail), matching axiom 6's pair.
- **AST** (`lib/ast.ml`): new constructor
  `MapBoth of point_operand * line_operand * point_operand * line_operand * point_operand option`.

### Geometry — `Geom.beloch7_creases`

`beloch7_creases : point -> line -> point -> line -> line list`, returning 0, 1,
or 3 creases. A crease folding `p` onto `d` is tangent to the parabola (focus
`p`, directrix `d`); folding `p` onto `d` *and* `q` onto `e` simultaneously makes
the crease a common tangent to two parabolas — a cubic [justin1986:11;
hull2020 §2.4].

Construction (reuses existing primitives only):

1. Parametrize `p`'s landing along directrix `d` by a rational parameter `t`:
   `p*(t) = d0 + t·û` (a point on `d`).
2. Candidate crease `c(t) = perpendicular_bisector p p*(t)`.
3. The same crease must land `q` on `e`:
   `side_of_line e (reflect_point c(t) q) = 0`. Expanding this yields a **cubic in
   `t`** whose four coefficients are `Num` values built from the coordinates of
   `p`, `d`, `q`, `e`.
4. `Num.real_roots [c0; c1; c2; c3]` → 1 or 3 real `t`; map each `t` back to its
   crease via `perpendicular_bisector`. (This is the call site that drives
   Slice 1's `Alg`-coefficient path when the inputs are irrational.)

No new geometry primitives: uses `perpendicular_bisector`, `reflect_point`,
`side_of_line`, `intersection`, `parallel` (`lib/geom.ml`).

### Eval (`lib/eval.ml`)

New `axis_of` arm, tag `"axiom7"`, sources `[pstr p; lstr d; pstr q; lstr e]`
(plus `x` when present), `@`-fold moving side defaults to `.p`. Mirror axiom 6's
result structure exactly:

- `[]` → error "out of reach (no common tangent / fold exists)".
- `[c]` → single crease, no selector needed.
- `≥2` creases → require `toward .x`; if absent, error mirroring axiom 6's
  ambiguity message. Select the crease whose image of the **first** folded point
  (`reflect_point c p` landing on `d`) is nearest `.x`, by exact squared distance
  (`Num.compare`) — the one disambiguation vocabulary shared by axioms 5/6/7.

**Degeneracy guards** [justin1986 §8.4a], via existing `parallel`/`intersection`:

- `P' ∈ D'` (the second point already on its target line) → the problem collapses
  to axiom 6 + axiom 4; raise a pointed error naming the lower axioms.
- `D ∥ D'` (parallel directrices) → axiom-6-type degenerate case; pointed error.

### Tests

- **Geometry units:** a known two-parabola configuration with a hand-verified
  common tangent; assert each returned crease folds `p` onto `d` and `q` onto `e`
  (verify with `reflect_point` + `side_of_line = 0`, the axiom-6 test pattern).
- **Degeneracy:** `P'∈D'` and `D∥D'` raise the expected errors.
- **Parse:** `MapBoth` AST shape, with and without `toward`.
- **Golden, end-to-end (`.bel` → FOLD, exact) — the headline:**
  - **Doubling the cube:** a `.bel` program whose crease encodes `∛2`; assert the
    constructed length `v` satisfies `v³ = 2` exactly (`Num.equal`).
  - **Angle trisection** [justin1986 §4.2]: trisect a given angle; assert the
    trisection identity exactly.
  - **Composed irrational input:** axiom 7 fed by an axiom-5 bisector (irrational
    coordinates), forcing the `Alg`-coefficient `real_roots` path through the full
    pipeline end-to-end.
- **FOLD emit:** the emitted FOLD carries the `"axiom7"` tag and correct sources.

---

## Docs & provenance (same change)

- `spec/SPECIFICATION.md`: new section for axiom 7 (grammar + EBNF mirror), and
  move axiom 7 from Appendix B "deferred" to "landed".
- ADR: write **ADR 0013 — axiom 7 (cubic Beloch fold)** if the
  superset-manufacture + exact-eval-certify design or the landing-parameter cubic
  construction warrant a recorded decision; otherwise a journal note in `notes/`.
  Ground geometry to `hull2020 §2.4` / `justin1986`, the root finder to
  `bpr2006 §§4.2, 10.2–10.4`.
- `paper/references.bib` + `bibliography.md`: confirm `bpr2006`, `hull2020`,
  `justin1986` entries cover the cited locators (all already present).

## Build order

1. Slice 1 kernel: nested-poly elimination helper → `real_roots` `Alg` path →
   num tests **green** (the gate).
2. Slice 2 surface: lexer/parser/AST → `beloch7_creases` → eval arm → degeneracy
   guards.
3. Golden tests (∛2, trisection, composed-irrational) green end-to-end.
4. Docs, ADR/journal, FOLD screenshots for the PR.

## Out of scope

- Axiom 8 and anything beyond Huzita-Justin.
- Any `Ext`-style quadratic fast-path beyond the existing `Rat` fast-path
  (explicit YAGNI; revisit only if profiling demands).
- Thom encoding of algebraic numbers — isolating intervals suffice here
  (archimedean); revisit only if interval refinement proves inadequate.
