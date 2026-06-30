# Axiom 4 — project a point onto a line, crease perpendicular to a second line

**Status:** design approved, ready for implementation plan
**Slice:** v0.4-dev
**Surface:** `map .p onto --l1 perp --l2`

## What it is

Classic Justin operation **④** `(P → D, D' → D')`: bring point `P` onto line
`D` with a single fold whose crease keeps line `D'` fixed — equivalently, the
crease is **perpendicular to `D'`**, and `P` is moved **parallel to `D'`** onto
`D`. The result is the *projection of `P` onto `D` parallel to `D'`*
[[justin1986, §8.1]].

### Numbering — read this before touching the spec

This operation is numbered differently in every common source. Beloch follows
the **classic Justin numbering**, where it is **axiom 4**.

| operation | Wikipedia (Huzita–Hatori) | classic Justin | Beloch |
|---|---|---|---|
| perpendicular through a point | O4 | ③ | axiom **3** (shipped, v0.2) |
| project P→l1, crease ⊥ l2 | **O7** | **④** | axiom **4** (this slice) |

So Beloch's axiom 4 is Wikipedia's **O7** ("place `p` onto `l1` with a fold
perpendicular to `l2`"), *not* Wikipedia's O4. Wikipedia's O4 is Beloch's
already-shipped axiom 3. This clash is exactly the trap recorded in
`antipatterns.md` and §1 of the spec.

"crease ⊥ l2" and "l2 maps onto itself" and "projection parallel to l2" are
three framings of the same constraint.

## Syntax

```
map .p onto --l1 perp --l2
```

- `.p` — the point to project (point operand)
- `--l1` — the target line it lands on (line operand)
- `--l2` — the line the crease is perpendicular to (line operand)

`perp` is reused from the axiom-3 statement verb (`perp --l through .p`). The
overload is intentional: both spellings mean "perpendicular to a line". No
`toward` selector — the operation has at most one solution and is never
ambiguous.

Inline anonymous operands compose as elsewhere, e.g.
`map .p onto --(.a .b) perp --l2`.

### Grammar / AST

New rule in `parser.mly`:

```
| MAP point_operand ONTO line_operand PERP line_operand
    { MapOntoLine ($2, $4, $6) }
```

New AST variant in `ast.ml`:

```ocaml
| MapOntoLine of point_operand * line_operand * line_operand  (* axiom 4 *)
```

No LR conflict with axiom 2 (`MAP point ONTO point`) or axiom 5
(`MAP line ONTO line …`): after `MAP point_operand ONTO`, the next operand is a
point (`.x` / inline) for axiom 2 versus a line (`--x` / inline) for axiom 4,
distinguishable by the operand's leading token. The `PERP` token already exists.

## Geometry

All exact, all rational — operations ①–④ never leave ℚ
[[justin1986, §8.2a]]. No `sqrt`, no extension of `Num`.

```
m       = line through p parallel to l2     (a = l2.a, b = l2.b, c = l2.a·p.x + l2.b·p.y)
Q       = intersection(m, l1)               (the landing point on l1)
crease  = perpendicular_bisector(p, Q)      (automatically ⊥ l2, since p→Q is ∥ l2)
```

The eval handler returns `(crease, "axiom4", [pstr p; lstr l1; lstr l2])`,
matching the shape used by axioms 1/2/3/5.

A small helper is needed in `geom.ml` to build a line through a point parallel
to a given line (one normal-form construction), or it can be inlined in the
handler.

## Edge cases

1. **`l1 ∥ l2`** → `m ∥ l1` → no intersection → **error**:
   `"map onto line: l1 parallel to l2, no fold exists"`.
   This single guard subsumes both of Justin's degenerate sub-cases: `D ∥ D'`
   with `P ∉ D` (zero solutions) and `D ∥ D'` with `P ∈ D` (infinitely many,
   forbidden by Justin's constraint `¬(P ∈ D ∧ D ∥ D')`).

2. **`p ∈ l1`** (with `l1 ∦ l2`) → `Q = p` → the perpendicular bisector is
   degenerate. The well-defined solution is the perpendicular to `l2` through
   `p` (`perpendicular_through l2 p`), which fixes `p` and trivially keeps it on
   `l1`. Detect `Q = p` and return this crease. Exactly one solution, consistent
   with Justin's count.

## Output

Identical to axioms 3 and 5. The crease participates in:

- mountain/valley direction (the `perp` constraint keyword is orthogonal to the
  M/V `fold_spec`)
- FOLD emission — `creasePattern` and `foldedForm` frames
- diagram label `axiom4`
- the `@` fold modifier — works with no extra wiring

## Tests

Mirror the axiom-3 / axiom-5 cases in `tests/test_beloch.ml`:

1. **Basic projection** onto a slanted line — assert the exact rational crease
   coefficients.
2. **`p ∈ l1` degenerate** — assert the crease equals the perpendicular to `l2`
   through `p`.
3. **`l1 ∥ l2` error** — assert the parallel-lines error is raised.
4. **Perpendicularity invariant** — assert the resulting crease is exactly
   perpendicular to `l2`.
5. **Inline operands** — `map .p onto --(.a .b) perp --l2` parses and evaluates.

## Docs

- `spec/SPECIFICATION.md`: new section **§4.5a Axiom 4 — project a point onto a
  line** *(since v0.4-dev)*, with the grammar block, the geometry, the error,
  and a pointer to the numbering table above. Add the production to the grammar
  EBNF. Bump the "Current version" line to mention v0.4-dev (axiom 4).
- `notes/2026-06-30-axiom4.md`: design-journal entry (the numbering clash, the
  stays-in-ℚ property, the projection construction).
- `paper/references.bib` / `bibliography.md`: no new source — `justin1986`
  already present.

## Out of scope

- No new `Num` capability (no cube roots — that arrives with axiom 6).
- No `toward`-style selector (not needed; ≤1 solution).
- No general unconstrained point-onto-line (`map .p onto --l1` alone) — that is
  axioms 6/7, future slices.
