# Shared-field arithmetic for `Num` (RUR-style `Field` representation)

**Status:** design approved, ready to plan
**Date:** 2026-06-30
**Builds on:** ADR 0012 (real-algebraic number kernel); the axiom-7 slice
(`docs/superpowers/specs/2026-06-30-axiom-7-cubic-beloch-fold-design.md`), which
surfaced the problem this fixes.

## Goal

Make exact arithmetic with several algebraic numbers that **share a field**
cheap, so that *folding the paper along an irrational axiom-7 crease* — the ∛2
doubling-the-cube fold, angle trisection — actually completes, instead of
exploding to multi-minute resultant chains.

Today every algebraic number is an independent `Alg` (its own minimal polynomial
+ isolating interval), and products/sums are formed by resultants. When several
values are in fact rational functions of one common generator α (e.g. a crease's
three coordinates `a, b, c`, all rational functions of the single landing
parameter `t`), the kernel does not know this and re-derives them as independent,
so degrees multiply (3 → 9 → 27 …) and computation is prohibitive (>25 min
measured for a single irrational-crease fold). `[bpr2006 §12]` notes this naive
multivariate blowup is doubly-exponential.

The fix is the standard one `[bpr2006 §12.4, Rational Univariate Representation]`:
represent all coordinates as rational functions of a **single** generator and do
arithmetic in that one field, where degrees stay bounded by `deg(α)`.

## Architecture — a `Field` constructor on `Num.t`

Extend the existing number type rather than building a parallel tower, so the
entire `Geom` / `Fold_state` / `eval` layer stays **byte-identical** (it only
calls `Num.add`/`mul`/`sign`/…, which now stay in ℚ(α)):

```ocaml
type t =
  | Rat of Q.t
  | Alg of { poly : Poly.t; lo : Q.t; hi : Q.t }   (* unchanged *)
  | Field of { gen : gen; coords : Poly.t }        (* the value coords(α) *)

and gen = { mu : Poly.t; lo : Q.t; hi : Q.t }      (* α: irreducible μ + interval *)
```

- `gen.mu` is the **irreducible** minimal polynomial of α (degree `d`), obtained
  by factoring upfront (below). `gen.lo`/`gen.hi` isolate α as μ's unique root in
  that interval.
- `coords` ∈ ℚ[x], `deg coords < d`. The value is `coords(α)`. **Invariant:**
  `coords` is always kept reduced mod μ (add/sub stay below degree `d`; mul
  applies `Poly.rem`). The syntactic zero-test depends on this: with `coords`
  reduced and `deg coords < deg μ`, `μ ∣ coords ⟺ coords` is the zero array.
- Generators are shared by **structural identity** (`mu` contents equal + same
  interval). Two distinct roots of the same polynomial have different intervals,
  hence different `gen`s — they are never wrongly merged.

### Why irreducible μ (the payoff of factoring upfront)

Because μ is irreducible, `ℚ[x]/(μ)` is a genuine **field**, and every operation
is clean and trivially exact:

| op | implementation | note |
|---|---|---|
| add / sub | `Poly.add` / `Poly.sub` of `coords` | exact, degree < d |
| mul | `Poly.mul` then `Poly.rem` by μ | exact, degree < d, **no resultant** |
| inverse | extended Euclid mod μ | **always succeeds** (every nonzero elt is a unit) |
| zero-test | reduced `coords` **is the empty array** | `coords(α)=0 ⟺ μ∣coords ⟺ reduced=0`; pure syntactic check, no Sturm, no interval refinement |
| sign (≠0) | interval-evaluate `coords` at α's interval, refine α via μ's sign changes until the value-interval excludes 0 | terminates: a nonzero algebraic number is bounded from 0 |

Zero-testing collapsing to "is this polynomial empty" and inversion never hitting
a zero divisor are the direct rewards of carrying an *irreducible* μ rather than
a merely squarefree one.

## Getting μ — upfront factorization over ℚ

`real_roots` produces each root as `Alg{poly = R; interval}` where `R` is
squarefree but possibly **reducible**. To build a `Field` we need the
**irreducible** factor μ that has this root.

- **Factor `R` over ℚ, elementary scope:** pull out rational-root linear factors
  (reuse the existing `rational_roots_in` in `num.ml`); divide them out. What
  remains of **degree ≤ 3 with no rational root is irreducible** (a cubic or
  quadratic with no rational root has no ℚ-factorization). μ for a given root =
  the factor (linear, or the irreducible ≤3 remainder) whose unique real root
  lies in that root's isolating interval. This covers every headline case:
  - `x³ − 2` → irreducible, μ = R (doubling the cube).
  - `t³ − 3t² − 3t + 1` → `(t+1)(t² − 4t + 1)`; the irrational roots get
    μ = `t² − 4t + 1` (trisection of 45°).
- **Rigorous scope boundary:** a `Field` is built **only when a proven-irreducible
  μ is produced**. When `R` cannot be factored to irreducibility by the
  elementary routine (higher-degree composite remainder), the root stays `Alg`
  and uses today's resultant path — **correct, just slow**. A general Zassenhaus
  factorizer (to extend the fast path to deep compositions) is an explicit
  **follow-up, out of scope here**.

## `real_roots` returns `Field`

For each real root of `R` whose irreducible μ the routine can produce, return
`Field { gen = { mu; lo; hi }; coords = [| 0; 1 |] }` — literally "α itself."
Everything geometry then builds from that root lives in ℚ(α). Roots without an
obtainable irreducible μ fall back to `Alg` as today. The returned list's
ordering and values are unchanged; only the representation of factorable roots
differs.

## Interop and the safety invariant

`Field` is a **value-preserving fast path layered over the proven `Alg`
resultant path**:

- `Rat q` is a constant in any ℚ(α): combine by lifting to `coords = [| q |]`.
- `Field(α)` ∘ `Field(α)` with the **same** `gen` (structural identity) → fast
  field arithmetic above.
- `Field(α)` ∘ `Field(β)` with **different** generators, or `Field` ∘ `Alg` →
  **fall back**: convert `Field → Alg` (its defining polynomial is μ, its
  interval is α's; value = `coords(α)`, computed by the existing evaluate-at-α
  machinery / `make`) and use today's resultant arithmetic.
- `sign`, `compare`, `equal`, `to_float` gain a `Field` arm; `compare`/`equal`
  reduce to `sign (sub …)`, so only `sign` (above) and the `Field→Alg` fallback
  are new surface.

**Invariant:** correctness never depends on the fast path firing — only speed
does. The generator-identity test is conservative (equal μ + equal interval), so
a missed match degrades to the proven path, never to a wrong answer. Any fast-path
operation is provably value-preserving (`coords(α)` is the true value at every
step). The worst a fast-path bug can do is be slow, not wrong.

## Blast radius

- **`lib/num.ml`:** the `Field` constructor, `gen` type, field arithmetic, the
  `Field` arms of `add/sub/mul/neg/inv/div/sign/compare/equal/to_float`, the
  `Field → Alg` fallback, and the factorization helper feeding `real_roots`.
- **`lib/poly.ml`:** may need a small helper if not present (e.g. exact division
  to divide out linear factors — `divmod` already exists; reuse it).
- **Everything else unchanged.** `Geom`, `Fold_state`, `Fold_emit`, `eval`,
  `beloch7_creases` are not touched — they consume `Num` through its existing
  interface, which is preserved. This is the central design property.

## Testing

- **Unit (`Num`/field arithmetic):** with α = root of `x³ − 2`:
  `(α)³ = 2` via field mul (degree stays ≤ 2, no blowup); `α · α⁻¹ = 1`
  (inversion mod irreducible μ); zero-test of `α³ − 2` returns true by the
  syntactic check; sign of `α − 1` is `+`. With α a root of `t² − 4t + 1`:
  arithmetic and sign correct.
- **No-blowup guard (the regression that motivates this):** an operation chain
  that previously exploded now completes fast. Concretely: build the
  doubling-the-cube crease (irrational, in ℚ(∛2)) and run
  `reflect_point` + `side_of_line` — assert it returns the right sign and
  **completes in well under a second** (e.g. wrap the prior axiom-7
  `p=(0,1)/q=(1,1)` config from the geometry slice that previously did not finish
  in 25 min). This is the headline payoff: *the irrational fold now folds.*
- **End-to-end:** a `.bel` doubling-the-cube program → FOLD, completing quickly,
  with the irrational `axiom7` crease emitted; assert exactness of the folded
  geometry (a reflected corner lands where it must, checked with `side_of_line`).
- **Interop:** `Field + Rat`, `Field + Alg` (different field → fallback path)
  give the same values as the all-`Alg` computation (cross-check `Num.equal`).
- **Regression:** the full existing suite stays green; the slow axiom-7 number
  tests are unaffected (still exact). Field is opt-in per value.

## Out of scope

- **General polynomial factorization (Zassenhaus / Berlekamp–Hensel).** Elementary
  rational-root + degree-≤3 irreducibility covers the headline; deeper
  compositions whose `R` is higher-degree composite stay on the `Alg` path
  (correct, slow). Adding a full factorizer to widen the fast path is a follow-up.
- **Dynamic evaluation / D5 lazy splitting.** The "upfront factorization" choice
  deliberately avoids the non-field quotient ring, so no splitting machinery is
  needed.
- **Cross-field composite generators** (combining ℚ(α) and ℚ(β) into one field
  via a primitive element). Different generators fall back to the resultant path;
  building a shared primitive element is a follow-up, not needed for the
  single-generator headline.

## Grounding

- Representation and the single-generator principle: `[bpr2006 §12.4, Rational
  Univariate Representation]`.
- The doubly-exponential blowup of the naive multivariate path that motivates it:
  `[bpr2006 §12]`.
- Exact sign of a polynomial value at an algebraic point (the `sign` arm):
  consistent with `[bpr2006 §10.3]`.
- The shared field for axiom 7's creases (all coordinates rational in the one
  landing parameter): the cubic Beloch fold `[justin1986 §2; hull2020 §2.3–2.4]`.

## Build order (for the plan)

1. `gen` type + `Field` constructor + field arithmetic (`add/sub/mul/neg`) with
   the syntactic zero-test — unit-tested in isolation (α from `x³−2`, `t²−4t+1`).
2. `inv`/`div` (extended Euclid mod μ) + `sign` (interval eval) + `compare`/
   `equal`/`to_float` arms.
3. Factorization helper (rational-root + ≤3 irreducibility) → μ extraction;
   wire `real_roots` to return `Field` for factorable roots.
4. Interop + `Field → Alg` fallback for mixed/cross-field operations.
5. The no-blowup geometry guard + end-to-end doubling-the-cube fold test; full
   regression.
