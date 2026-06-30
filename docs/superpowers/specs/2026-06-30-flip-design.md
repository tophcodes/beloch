# Beloch — `flip` (turn the sheet over) Design

- **Date:** 2026-06-30
- **Status:** Design — approved in brainstorming, pending implementation plan
- **Context:** the action-model folding engine (`@` folds, dual FOLD output) shipped in PRs #7–#13; this adds the first whole-sheet isometry. `rotate` was considered and dropped (with material/named point references, a whole-sheet rotation only reorients the output — it changes no fold; cosmetic). `flip` is substantive: it is how a mountain fold is physically made (flip + valley) and how mountain/valley stays correct across a turn-over.

## 1. Scope

Add a single statement, `flip over --l`, that turns the whole folded sheet over across the line bound to crease `--l`.

**In:**
- `flip over --l` — reflect every face across the line `--l`, flip each face's orientation, and reverse the layer stack.
- Correct mountain/valley for folds made after a flip (flip + valley = mountain), via the existing parity rule.

**Out (deferred):**
- Inline anonymous line axes `--(.a .b)` — a separate next slice (a general line-operand feature, not flip-specific).
- Default / directional flip axes (`flip`, `flip vertical`) — with named points the axis is cosmetic; skipped.
- Partial flips (turning over only some layers); non-flat geometry.

## 2. Semantics

`flip over --l` looks up the table-space line bound to `--l` (a named crease, exactly like other line operands; **error** if undefined) and turns the sheet over across it:

1. **Reflect every face** across `--l`: compose `Isometry.reflect_across_line l` into each face's isometry. A reflection has determinant −1, so **every face's `det_sign` flips** (front ↔ back).
2. **Reverse the layer order**: turning a stack over swaps top and bottom, so the face array (which is bottom→top) is reversed.

Consequences:

- **Proper mountain/valley.** A crease's assignment is `valley XOR (det_sign(cutting face) < 0)`, recorded when the fold runs (unchanged by this slice). Because `flip` flips every `det_sign`, a *subsequent* valley fold is recorded as a **mountain** relative to the original front face — i.e. "mountain = turn over, then valley." Creases made *before* the flip keep their assignment (they are material facts). The `mountain` keyword stays as a direct shortcut alongside `flip`.
- **Layer access.** The previously bottom layer is now on top, so the next fold can act on what was the underside — something a front-only model cannot reach.
- **Output.** `flip` alone leaves the `creasePattern` frame **unchanged** (it is in paper coordinates; `flip` only changes the per-face isometries / table placement). The `foldedForm` frame is mirrored across `--l` with its layer order reversed, and `faceOrders` is re-derived from the new order at emit time. M/V of *later* folds differs as above.

## 3. Components

- **`Fold_state.flip : t -> Geom.line -> t`** (new): reflect all faces across the line, reverse the face array, renormalise `layers`. Crease records (accumulated `M`/`V`/`U`) are untouched.
- **AST** (`lib/ast.ml`): new statement `Flip of crease_ref * Error.span`.
- **Lexer** (`lib/lexer.ml`): keywords `flip`, `over`.
- **Parser** (`lib/parser.mly`): `stmt | FLIP OVER crease_ref { Flip ($3, $loc) }`.
- **Eval** (`lib/eval.ml`): on `Flip`, `lookup_crease --l` → `state := Fold_state.flip !state line`. No crease records produced (flip makes no crease).

## 4. Errors

- `flip over --l` with `--l` undefined → `undefined crease --l` (the existing `lookup_crease` error).

## 5. Testing

- `Fold_state.flip`: on a one-fold state, flipping over a line flips `det_sign` of every face and reverses the layer array (top↔bottom).
- Proper M/V end-to-end: a program that precreases a center line, `flip over` it, then `@map … onto … moving …` (a valley by command) emits that crease as **`M`** (mountain) — because the flip inverted the parity.
- `flip` alone leaves the `creasePattern` frame byte-identical to the same program without the flip (paper coords unchanged); the `foldedForm` differs (mirrored + reversed).
- Error: `flip over --nope` raises the undefined-crease error.
- Regression: all existing programs (no `flip`) unchanged.

## 6. Follow-ups

Inline anonymous line operands `--(.a .b)` (next slice — makes `flip over --(.b .c)`, `cross --(...) --(...)`, etc. work without throwaway named creases); default/directional flip axes only if a real need appears; partial/per-layer flips with the maneuvers slice.
