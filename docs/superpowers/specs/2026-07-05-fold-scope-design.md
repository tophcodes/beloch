# Fold scope: `moving`, `up to`, `@fold` — design

Date: 2026-07-05. Companion ADR: `decisions/0016-typed-operands-bundle-values-singleton-slots.md`.
Fold-model background: [demaine2007, §14] (one-layer / all-layers / some-layers
simple folds; some-layers is strictly more powerful and "most natural").

## Problem

`moving` conflates two things and does neither precisely:

- It is documented as "the flap containing material point `.p`" (spec §4.6) but
  implemented as a table-space **side** pick (`eval.ml` keeps only
  `side_of_line`), discarding the material identity of the point.
- Once the paper is stacked there is no way to say *how much* moves: every fold
  is an all-layers simple fold ("fold through all layers is automatic").
  One-flap and some-layers folds — petal folds, "fold the top two flaps" — are
  inexpressible.
- Folding along an existing crease requires re-stating the axiom
  (`examples/precrease-fold.bel`), which re-derives a line instead of
  referencing material, and breaks down once the crease is a scattered bundle
  (ADR 0014).

## Model

Every fold has four ingredients:

| Ingredient | What | Source |
| --- | --- | --- |
| axis | the fold line | axiom, or material crease via `@fold` |
| anchor | flap that starts the moving set | implied (map folds) or `moving` |
| scope | which flaps move | default all-layers on the anchor's side, or `up to` |
| direction | valley/mountain | `mountain` keyword, default valley |

### Anchor — implied or required, never both

- **Map folds** (`@map .a onto .c`): anchor implied = the flap carrying the
  moved point `.a`. `moving <flap>` overrides (e.g. `moving .c` folds the other
  side). A redundant explicit `moving .a` is a lint case (#64).
- **Line-construction folds** (`@through`, `@perp`, `@map --l onto --m`) and
  `@fold`: no natural anchor → `moving` **required** (today's error stays).

### Scope

- **No `up to`**: all layers on the anchor's side move — the status-quo
  all-layers simple fold. Existing examples keep their meaning.
- **`up to <flap>`**: the contiguous range of flaps from the anchor flap
  through the target flap **inclusive**, in the stack order over the crease
  region. Both ends are named, so no top/bottom or grab-direction convention is
  needed.
- **Exactly one flap**: `up to` the anchor itself — `@map .a onto .c up to .a`.

### Operand type: flap

`moving` and `up to` are both flap-typed (ADR 0016):

```
fold_spec    := ["moving" flap_operand] ["up" "to" flap_operand] ["mountain"]
flap_operand := point            ; sugar: the flap carrying the point
              | line             ; sugar: #(--d) — resolves iff unique
              | "#(" ... ")"     ; explicit incidence constraints (PR2 operand)
```

Resolution follows the ADR: incidence constraints, uniqueness required, error
names the candidates. `moving --d` therefore usually multi-matches (a hinge has
two sides); `up to --d` resolves, because the anchor fixes the walk direction —
walking from the anchor flap through the stack, the first flap hinged on a
segment of `--d` ends the range (inclusive); never reached → error.

### `@fold` — fold along existing material

```
@fold <crease-operand> [moving <flap>] [up to <flap>] [mountain]
```

Folds along an existing crease (a bundle). Material resolution per flap as in
PR2 (#28): a bent crease under the moving set is an error. `moving` is always
required (a material crease implies no side). Replaces axiom re-statement after
a precrease.

### Crease all layers, fold some

Pure composition — this was the motivating question:

```
--d = map .b onto .a          ; bare bind: subdivide creases ALL layers
@fold --d moving .b up to .c  ; fold only flaps .b through .c along it
```

Non-moving layers keep their flat crease mark; moving ones fold. Matches paper.

## Errors

- Missing anchor where required → existing "this fold needs `moving`" error.
- Flap operand resolution: 0-match / multi-match with candidates (ADR 0016).
- `up to` target not on the anchor's side, or not reachable in the stack walk
  over the crease region → error.
- Anchor flap's material lies on the axis → existing error.
- Physically unfoldable scope (collision) → existing taco checks (#47).
- `@fold` across a bent crease → existing PR2 error.

## Out of scope / deferred

- Non-contiguous flap sets (matches "subset deferred" in
  `notes/2026-07-03-crease-layer-selection.md`).
- Keyword bikeshed: `up to` is the working choice; `to`/`taking` are
  alternatives. `through` is taken (axiom keyword).
- Renaming `@map` to `@fold` for axiom folds — `@fold` here is reserved for
  material-crease references.

## Testing

- Unit: each error class above.
- Examples (load-bearing per example discipline): a top-flap-only fold on a
  stack (result differs from all-layers), precrease → `@fold`, an `up to`
  range fold, crease-all-fold-some.
- Existing stack examples must evaluate unchanged (default stays all-layers).

## Implementation sketch

1. AST/parser: `fold_spec` gains `up_to`; `moving` becomes `flap_operand`;
   new `@fold` statement.
2. Evaluator: flap resolution (incidence over faces), stack-walk range
   selection, scope-restricted reflection + restack (today's fold reflects the
   whole side; the moving set becomes an explicit face set).
3. `@fold`: bundle → per-flap line resolution (exists since PR2), then (2).
4. Spec §4.6 rewrite + ADR cross-links; lint (#64) and LSP lifetime hints
   (#65) follow separately.
