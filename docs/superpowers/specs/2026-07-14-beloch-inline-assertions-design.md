# Beloch inline assertions — a `.bel` test format

**Date:** 2026-07-14
**Status:** design, v1
**Motivation:** `examples/` mixes docs-showcases and per-feature behaviour
tests with no mapping between an example and the behaviour it pins. Introduce a
Beloch-native test format: a `.bel` file carries its own expected outcome as
trailing `;`-comment assertions, extracted and checked by an OCaml harness. The
assertion is intrinsic to the example, human-readable, and doubles as
documentation. This lands **before** the scoped-fold hinge-closure check, which
then becomes two clean cases (`expect error` + a valid positive case).

## Non-goals (v1)

- No flap/layer space (`.p flap` → `(x, y, layer)`). Deferred to v2; the space
  qualifier syntax is built extensibly so `flap` is later just a third case.
- No irrational-coordinate literals (qqbar). Compare derived points against
  each other instead of against a literal.
- No full migration of `examples/`. v1 migrates **one** feature area (`fold`)
  as proof; the rest and the `test_e2e.ml` retirement are a follow-up slice.
- No `beloch test` CLI subcommand yet (OCaml harness only; CLI later).

## Format

A test `.bel` = a normal program followed by a trailing block of assertion
comments. Assertions are ordinary `;` comments, so the lexer already ignores
them — the runner extracts them from the **raw file text**, independent of
parsing.

Extraction: a line matches `^\s*;\s*(assert|expect)\b`. Convention (not
enforced): a trailing block after a blank line, reading as a spec footer.

```
paper square
fold map .d onto .a

; assert .d = .a
; assert .d paper = (0, 1)
; assert faces = 2
```

A file is **either** value assertions **or** a single `expect error` (once the
program errors, nothing else can be checked). Mixing is a harness error.

## Assertion grammar (v1)

```
assert    := "assert" value "=" value
           | "assert" point ["not"] "incident" (line | point)
           | "assert" line "is" assignment
           | "assert" count "=" int
expect    := "expect" "error" STRING          ; substring match on the message

value     := point | line | literal
point     := "." NAME [space]                 ; space defaults to "table"
line      := "--" NAME
space     := "table" | "paper"                ; "flap" reserved → error "not yet supported"
literal   := "(" rat "," rat ")"              ; rat = INT | INT "/" INT
count     := "faces" | "steps"
assignment:= "mountain" | "valley" | "boundary"
```

Semantics:

- **`point = point`** — exact coincidence of the two points in their space
  (default `table`). `.a paper = .b paper` compares paper coords.
- **`point = literal`** — the point's coord (in its space) equals the rational
  literal.
- **`line = line`** — same line (normalised coeffs, exact).
- **`point incident line`** — the point's **paper** coord satisfies the line's
  paper equation `a·x + b·y = c` exactly. `not incident` negates. (Incidence is
  a construction relation → always paper space; both operands paper.)
- **`point incident point`** — coincidence; an alias of `=` for point↔point.
  `=` is the canonical point↔point form; `incident` is primarily point↔line.
- **`line is <assignment>`** — the named crease's edge assignment. Requires
  `--name` to resolve to a **material** crease; otherwise harness error
  ("`--x` is not a material crease").
- **`faces = N`** — face count of the final `foldedForm` frame.
- **`steps = N`** — number of `foldedForm` frames.
- **`expect error "substr"`** — evaluation must raise `Error.Beloch_error`
  whose message contains `substr` (substring, matching `test_e2e.ml`'s style).

Equality/incidence use exact arithmetic (`Num` compare / `Geom.point_equal` /
exact line satisfaction) — Beloch is exact, so no tolerances.

## Runner — `tests/test_bel_assert.ml`

Alcotest suite, one test case per `.bel` under `tests/cases/**` (walked
recursively, mirroring `test_golden.ml`'s `examples/` walk and its
`DUNE_SOURCEROOT` anchoring for in-repo worktrees).

Per file:
1. Read raw text; extract assertion lines (`^\s*;\s*(assert|expect)\b`).
2. Tokenise each assertion with a small hand-rolled tokenizer (no Menhir — the
   grammar is line-oriented and tiny).
3. Evaluate the program (whole file; comments ignored by the lexer).
4. If the file has `expect error`: assert eval raised with the substring;
   forbid any other assertion in the file.
5. Else: eval must succeed; resolve and check each assertion against the eval
   result — named points (paper + table coords), named lines (coeffs), the
   final folded frame (faces), the frame list (steps), and crease assignments.

Operand resolution draws on the evaluator's own state:
`Eval.t.named_points : (string * Geom.point) list` is **paper**-space
(construction landmarks, single coord each); `named_lines` likewise. The
`Fold_state.t` carries the faces/edges/layer order and the folded frames.

**Table projection.** A named point's `table` coord is not stored — it is
computed exactly the way `fold_emit.folded_frame_of_state` does: find the
face(s) whose paper polygon contains the point and apply that face's isometry
(`Isometry.apply_point f.iso p`). v1 semantics:
- point in exactly one face → that table image.
- point on the fold axis / shared crease → all containing faces agree → that
  image.
- point genuinely under multiple layers with disagreeing images → harness
  error: `"ambiguous table position (point lies in N layers); flap space is v2"`.
This keeps v1 single-valued and honest; the multi-layer case is exactly what
flap space (deferred) will address.

The implementation plan confirms whether corner names `a`–`d` are reachable
through `named_points` or must come from `beloch:vertices_names`, and factors
the projection helper so the runner and `fold_emit` share it rather than
duplicating the containing-face logic.

`dune`: add `test_bel_assert` to the tests stanza with a `(source_tree cases)`
dep so the cases ship into the sandbox.

## File organisation — hard split

- `tests/cases/<feature>/*.bel` — behaviour tests with inline assertions.
- `examples/` — only what the docs site renders (golden-snapshotted by
  `test_golden.ml` as before).
- A behaviour test lives in exactly one place: `tests/cases/`. When an example
  is migrated there, it leaves `examples/` (so `test_golden.ml` no longer
  covers it — the assertion case covers it better and more legibly).

## Migration scope (v1)

- Create `tests/cases/fold/` and migrate the **valid** fold behaviour examples
  into it with inline assertions (a handful: a basic full-layer fold, a valid
  scoped fold, a multi-fold). **Do not** migrate the tearing `up to` examples
  yet — their correct assertion is `expect error`, which needs the
  hinge-closure check that lands in a later slice.
- Leave `test_e2e.ml` and the rest of `examples/` untouched in v1.
- Add at least one case exercising each assertion form (=, incident, not
  incident, is-mountain, faces, steps, expect-error) so the harness itself is
  proven.

## Sequencing

1. **This slice:** format + `test_bel_assert.ml` runner + `tests/cases/fold/`
   proof migration.
2. **Migration slice:** move remaining behaviour examples into `tests/cases/`,
   retire the overlapping `test_e2e.ml` cases.
3. **Hinge-closure slice:** the scoped-fold check, expressed as
   `tests/cases/fold/up-to-tear.bel` (`; expect error "hinge"`) plus a valid
   `up-to-parallel.bel` with positive assertions.
