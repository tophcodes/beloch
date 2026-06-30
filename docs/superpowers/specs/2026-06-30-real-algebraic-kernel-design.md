# Real-algebraic number kernel — replace the quadratic `Ext` tower

**Status:** design approved, ready for implementation plan
**Slice:** kernel rewrite — slice 1 of 2 (axiom 7 is slice 2, built on top)
**Surface:** none. No `.bel` syntax changes; this is a foundation swap that keeps
all existing behaviour green.

## Why now

[ADR 0010](../../../decisions/0010-constructible-real-numbers.md) gave `Num` a
quadratic-extension tower (`Rat of Q.t | Ext of t*t*t`, meaning `a + b√d`) — the
constructible reals, exactly enough for axioms 1–6 (square roots only). It
explicitly deferred the degree-3 kernel "until axioms 6/7 force it."

Axiom 7 (Justin ⑦, the Beloch fold `(P→D, P'→D')`) forces it. Its crease is the
common tangent to two parabolas, i.e. a root of a **general cubic**
`[justin1986 §2–3]`, with **1 or 3 real roots** `[justin1986 §4, remark]`. When
there are three real roots, the *casus irreducibilis* applies: those real roots
**cannot be written with real radicals** — Cardano's formula routes through
complex cube roots even though every root is real. So a `Cbrt` generator is
provably insufficient. The kernel must represent real roots of arbitrary
integer polynomials directly. Justin states the target field precisely: K₃ is
the smallest real field closed under "the real roots of `x³ + px + q = 0`"
`[justin1986 §8.4d]`; `[hull2020]` characterises origami numbers by their
**minimal polynomials**.

Decision taken in brainstorming: a **full real-algebraic rewrite** — one
representation for every irrational, the elegant `Ext` tower retired. A rational
fast-path is kept so the cheap axioms pay nothing.

## Representation

A Beloch number is a **real algebraic number**, stored as the standard
*isolating-interval representation* `[bpr2006 Ch. 10]`:

```ocaml
type t =
  | Rat of Q.t                                   (* fast-path: exact rational  *)
  | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t } (* the unique root of [poly]
                                                    in the open interval (lo,hi) *)
```

Invariants for `Alg`:

1. `poly ∈ ℚ[x]` is **squarefree** and `poly` has **exactly one** real root in
   `(lo, hi)` — that root *is* this number.
2. The number is **irrational** (rational values always collapse to `Rat`), so
   `0` is never the isolated root of an `Alg`; sign is always decidable by
   refining the window away from `0`.

Every number reachable from a rational square sheet is algebraic over ℚ, so this
one shape covers ℚ, every `√`, every `∛`, the casus-irreducibilis cubics, and the
degree-4 Ferrari folds Justin notes `[justin1986 §6]` — all on the real line, no
complex arithmetic anywhere.

## Modules

Split into two units, each with one job (current `lib/num.ml` is rewritten;
`lib/poly.ml` is new):

### `lib/poly.ml` — univariate polynomials over ℚ

Dense `Q.t array` (or `Q.t list`), low coefficient first. Pure algebra, no
geometry, no intervals-as-numbers.

- `degree`, `eval : t -> Q.t -> Q.t`, `add`, `sub`, `mul`, `scale`, `neg`,
  `derivative`.
- `pseudo_remainder` / signed-subresultant remainder sequence, `gcd`,
  `squarefree_part` `[bpr2006 §8.3]`.
- `resultant : t -> t -> Q.t` and the bivariate elimination helpers needed by
  `Num` arithmetic `[bpr2006 §4.2]`.
- `sturm_sequence` and `sign_changes` → real-root **counting** on an interval
  `[bpr2006 Ch. 2, Ch. 9]`.
- `isolate_roots : t -> (Q.t * Q.t) list` → disjoint isolating intervals for all
  real roots `[bpr2006 Ch. 10]`.
- `sign_at : t -> Q.t -> int`.

### `lib/num.ml` — the algebraic-number type (rewritten)

Same **narrow public interface as today** so callers barely change:
`zero one of_q of_int neg add sub mul inv div sqrt sign compare equal to_float`.
Drop `Ext`, `compare_struct`, `ext`. Add one constructor for axiom 7:

- `real_roots : t array -> t list` — real roots of a polynomial **whose
  coefficients are themselves `Num` values**, returned ascending. Coefficients
  are algebraic over ℚ, so the routine eliminates their generators by resultants
  to obtain a single ℚ-defining polynomial per root, isolates, and attaches the
  correct window. `sqrt x` is reimplemented as the nonnegative root of `t² − x`.

Operation notes:

- `add`/`mul`/`inv`/`div` on `Alg`: defining polynomial of the result via
  resultant (`Res_y(P_x(z−y), P_y(y))` for sums, the homogenised form for
  products, coefficient-reversal for `inv`); result window via interval
  arithmetic on operand windows, **refined by bisection until it isolates one
  root** of the result polynomial. `neg` is `poly(−x)` with the flipped window —
  no resultant.
- **Canonicalisation** after every `Alg` build: take the squarefree part; if the
  isolated root is rational (a linear ℚ-factor sits in the window), collapse to
  `Rat`. This is what makes `(√2)² ` reduce to `Rat 2` and `equal x y`
  (≡ `sign (sub x y) = 0`) decide a true zero exactly.
- `sign (Alg …)`: refine the window until it lies wholly on one side of `0`
  (terminates because the root is irrational, hence ≠ 0). `Rat` is `Q.sign`.
- `to_float`: `Rat` → `Q.to_float`; `Alg` → refine the window to target precision
  and return its midpoint. **Output only** (FOLD JSON), never fed back.

## Migration / blast radius

`geom.ml`, `isometry.ml`, `fold_state.ml`, `eval.ml` all consume `Num` through
the interface above. Because the signature is preserved, the migration is
mechanical: remove any code that pattern-matches `Ext` directly (if any leaked
out of `num.ml` — to be checked in the plan), nothing else should change. The
only *behavioural* difference is that sign/equality on irrationals now run
through interval refinement: **same answers, more work**. The acceptance test for
this slice is therefore "**every existing test stays green**."

## Cost — accepted, recorded

Resultant-based arithmetic is heavier than the closed-form `a+b√d`; deep nesting
produces high-degree defining polynomials (representation blowup). This is the
same correctness-over-speed bargain ADR 0010 already struck, now paid in full.
The `Rat` fast-path keeps axioms 1–4 free. An `Ext`-style quadratic fast-path
could be reintroduced later **only if profiling demands it** — explicitly YAGNI
now.

## ADR

Write **ADR 0012 — Real-algebraic number kernel**, superseding ADR 0010 (mark
0010 *Superseded by 0012*). Record: the casus-irreducibilis argument, the
isolating-interval representation, the retirement of `Ext`, the kept `Rat`
fast-path, the accepted blowup. Ground the algorithms to `bpr2006` and the field
theory to `justin1986 §8.4d` / `hull2020`.

## New source

Add **`bpr2006`** — Basu, Pollack, Roy, *Algorithms in Real Algebraic Geometry*
(2nd ed., Springer, 2006) — to `paper/references.bib` and a note in
`bibliography.md`, in this same change. PDF + extracted text already in
`refs/bpr2006.{pdf,txt}`. It is the source for resultants/subresultants (Ch. 4,
8), Sturm sequences and root counting (Ch. 2, 9), and real-root isolation
(Ch. 10).

## Tests

New `tests/test_poly.ml`:

- `resultant`: `Res(x²−2, x²−3) = 1` (≡ `∏(±√2 ∓ √3)`); `Res(P,P) = 0`.
- Sturm root count: `x³ − 3x − 1` reports **3** real roots; `x²+1` reports 0.
- `squarefree_part` / `gcd` on a polynomial with a repeated factor.
- `isolate_roots` returns three disjoint windows for `x³ − 3x − 1`.

New `tests/test_num.ml`:

- Rational arithmetic stays `Rat` (no `Alg` nodes) — guards the fast-path.
- `sqrt (of_int 2)` squared `equal`s `of_int 2` exactly (canonicalisation).
- `sign` / `compare` order the three real roots of `x³ − 3x − 1`
  (≈ −1.532, −0.347, 1.879) correctly, including their signs.
- Nested radical `√(1 + √2)`: positive sign, and `(·)² − 1` `equal`s `√2`.
- A casus-irreducibilis cubic (three real roots, irreducible over ℚ): each root
  is representable, distinct, and `to_float` lands within `1e-9` of the decimal.

Existing suite (`tests/test_beloch.ml`, axioms 1–6, fold-state, FOLD emit) must
pass unchanged — the migration's real gate.

## Out of scope (this slice)

- **Axiom 7 itself** — syntax, geometry, eval, docs. That is slice 2 (see below);
  it introduces no kernel change beyond calling `Num.real_roots`.
- Thom encoding of algebraic numbers — isolating intervals suffice `[bpr2006
  Ch. 10]`; revisit only if interval refinement proves inadequate.
- Any `Ext`-style fast-path beyond `Rat`.

## Next slice — axiom 7 (decisions captured so they aren't lost)

Built on this kernel once it ships; gets its own spec, with the parabola algebra
pinned against `hull2020` at that time.

- **Syntax:** `map .p onto --d and .q onto --e` (+ optional `toward .x`); all
  tokens already exist.
- **Geometry:** `Geom.beloch7_creases` builds the common-tangent cubic
  (coefficients in `Num`) for parabolas (focus `.p`, directrix `--d`) and
  (focus `.q`, directrix `--e`) `[justin1986 §2–3]`, calls `Num.real_roots`
  (1 or 3 roots), maps each root to its crease line.
- **Selector:** `toward .x` → the solution whose image of the **first** folded
  point (`.p` landing on `--d`) is nearest `.x` (exact). One disambiguation
  vocabulary across axioms 5/6/7.
- **Degeneracies** `[justin1986 §8.4a]`: guard `P'∈D'` (→ ⑥+④), `D∥D'`
  (→ ⑥-type), 0 roots (out of reach), ambiguous-without-`toward` — errors
  mirroring axiom 6, with pointers.
- **Golden tests:** doubling the cube (`∛2`) and angle trisection, end-to-end and
  exact — the headline payoff.
- Tag `"axiom7"`, sources `[p; d; q; e]` (+`x`); `@`-fold moving side defaults to
  `.p`.
