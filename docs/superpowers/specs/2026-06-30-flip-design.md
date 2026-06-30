# Beloch — `flip` (turn the sheet over) Design

- **Date:** 2026-06-30
- **Status:** Design — approved in brainstorming, pending implementation plan
- **Context:** the action-model folding engine (`@` folds, dual FOLD output) shipped in PRs #7–#13; this adds the first whole-sheet isometry. `rotate` was considered and dropped (with named/material point references, a whole-sheet rotation only reorients the output — it changes no fold; cosmetic). `flip` is substantive: it is how a mountain fold is physically made (flip + valley) and how mountain/valley stays correct across a turn-over.

## 1. Scope

Add a single bare statement, `flip`, that turns the whole folded sheet over.

**Key realisation (why bare, no axis operand):** turning a sheet over is a reflection, which needs *some* line — but *which* line only determines where the paper lands in internal table coordinates (a mirror of the position). The **substantive** effect — every face's orientation flips and the layer stack reverses — is **axis-independent**. With named/material point references the landing position is irrelevant to the user, so the axis is an internal detail, not a user parameter. (The flip *direction* will matter later, for the animation engine — *how* the sheet visibly turns — and can become an optional argument then.)

**In:**
- `flip` — turn the whole sheet over: flip every face's orientation, reverse the layer stack.
- Correct mountain/valley for folds made after a flip (flip + valley = mountain), via the existing parity rule.

**Out (deferred):**
- A user-facing flip axis / direction (`flip over --l`, `flip vertical`, …) — revisit with the animation engine, when *how* it turns becomes visible.
- Inline anonymous line operands `--(.a .b)` — a separate next slice (general line-operand sugar).
- Partial flips (turning over only some layers); non-flat geometry.

## 2. Semantics

`flip` turns the sheet over across a **canonical internal axis: the vertical centerline of the current footprint** (`x = (minX + maxX) / 2` over all faces' table coordinates) — an in-place left↔right turn-over that keeps coordinates roughly in place. The axis choice is internal and carries no user-visible meaning beyond a global mirror.

1. **Reflect every face** across that axis: compose `Isometry.reflect_across_line axis` into each face's isometry. A reflection has determinant −1, so **every face's `det_sign` flips** (front ↔ back).
2. **Reverse the layer order**: turning a stack over swaps top and bottom, so the face array (which is bottom→top) is reversed.

Consequences:

- **Proper mountain/valley.** A crease's assignment is `valley XOR (det_sign(cutting face) < 0)`, recorded when the fold runs (unchanged by this slice). Because `flip` flips every `det_sign`, a *subsequent* valley fold is recorded as a **mountain** relative to the original front — i.e. "mountain = turn over, then valley." Creases made *before* the flip keep their assignment (material facts). The `mountain` keyword stays as a direct shortcut alongside `flip`.
- **Layer access.** The previously bottom layer is now on top, so the next fold can act on what was the underside — something a front-only model cannot reach.
- **Output.** `flip` alone leaves the `creasePattern` frame **unchanged** (it is in paper coordinates; `flip` only changes the per-face isometries / table placement). The `foldedForm` frame is mirrored across the axis with its layer order reversed, and `faceOrders` is re-derived from the new order at emit time. M/V of *later* folds differs as above.

## 3. Components

- **`Fold_state.flip : t -> t`** (new): compute the footprint's vertical centerline, reflect all faces across it, reverse the face array, renormalise `layers`. Crease records (accumulated `M`/`V`/`U`) are untouched. Computing the centerline needs the exact min/max table-x over all face vertices (via `Num.compare`).
- **AST** (`lib/ast.ml`): new statement `Flip of Error.span`.
- **Lexer** (`lib/lexer.ml`): keyword `flip`.
- **Parser** (`lib/parser.mly`): `stmt | FLIP { Flip $loc }`.
- **Eval** (`lib/eval.ml`): on `Flip`, `state := Fold_state.flip !state`. No crease records produced (flip makes no crease); no lookup, no error.

## 4. Errors

None — `flip` is a bare statement with no operand.

## 5. Testing

- `Fold_state.flip`: on a one-fold state, `flip` flips `det_sign` of every face and reverses the layer array (top↔bottom); applying `flip` twice returns the original face orientations and order (involution up to the canonical axis).
- Proper M/V end-to-end: a program that folds, then `flip`, then `@map … onto … moving …` (a valley by command) emits that later crease as **`M`** (mountain) — because the flip inverted the parity.
- `flip` alone leaves the `creasePattern` frame byte-identical to the same program without the flip (paper coords unchanged); the `foldedForm` differs (mirrored + reversed).
- Regression: all existing programs (no `flip`) unchanged.

## 6. Follow-ups

A user-facing flip direction/axis (for the animation engine, once *how* the sheet turns is visible); inline anonymous line operands `--(.a .b)` (next slice); partial/per-layer flips with the maneuvers slice.
