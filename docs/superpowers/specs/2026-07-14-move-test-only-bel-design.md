# Move test-only `.bel` out of `examples/` into `tests/cases/`

## Problem

`examples/` does double duty: human-facing illustrative programs *and* the
regression corpus. `test_golden.ml` walks every `.bel` under `examples/` and
snapshots its FOLD; many of those files are contrived feature/error probes with
no illustrative value. With the new inline-assertion harness
(`tests/test_bel_assert.ml`, walks `tests/cases/**/*.bel`) those probes belong in
`tests/cases/` carrying their own `; assert` / `; expect error` lines, leaving
`examples/` for load-bearing illustrations only (cf. the example-discipline
principle).

## Scope

Move the **21** clearly test-only files. Excluded:

- `crease-all-fold-some.bel`, `fold-top-flap.bel` — already mid-migration on
  `main` by a parallel session (uncommitted `tear` behaviour change + their own
  `tests/cases/fold/tear-*.bel`). Do not touch, avoid the collision.
- `fold-quarter.bel` — de-facto **shared fixture**: read by 3 TypeScript suites
  (`render/scene`, `render/render-svg`, `site/lib`) plus 2 OCaml e2e cases,
  including the exact `faceOrders` layer-order regression that the inline grammar
  **cannot** express. Relocating it is a 5-file, two-language churn for coverage
  the harness can't replace. Leave in place; separate follow-up if desired.

The illustrative set stays in `examples/`: `bases/*`, `syntax/cube-root`,
`syntax/x-midpoint`, `syntax/diagonals`, `syntax/perp`, `syntax/bisect-a`,
`syntax/bisect-straddle`, and the "unsure" band (`through`, `project`,
`crease-at-flap`, `square-centre`, `fold-top-two`).

## Isolation

Work in an in-repo worktree based on the **commit** `9b028fd` (local `main`
HEAD: has the harness + spec docs, still has the examples, and — being a commit —
excludes the parallel session's uncommitted `tear` work). A `dune-workspace`
file pins the build root inside the worktree (untracked build aid, not
committed).

## Target layout (`git mv`, keep basenames)

- `tests/cases/collapse/` (7): collapse-all-valley, -ambiguous, -ambiguous-over,
  -duplicate-ray, -kawasaki, -midpaper, -standing
- `tests/cases/mark/` (6): def-diagonals, bisect-b, bisect-parallel, dup-point,
  parallel, square
- `tests/cases/fold/` (8): fold-half, flip-mountain, fold-along, multiple-folds,
  fold-straddle-fresh-cut, crease-flip-reuse, complex-fold, inline-midpoint

## Per-file assertions

Assertion grammar is limited (point/line `=`, `incident`, `is
mountain/valley/boundary`, `faces = N`, `steps = N`, `expect error "substr"`).
`faces = N` values come from the current goldens; point asserts on folded sheets
use the `paper` qualifier to dodge the table-layer-ambiguity guard.

### collapse/ (all `git mv` from `examples/syntax/`, delete matching golden)

| file | assertions | e2e |
|---|---|---|
| collapse-all-valley | `expect error "Maekawa"` | none |
| collapse-ambiguous | `expect error "ambiguous stacking"` | none |
| collapse-ambiguous-over | `faces = 8`; `.rm paper = (1, 1/2)`; `.tm paper = (1/2, 1)` | none |
| collapse-duplicate-ray | `expect error "duplicate ray"` | none |
| collapse-kawasaki | `expect error "flat-foldable"` | none |
| collapse-midpaper | `expect error "Maekawa"` (header comment is stale; golden says Maekawa) | none |
| collapse-standing | `expect error "standing"` | none |

### mark/ (`git mv` from `examples/syntax/`)

| file | assertions | e2e action |
|---|---|---|
| def-diagonals | `faces = 4`; `.m = (1/2, 1/2)`; `steps = 3` | **delete** `test_e2e_def_diagonals` |
| bisect-b | `faces = 3` | **keep + repoint** `test_e2e_bisect_select` (also reads bisect-a, which stays) |
| bisect-parallel | `faces = 2` | **delete** `test_e2e_bisect_parallel` |
| dup-point | `expect error "same place"` | **delete** `test_e2e_anti_dup` |
| parallel | `expect error "parallel"` | **delete** `test_e2e_anti_parallel` |
| square | `faces = 1` | **delete** `test_e2e_square_one_face`; **keep + repoint** `test_e2e_faces_matrix_and_frame` (identity isometry — not expressible inline) |

### fold/ (`git mv`; syntax/ or examples/ root as noted)

| file | assertions | notes / e2e |
|---|---|---|
| fold-half (syntax/) | `faces = 2`; `--half is valley` | **name the fold** `fold --half = …`; **delete** `test_e2e_fold_half` |
| flip-mountain (syntax/) | `faces = 2`; `--m is mountain` | **name the fold** `fold --m = …`; e2e is inline, untouched |
| fold-along (root) | `faces = 2`; `--d is valley` | none |
| multiple-folds (root) | `faces = 6`; `steps = 2`; `--v is valley`; `--b is boundary` | none |
| fold-straddle-fresh-cut (root) | `faces = 6`; `.ctr paper = (1/2, 1/2)`; `--ac is valley` | none |
| crease-flip-reuse (syntax/) | `faces = 4` | none |
| complex-fold (syntax/) | `faces = 4`; `.mid paper = (1/2, 0)`; `--b is boundary` | none |
| inline-midpoint (syntax/) | `faces = 6` | none |

Assertions marked as guesses (`is valley/mountain`, `steps`, point positions) are
verified by running `dune test`; the harness is the oracle — a wrong value is
corrected or the over-reaching line dropped, `faces = N` is the certain backbone.

## Coverage accounting

- Fully replaced by inline → e2e case deleted: `anti_dup`, `anti_parallel`,
  `def_diagonals`, `bisect_parallel`, `fold_half`.
- Non-expressible residual → e2e case **kept, path repointed** into
  `tests/cases/`: `faces_matrix_and_frame` (square identity isometry),
  `bisect_select` (axiom5 tag + bisect-a≠bisect-b).
- Knowingly lost (no inline equivalent, no separate regression value worth
  keeping a case for): layer order / frame-class on the works probes that had no
  e2e case anyway.

## Golden

Delete the 21 matching `tests/golden/**/*.fold` (and any `_pre_slice1` copies).
`test_golden.ml` needs no code change — it walks whatever remains in `examples/`.

## Verify

`dune build` + `dune test` green (bel_assert picks up the 21 new cases; golden no
longer references the moved files; e2e passes with 5 cases removed and 2
repointed). Then draft PR.
