# Axiom 6 — fold a point onto a line, crease through a fixed point

**Status:** design approved, ready for implementation plan
**Slice:** v0.8-dev (next free slice after v0.7-dev action model)
**Surface:** `map .p onto --d through .p'` (`toward .x` when two solutions)

## What it is

Justin operation **⑥** `(P → D, P' → P')`: fold point `P` onto line `D` with a
single crease that keeps a second point `P'` fixed (`P'` maps to itself). Because
`P'` lies on the crease, it is equidistant from `P` and its image `P''` on `D`,
so `P''` is the intersection of the **circle** centred at `P'` with radius
`|P'P|` and the line `D` `[justin1986, §8.2c, l.156]`. Up to two such landing
points, hence up to two creases. The result is the **perpendicular bisector of
`P` and `P''`**, and it always passes through `P'`.

This is a **second-degree** operation `[justin1986, §8.1 table, l.127]`
("Solution équation du 2e degré", 0/1/2 solutions). It stays inside the existing
constructible-real `Num` (square roots only) — **no cube roots, no number-kernel
change.**

### Numbering — read this before touching the spec

Beloch follows **strict Justin numbering**, verified against the §8.1 table in
`refs/justin1986.md`: axioms 1–5 map exactly onto Justin ①–⑤ (line, médiatrice,
perpendicular, projection, bisector). Therefore:

| Beloch | Justin | operation | degree | solutions |
|---|---|---|---|---|
| axiom **5** (shipped) | ⑤ | `(D → D')` bisector | 2 | 1, 2 |
| axiom **6** (this slice) | **⑥** | `(P → D, P' → P')` | **2** | 0, 1, 2 |
| axiom **7** (future) | ⑦ | `(P → D, P' → D')` the Beloch fold | **3** | 0, 1, 2, 3 |

The project's earlier memory/ADR shorthand ("axiom 6 = the cubic") **conflated
⑥ and ⑦** and is wrong against the committed numbering. The exact trap was
already flagged in `notes/2026-06-29-axiom5.md:57`. **Axiom 6 = Justin ⑥, the
quadratic.** The cubic Beloch fold is Justin ⑦ → Beloch **axiom 7**, a separate
future slice that needs a real-algebraic number kernel (cube roots; casus
irreducibilis means real radicals do not suffice).

## Syntax

```
map .p onto --d through .p'              # ≤1 solution
map .p onto --d through .p' toward .x    # 2 solutions: pick landing nearer .x
```

- `.p` — the point to fold onto the line (point operand)
- `--d` — the target line it lands on (line operand)
- `.p'` — the fixed point the crease must pass through (point operand)
- `toward .x` — optional selector, required only when there are two solutions

`through` is reused from the axiom-3 statement verb (`perp --l through .p`): in
both spellings it means "the crease passes through this point". `toward` is
reused from axiom 5's selector — one disambiguation vocabulary across all
multi-solution axioms; no synonym (`closer` etc.) is introduced.

Inline anonymous operands compose as elsewhere, e.g.
`map .p onto --(.a .b) through .(--m --n) toward .x`.

### Grammar / AST

New rules in `parser.mly`:

```
| MAP point_operand ONTO line_operand THROUGH point_operand
    { MapThrough ($2, $4, $6, None) }
| MAP point_operand ONTO line_operand THROUGH point_operand TOWARD point_operand
    { MapThrough ($2, $4, $6, Some $8) }
```

New AST variant in `ast.ml`:

```ocaml
| MapThrough of point_operand * line_operand * point_operand * point_operand option
    (* axiom 6 *)
```

No LR conflict: after `MAP point_operand ONTO line_operand`, the next token is
`PERP` for axiom 4 versus `THROUGH` for axiom 6 — distinct keywords. The trailing
`TOWARD point_operand` mirrors axiom 5's optional selector. All tokens (`MAP`,
`ONTO`, `THROUGH`, `TOWARD`) already exist.

## Geometry

All square-root, never cube-root — operation ⑥ lives in the quadratic tower
`[justin1986, §8.2c]`. The radius **squared** `|P'P|²` is exact (no sqrt); a
single sqrt appears only in the circle∩line discriminant, absorbed by `Num.sqrt`.

New helper in `geom.ml`:

```
beloch_creases (p : point) (d : line) (p' : point) : line list
  r2   = (p.x−p'.x)² + (p.y−p'.y)²              (* exact, in Num *)
  hits = circle_line_intersection ~center:p' ~r2 d   (* 0, 1, or 2 points *)
  for each hit q:
    if point_equal q p then drop                 (* identity, no fold *)
    else perpendicular_bisector p q              (* passes through p' by construction *)
```

`circle_line_intersection` is a new `geom.ml` primitive: substitute the line into
`(x−cx)² + (y−cy)² = r2`, solve the resulting quadratic, return 0/1/2 points.
Returns the tangent point once when the discriminant is zero.

The eval handler returns `(crease, "axiom6", sources)`, matching the shape used
by axioms 1–5.

## Eval

Mirror axiom 5's `toward` resolution (`lib/eval.ml`):

- **0 creases** → error: `"cannot fold .p onto --d through .p': out of reach"`.
- **1 crease** → return it; `toward` is optional here and ignored if supplied.
- **2 creases** → require `toward .x`; pick the crease whose landing point `P''`
  is nearer `.x` (exact `Num` distance-squared comparison). Missing selector →
  error: `"two folds place .p onto --d through .p'; add 'toward .x'"`.
- tag `"axiom6"`, sources `[pstr p; lstr d; pstr p']` (plus `pstr x` when the
  selector is present).
- `@` fold default moving side = `side_of_line crease p` — `P` is the point that
  moves onto `D` (same pattern as axiom 2's `MapPoints` default).

## Edge cases

1. **`dist(p', D) > |p'−p|`** → circle misses the line → 0 hits → out-of-reach
   error.
2. **Tangent** (`dist(p', D) = |p'−p|`) → 1 solution (double root); no selector
   needed.
3. **`p = p'`** (radius 0): the circle is the single point `p'`; it meets `D`
   only when `p' ∈ D`, which is exactly Justin's forbidden `¬(P = P' ∈ D)`.
   Otherwise 0 hits. Both paths → error (the out-of-reach message covers the
   `p' ∉ D` case; add an explicit guard for `p = p' ∈ D`).
4. **`p ∈ D`**: one landing point equals `p` itself (folding `p` onto where it
   already sits — the identity). It is dropped (`point_equal q p`), and the
   mirror landing across the foot of the perpendicular from `p'` gives the real
   crease. If both landings are degenerate → 0 creases → error.
5. **`p' ∈ D`** (with `p ≠ p'`): allowed (the constraint forbids only
   `p = p' ∈ D`). The circle is centred on `D`, giving two symmetric landing
   points and two creases through `p'`. Normal two-solution case.

## Output

Identical wiring to axioms 4 and 5. The crease participates in:

- mountain/valley direction (the M/V `fold_spec` is orthogonal to the geometry)
- FOLD emission — `creasePattern` and `foldedForm` frames
- diagram label `axiom6`
- the `@` fold modifier — works with no extra wiring (moving side defaults to `p`)

## Tests

Mirror the axiom-5 cases in `tests/test_beloch.ml`:

1. **Two solutions + `toward`** — assert the exact rational/`Num` crease for the
   selected landing point.
2. **Single solution** (tangent) — assert the unique crease, with and without
   `toward`.
3. **Out-of-reach error** — `dist(p', D) > |p'−p|` raises the out-of-reach error.
4. **Ambiguous without selector** — two solutions, no `toward`, raises the
   "add 'toward .x'" error.
5. **`p ∈ D` degenerate landing dropped** — assert exactly one non-trivial
   crease is returned.
6. **Pivot invariant** — assert every returned crease passes through `p'`
   (exact: `side_of_line crease p' = 0`).
7. **Inline operands** — `map .p onto --(.a .b) through .p' toward .x` parses and
   evaluates.

## Docs

- `spec/SPECIFICATION.md`: new section **§4.5b Axiom 6 — fold a point onto a
  line, crease through a fixed point** *(since v0.8-dev)* (placed after §4.5a so
  the axiom sections stay contiguous), with the grammar block, the
  circle∩line geometry, the errors, the `toward` selector, and a pointer to the
  numbering table above. Add the production to the grammar EBNF. Note explicitly
  that cube roots still do not arise (they wait for axiom 7).
- `notes/2026-06-30-axiom6.md`: design-journal entry — the **numbering
  resolution** (axiom 6 = Justin ⑥ quadratic; cubic ⑦ deferred to axiom 7), the
  stays-in-the-quadratic-tower property, the circle∩line construction.
- Correct the roadmap memory note that said "axiom 6 = the cubic".
- `paper/references.bib` / `bibliography.md`: no new source — `justin1986`
  already present.

## Out of scope

- The cubic **Beloch fold** (Justin ⑦ → Beloch axiom 7) and the real-algebraic
  number kernel it requires. This slice introduces **no** `Num` extension.
- No synonym keyword for `toward`.
- No multi-result return — one crease per statement, as in axioms 1–5.
