# Beloch v0.0 — Minimal Core (design spec)

Status: **design approved 2026-06-28**, not yet implemented.
First increment per [decision 0003](../decisions/0003-restart-from-minimal-core.md).
This document is the spec the implementation plan is built from; it grows into
the permanent language spec as later increments land.

## 1. Goal & scope

v0.0 is the **thinnest vertical slice that runs end-to-end**: a `.bel` program
parses, evaluates, and emits a valid FOLD file a FOLD viewer can open. Geometry
is exact; the surface language is deliberately tiny.

**In scope**

- A single square sheet of paper.
- Two of the Huzita-Justin axioms: **O1** (line through two points) and **O2**
  (bring one point onto another / perpendicular bisector).
- Naming: bind creases (`--name`) and derive points (`.name`), reusable in later
  statements.
- Exact rational (ℚ) geometry — no floating-point epsilon.
- Crease-crease intersections computed analytically and split into a clean
  planar graph (vertices + edges).
- Output: valid FOLD with `beloch:*` provenance.

**Out of scope (deferred, in rough later order)**

folded state · mountain/valley direction · faces (`faces_vertices`) · axioms
3–7 · regions · parts/imports · `step` blocks · `flip`/`rotate` · YR diagrams ·
LSP · Tree-sitter grammar.

## 2. Surface language

> Syntax is **provisional** — semantics and architecture are the committed part;
> concrete spellings (`paper square`, `through`, `cross`, sigils) may be revised.

Sigils inherited from the 2018 design: `.name` is a **point**, `--name` is a
**crease/line**. `;` begins a line comment.

```
; both diagonals + their midpoint
paper square

--d1: through .a .c          ; O1 — line through two points
--d2: fold .b to .d          ; O2 — bring .b onto .d (perpendicular bisector)
.center: cross --d1 --d2     ; derived point = intersection of two creases

fold .a to .center           ; anonymous crease, uses the derived point
```

- `paper square` — declares a unit square. Corners are pre-bound:
  `.a=(0,0) .b=(1,0) .c=(1,1) .d=(0,1)`, counter-clockwise.
- Crease statement, named (`--n: <axiom>`) or anonymous (`<axiom>`).
- Statements execute top to bottom; a name must be defined before use.

### Grammar sketch (informal; the Menhir grammar is authoritative once written)

```
program     := "paper" "square" stmt*
stmt        := crease_stmt | point_stmt
crease_stmt := [ CREASE_NAME ":" ] axiom
point_stmt  := POINT_NAME ":" point_expr
axiom       := "through" point_ref point_ref      ; O1
             | "fold" point_ref "to" point_ref    ; O2
point_expr  := "cross" CREASE_NAME CREASE_NAME    ; intersection of two creases
point_ref   := POINT_NAME
POINT_NAME  := "." ident
CREASE_NAME := "--" ident
```

## 3. Semantics

### Points

The four corners plus any derived points. A derived point from `cross` is a
first-class value usable as a `point_ref` in subsequent axioms.

### Axioms

- **O1 `through .x .y`** — the unique line through `.x` and `.y`.
  Error if `.x` and `.y` are the same point.
- **O2 `fold .x to .y`** — the perpendicular bisector of segment `x–y` (the
  crease that brings `.x` onto `.y`). Error if `.x` and `.y` are the same point.

A crease's geometric value is an infinite line; for output it is **clipped** to
the paper polygon, yielding a segment.

### Derived points

- **`cross --c1 --c2`** — the analytic intersection of the two creases' lines.
  - Error if the lines are **parallel** (no intersection).
  - Error if the intersection point is **not on the paper** (point-in-polygon
    test decides). "On the paper" includes the boundary.

### Exactness

All coordinates and line coefficients are exact rationals (`zarith`, ℚ). A line
is stored as `a·x + b·y = c` with `a,b,c ∈ ℚ`. For O1+O2 over rational inputs,
ℚ is closed: bisectors of rational points are rational lines, and intersections
of rational lines are rational points. **No epsilon, no tolerance, no sampling.**
Equality, parallelism, and point-in-polygon are exact comparisons.
(The boundary where ℚ stops being closed — `sqrt`/cubics in axioms 5/6 — is a
known future decision, not a v0.0 concern. See
[antipatterns.md](../antipatterns.md).)

## 4. Evaluator architecture

Staged pipeline (per [decision 0007](../decisions/0007-evaluator-not-compiler.md)):

```
.bel
  → Lexer  (sedlex)
  → Parser (menhir)         → AST
  → Resolve                 → names (.point / --crease) bound in an environment
  → Eval                    → geometric crease-pattern state, exact ℚ
  → Planarize               → split crease segments at on-paper intersections,
                              dedup vertices  → clean planar graph (no faces)
  → Emit                    → FOLD JSON (yojson)
```

OCaml modules (in `lib/`):

| Module | Responsibility |
|--------|----------------|
| `ast.ml` | AST types for program/statements/axioms/expressions, with source spans |
| `lexer.ml` | sedlex lexer |
| `parser.mly` | menhir grammar → AST |
| `geom.ml` | `Point`/`Line` over ℚ; line-through-two-points, perpendicular bisector, line∩line, clip-to-polygon, point-in-polygon |
| `resolve.ml` | name resolution; environment of points and creases; undefined-name errors |
| `state.ml` | `crease_pattern`: paper polygon, vertices (deduped), edges (with assignment + provenance) |
| `eval.ml` | walk the resolved AST, apply axioms, build state |
| `planarize.ml` | compute pairwise on-paper crease intersections, split edges, dedup vertices |
| `fold_emit.ml` | serialize state → FOLD JSON |
| `error.ml` | diagnostics with source spans |

`bin/main.ml` wires `beloch fold FILE.bel`.

State threaded through eval: a `crease_pattern` record
`{ paper : polygon; vertices : point list (deduped); edges : edge list }` where
`edge = { v0; v1; assignment; provenance }`, plus the name environment mapping
point names → `Point` and crease names → `Line` (with the clipped segment).

## 5. FOLD output

Emitted top-level fields:

- `file_spec`, `file_creator: "beloch 0.0.0-dev"`,
  `frame_classes: ["creasePattern"]`
- `vertices_coords` — `[x, y]` per vertex (ℚ rendered to JSON decimal; internal
  values stay exact)
- `edges_vertices` — `[v0, v1]` index pairs
- `edges_assignment` — `"B"` for the four paper-boundary edges, **`"U"`**
  (unassigned) for every crease. v0.0 does not model fold direction, so claiming
  `"V"` would assert something uncomputed; `"U"` is the honest label.
- `beloch:edges` (extension) — per crease edge: originating axiom (`"O1"`/`"O2"`),
  source point/crease names, and source span, for provenance and source mapping.

## 6. Error handling

All errors are compile errors carrying a source span; first matching error wins;
process exits non-zero. Cases:

- parse error (menhir)
- O1/O2 with two identical points
- `cross` on parallel creases
- `cross` whose intersection is off the paper
- reference to an undefined point or crease name

## 7. Testing

- **Unit** (`geom`): known ℚ cases — e.g. the two diagonals intersect exactly at
  `(1/2, 1/2)`; clipping a diagonal to the unit square; point-in-polygon on
  boundary and interior.
- **Golden**: `examples/*.bel` → expected `*.fold`. At minimum: "both diagonals"
  and "X with named midpoint".
- **Examples** live in `examples/` tagged `works` (must evaluate) and `anti`
  (must raise the expected error) per
  [examples/README.md](../examples/README.md).

## 8. Success criterion

`beloch fold examples/diagonals.bel` produces a FOLD file that opens in a FOLD
viewer and shows the correct crease lines, with exact coordinates and a vertex
at every on-paper crease intersection.
