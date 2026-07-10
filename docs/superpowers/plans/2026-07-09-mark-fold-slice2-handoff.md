# mark / fold — Slice 2 handoff (partial marks / the pinch & ray-fix)

Written 2026-07-09, right after Slice 1 shipped to `main`. This is a **handoff,
not a plan** — Slice 2 still has open design questions to settle (brainstorm →
writing-plans) before it can be executed.

## Where things stand (Slice 1, shipped)

Slice 1 (`main` @ `498c0b1`+, local, unpushed) did the **surface + `U`→`F`**
cutover, behavior-preserving:

- Motions `map`/`through`/`perp` are pure line **values**; `--l = map .a onto .b`
  binds a `Frozen` line and subdivides **nothing** (new AST `BindLine`).
- `mark <motion>` / `mark --d = <motion>` = flat crease. **In Slice 1 `mark`
  still SUBDIVIDES** exactly like the old precrease — it just emits `F` instead
  of `U`. It is *not yet* a non-subdividing record.
- `fold <motion|--crease> [moving/up to/mountain]` merges the old `@map … moving`
  and `@fold` paths (`resolve_markable` → `` `Fresh `` / `` `Existing `` in
  `lib/eval.ml`). `collapse` = old `@collapse`, `@` retired everywhere (now a
  lexer error).
- `promote_crease` re-points a prior-`Frozen` name to its fresh `Material` crease
  when you `mark --d` a value line (guarded to `Frozen` only).
- FOLD emits only `B/M/V/F`; the `U` constructor is gone (`assign = M|V|F`).

**Full design:** `docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`
(read §4 surface, §5 marks-as-records, §8 deferred, §10 open questions). Memory:
`[[beloch-mark-fold-notation-design]]`.

## What Slice 2 is

**The actual pinch / reference-crease feature** — the part that makes a crease
*not* re-segment everything it crosses. This is what the whole redesign was
*for*; Slice 1 was the enabling surface.

Deliverables (design §4 extent, §5, §8):

1. **Non-subdividing partial marks.** A `mark` with a partial extent creates a
   record in a new `marks : mark array` on `Fold_state.t`
   (`{ seg-or-point, intent M|V, cp_dir, crease_id, layer }`) that is **not** a
   face-boundary edge — so it splits no rays, is no flap boundary, and **can end
   mid-face**. Full-chord `mark` may stay subdividing (as Slice 1) or also become
   a record — that's an open question (below).
2. **Extent syntax:** `mark --l between .a .b` (segment) and `mark --l at .p`
   (single reference point). `at` returns as an extent locator on `mark` only
   (not the old bundle selector).
3. **Snapping (marks-only):** a mark endpoint that lands close to an existing
   edge/vertex after a later crease is made incident to it — the sole deliberate
   inexactness, quarantined to marks, points stay rational.
4. **Direction on `mark` + CP-frame intent:** `mark … valley/mountain` records an
   M/V *intent* that populates the **creasePattern** FOLD frame while the
   **foldedForm** frame stays `F`. (Deriving intent from *fold history* is a
   further follow-up, not Slice 2.)
5. **Layer selection:** `#[…]` chooses which layer(s) a mark materialises on
   (logical, not physical-ε — you may mark the bottom layer though the reference
   line is drawn on top). Singleton by default; set-valued is deferred.
6. **Terse motion sugar** (optional, low priority): `mark .a onto .b` /
   `fold .a onto .b` dropping the `map` keyword.

## Why it matters (the payoff / verification target)

Slice 1 did **not** fix the motivating defects — it migrated the offending
scaffolds as `mark --x = through …`, which still subdivides and splits rays.
Slice 2's partial marks are the fix. Concrete acceptance targets:

- `examples/iteration/003` and `004`: currently **error** (`no common interior
  vertex`) because scoring the corner→apex reference creases as full `through`
  creases splits the bisector rays. Rewriting those landmarks as **partial
  marks** (that don't cross/segment the bisectors) should make `@collapse` select
  the right segments again → these examples work.
- `examples/syntax/cube-root.bel`: keeps its Messer-exact landing but its CP
  carries interim full-chord scaffolding creases; partial marks should clean the
  CP (landmarks become short reference marks).
- See `[[beloch-sightline-to-pinch-interim]]` for the interim-`through` list to
  rewrite to partial marks.

## Open design questions to settle BEFORE planning (design §10)

Brainstorm these with Toph first — a no-placeholder plan can't be written until
they're decided:

1. **Does a *full* `mark` subdivide or also become a record?** Slice 1 keeps
   full `mark` subdividing. If partial marks are records but full marks
   subdivide, the two behave differently at the boundary — decide whether that's
   acceptable or full marks also move to the record model. (Note: a `fold` along
   a mark, and `@collapse` folding along one, must subdivide *at fold time* if the
   mark itself didn't — check the `fold`/`collapse` eval paths.)
2. **Snapping tolerance & trigger timing** — what counts as "close enough", and
   at which point in evaluation does snapping fire (only after a later crease, or
   eagerly)? Must stay exact-rational (a snap is an incidence decision, not a
   coordinate perturbation).
3. **`at .p` single-point extent** — material is the exact point; the short tick
   is display-only. Nail the `fold2svg`/render tick, and what the FOLD edge for a
   point-mark looks like (zero-length? a tick segment?).
4. **Marks emit default** — emitted as raw `edges_vertices` `F` edges (visible in
   CP) or omitted for scaffold-only marks? Design leans "emit, with display able
   to hide scaffold marks."
5. **Set-valued layer selection** (`#[.c .d]` marking several layers) — reopens
   the deferred segment-set value (ADR 0016). Keep singleton for Slice 2 unless a
   real need appears.

## Implementation anchors (from Slice 1)

- New `marks` structure lives on `Fold_state.t` **beside** `edges`; it must NOT
  participate in `subdivide`, the coplanar-cluster/flap graph
  (`fold_state.ml` ~:382, ADR 0017), ray-splitting, or `Layer_order`. It rides
  isometries with its layer (like material) and is read by `fold_emit`.
- `fold_emit` already emits dual frames (creasePattern + foldedForm) — CP-intent
  for marks slots into the creasePattern frame; foldedForm marks are `F`.
- `#26` invariant (every *edge* borders faces or the paper edge) stays intact
  precisely because marks are not edges.
- The `mark`/`fold` eval arms and `resolve_markable` are the extension points for
  extent + layer clauses. `BindLine`/`Frozen` + `promote_crease` already model
  "value line → materialise later".

## Recommended next step

`brainstorming` on the five open questions above → `writing-plans` → subagent-
driven execution (Slice 1's ledger `.superpowers/sdd/progress.md` shows the
cadence). Start slice on a fresh branch from `main`.
