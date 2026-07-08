# `@flatten` — flat single-vertex solver (design)

## Status

Proposed (2026-07-07). Semantics settled; **surface selector syntax is
provisional** and adopts the outcome of the separate selector/type
formalisation (see *Open questions*). This document fixes the *contract*, not
the final spelling of the selectors.

## Motivation — the emergent-crease problem

Some flat folds require a crease that **no Huzita axiom can construct** from the
sheet's existing points. The canonical case is a rabbit-ear formed by a swivel
(fold two hinges, tuck the reflex flap flat to one side).

Worked out exactly on `examples/iteration/005.bel` (verified against the running
kernel): with the vertex `o = (1/2, 11/48) ≈ (0.5, 0.229)` and hinges reaching
the side edges at height `11/24 ≈ 0.4583`, the collapse is flat **iff** a
mountain crease runs from `o` at **319.25°**, meeting the base at `x ≈ 0.766`.
Kawasaki closes to **0** there — and nowhere a bisector lands: the naive
`bisector(o→bm, o→b)` gives `302.7°` (`x = 0.647`), ~16° off. That crease is not
the output of any single `map`/`through`/`perp` on the named points — it is
**forced by flat-foldability**, and can only be *solved for*.

`@collapse` (§4.9) *validates* a fully specified crease set; it cannot derive a
missing crease. So the swivel rabbit is currently inexpressible. The families
that need this — rabbit ear (swivel), petal, squash — are exactly the ones
Appendix B defers.

## Decision

Add **one primitive, `@flatten`**: a flat single-vertex solver. Given a vertex
and a set of *fixed* creases, it **derives the remaining creases** that make the
vertex flat-foldable, then folds. The disambiguation of *which* flat state is
carried by a mandatory directional operand.

`@collapse` is **removed**: it is exactly `@flatten` with every crease fixed and
nothing to derive (validate-only). It survives as a usage pattern, not a
statement (see *Migration*). No named maneuver becomes a keyword — `rabbit`,
`petal`, `squash` are, at most, optional stdlib `def`s over `@flatten`.

## The operation

### Inputs

1. **The crease lines at the vertex.** Two (or more) full crease lines
   (`--ba --bb`). Their intersection is the vertex `o` (derived — no explicit
   `.o`). They partition the neighbourhood of `o` into sectors.

2. **The stayer sector** — a **flap-operand** marked `stays`:
   `(#(.m) stays)`, with `.m` sugar for `#(.m)` (ADR 0016: a bare point is a
   one-element incidence constraint; any object that determines the flap
   uniquely is accepted, else an ambiguity error). The named sector stays at the
   identity isometry; **its two bounding rays become the hinges**, and the
   complementary reflex region (`>180°`) is what folds. This is how the hinges
   are chosen *without* a per-ray `at` selector — you point into the region that
   stays, not at the rays.

   For validate-only use (old `@collapse`), the fixed creases are instead listed
   explicitly as ray-selectors — the `stays` shorthand covers the common
   two-hinge case; a fuller fixed set is given directly. (The exact spelling of
   both is provisional; see *Open questions*.)

3. **A directional operand (mandatory in the derive case):**
   - **`toward <point>`** — swing the folding flap *as one piece* toward that
     side; the solver returns the **minimal-crease** flat state (the rabbit).
     The point need only indicate the **side** (e.g. `.b`, a corner) — the exact
     emergent crease is *derived*, never constructed. Reuses the existing metric
     disambiguator `toward` (axioms 5–7).
   - **`onto <point | line>`** — pin the emergent flap's tip to an exact landing
     (petal; asymmetric petal when the target is an off-axis point; symmetric
     when it is the fold axis `--v`). For when the landing is a *choice*, not a
     derivation. Reuses `onto` (`@map`/axiom 2).

   Rule that makes `toward` unambiguous: **`toward` yields the fewest-crease
   solution.** Petal splits the excess into more creases, so it is not minimal
   and must be requested explicitly with `onto`.

4. **`over` clauses (optional)** — layer ordering, inherited verbatim from
   `@collapse` §4.9 (`<flap> over <flap>`; a point denotes its sector). Required
   only when more than one valid stacking survives, else `ambiguous stacking`.

Provisional surface form (spelling adopts the selector formalisation):

```
@flatten (--ba) (--bb) (#(.m) stays) toward .b            ; rabbit, right
@flatten (--ba) (--bb) (#(.m) stays) onto --v             ; petal, symmetric (v2)
@flatten (--ba) (--bb) (#(.m) stays) toward .b  .bm over .b   ; + layer pick
```

### Derivation

- **Vertex.** `o` = the common intersection of the given lines. Error if they do
  not meet at a single strictly-interior point.
- **Hinges.** The two boundary rays of the `stays` sector (each a segment of one
  input line). The stayer point must lie strictly inside a sector; on a boundary
  line → error.
- **Emergent creases.** With the hinges fixed and the `toward`/`onto` constraint,
  the solver finds the flat completion of the vertex: it adds the crease(s) that
  satisfy Kawasaki exactly (real-algebraic kernel, ADR 0012/0013) and pressing
  toward the target. For `toward` this is the unique minimal-crease solution.
  M/V assignment and layer ordering follow (the fan construction and stacking
  enumeration of §4.9 apply once the crease set is complete).

### Determinism

`(lines, stays, toward)` fixes the **crease geometry and M/V** uniquely — the
three flat completions of a two-hinge vertex are *symmetric (spine)*,
*swivel-left*, *swivel-right*; `toward` selects among them by side, and
minimality rules out petal. **Layer ordering** may still be ambiguous → `over`,
exactly as `@collapse`.

### Return value

`@flatten` *creates* creases, so — like `@map` and the axiom folds — it is
**bindable**. This matters *more* than for `@fold`: the emergent crease has no
construction, so binding is the **only** way to name it.

```
--r = @flatten (--ba) (--bb) (#(.m) stays) toward .b
```

Recommended shape (final form pending the selector work): `--r` binds a
**bundle of the emergent creases** this collapse produced (a rabbit derives
two — a centre fold and the swivel; in 005 the centre lands on the already-named
`--v`, so often only one is genuinely new), and the emergent **tip point** is
exposed so downstream statements have something to select against:

```
.tip = .(--r --(.a .b))     ; the derived tip on the base, now referenceable
```

Open: whether the binding is a single bundle addressed by incidence, or a
multi-name binding (`--centre --swivel = @flatten …`). Tied to the selector
formalisation.

### Errors

| condition | outcome |
|---|---|
| lines share no single interior vertex | error |
| stayer point on a boundary line (not strictly in a sector) | error |
| stayer sector `= 180°` (hinges collinear) | error: use a simple `@fold` |
| stayer sector `> 180°` (reflex chosen as the kept side) | not allowed |
| no flat completion for the given `toward`/`onto` | `vertex not flat-foldable` (with reason) |
| the derived assignment self-intersects | `assignment forces self-intersection` |
| more than one valid stacking, no `over` | `ambiguous stacking (<k> orders)` |
| `over` rules out every stacking | `contradictory over` |

(Checks reuse §4.9 machinery where the crease set is complete.)

## Migration — `@collapse` removed

`@collapse` was validate-only: a fully specified crease set, nothing derived.
That is `@flatten` with all creases fixed and no directional operand. The
shipped examples move over:

- `examples/bases/rabbit-ear.bel`, `examples/bases/waterbomb.bel` — restate the
  full ray list under `@flatten` (validate mode).
- `examples/iteration/005.bel` — gains the `@flatten (--ba)(--bb)(#(.m) stays)
  toward .b` collapse it was building toward, in derive mode.

## Scope

- **v1 ships `toward` (rabbit)** — fully understood and verified (005).
- **`onto` (petal) is syntactically reserved**; its exact geometry (crease
  count, asymmetry parameterisation, uniqueness under a single landing target)
  is a separate exact-geometry pass, deferred.
- **squash / reverse** are future stdlib `def`s over `@flatten`; the ones that
  reduce to a determinate flat single-vertex derivation fall out for free, the
  ones needing `unfold` or a 3-D intermediate wait for ADR 0015 / Appendix B.
- **No maneuver keywords.** `rabbit`/`petal`/`squash` are directions you point,
  or optional library `def`s — never grammar.

## Open questions

1. **Surface selector syntax.** `#(…) stays`, the `stays`/`toward`/`onto`
   spelling, and how a fixed crease list is written all depend on the pending
   **selector/type formalisation** (its own brainstorm/ADR): unifying
   `at` / `#()` / `in` / `crossing` into one context-typed filter, and deciding
   whether `face` and `flap` are one type or two. This document commits to the
   *contract*; the spelling follows that work.
2. **Return binding shape** — single emergent-bundle vs multi-name (above).
3. **Petal geometry** — the exact `onto` solution space.

## References

- ADR 0011 (action model), 0012/0013 (real-algebraic kernel — exact emergent
  creases), 0014 (crease = bundle of segments), 0015 (flat-folded states only —
  why squash/reverse wait), 0016 (typed operands — the flap-operand `stays`
  takes), 0017 (face vs flap granularity — the `#()` context-typing this builds
  on).
- `spec/SPECIFICATION.md` §4.6 (`@fold`), §4.9 (`@collapse`, being removed),
  §5a (`def`/`apply` — the optional maneuver library).
- `examples/iteration/005.bel` — the construction that makes the emergent crease
  concrete; verified numbers above.
