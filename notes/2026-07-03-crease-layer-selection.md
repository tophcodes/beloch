# 2026-07-03 — creating creases: bind (whole bundle) vs `pinch` (one segment)

Companion to `2026-07-03-crease-segment-at-operator.md`. That note covers
*referencing* a segment (`at`, a bundle → length-1 bundle projection). This one is
the **creation-time** side: when a crease is laid across a stack, how much of it
materialises. **Converged 2026-07-04** — the mark-vs-fold pass below closed the
last open questions; `pinch` is now spec-ready (see *Resolved* at the end).

## No `crease` keyword

There is none. The `CREASE` token *is* the `--name` name (`lexer.ml:47`,
`--foo → CREASE "foo"`). Creases are created by **axiom statements**, optionally
bound: `--d = through .a .b`, or anonymous; a leading `@` makes it fold (§4.6),
its absence leaves the paper flat. (An earlier sketch here invented
`crease … top/all/bottom` — fiction, removed.)

## Bind already means "all layers"

A bare bind (no `@`) runs `subdivide`, which cuts **every face the axis crosses**
(`eval.ml:347-349`; `fold_state.subdivide` seeds one edge per face actually cut).
So `--d = through .a .b` on a stack already creases **every layer** under the
line — the whole bundle. "Fold-through / all layers" is therefore the **existing
default**, not a missing feature. No `all` keyword needed.

## The gap: one segment → `pinch`

The complement — materialise **just one** segment, not the whole bundle — has no
home today. That is the reference-crease / pinch-mark operation:

```
pinch (through .a .b) at .c    ; subdivide restricted to .c's segment only
```

`pinch <line> at <selector>` = `subdivide` narrowed to the single face carrying
the `at`-selected segment. On a flat single sheet the line meets one face, so
`at` is optional; on a stack it is required (pick which layer). Good keyword —
`pinch` is the origami term for a small localised reference crease.

**Material vs. display.** Materially a pinch is a normal length-1 crease — it cuts
the **full chord** of its face and subdivides it, exactly like `bind` (just one
segment), so it is a real, `at`-referenceable crease and the face topology stays
in the existing full-chord polygon model. The "shortness" is a **display**
property: the crease carries a `pinch` **flag** (plus its reference point `.p`) as
edge metadata — the same channel that already carries `name`/`axiom`/`sources`/
`span` on `beloch:edges` (see `2026-06-29-crease-names.md`). The renderer
(`tools/fold2svg.mjs`) reads the flag and draws a **short segment centred on
`.p`**, not a line spanning the whole CP. This keeps the CP legible and — since
pinch marks sit at distinct points — keeps them visually separable, which is
exactly what the click-to-disambiguate UX (see companion note's debugging section)
needs. No new geometry kind; material stays full-chord, only rendering diverges.

**`pinch` is the segment-granularity primitive**, and its value is broadest in the
"construct over 20 steps, unfold, keep folding" workflow: after a full unfold the
bundle is *scattered* (companion note — no global line), so you work segment by
segment. There you name single segments as they arise via `pinch` rather than
leaning on a whole-bundle line that is about to scatter. The two operators mesh:
`pinch` lays/names one segment, `at` references one.

## Single-valued, by design

`pinch` makes **exactly one** segment. Want several → several statements.
`at … and …` keeps its *one-segment* meaning (two constraints, one result), so it
is **not** a way to pick a set. This preserves the singleton-target rule from the
companion note: operations consume length-1 bundles only.

## The two ends already have homes

| Scope | Syntax | Status |
|---|---|---|
| whole bundle (all layers) | `--d = through .a .b` (bare bind) | exists |
| one segment | `pinch <line> at <sel>` | new — `pinch` |
| a **subset** (>1, not all) | — | **deferred** |

The subset case is the only one needing a segment-set *value* (the array datatype,
and the reopened sigil question). Deliberately deferred; revisit only if it proves
common. No `top`/`bottom`/`all` scope vocabulary — reality is binary (bind = all,
`pinch` = one) with subsets parked.

## Resolved (2026-07-04)

The focused mark-vs-fold pass closed every open question. Four decisions:

1. **Flat, never folds.** `pinch` is a creation-time mark: it `subdivide`s one
   face and leaves the paper flat. It does **not** reflect, does **not** leave a
   side standing up, and does **not** fall through to the layers beneath the
   selected one. `@pinch` is meaningless — a parse/semantic **error**. All folding
   stays with `@`; `pinch` only lays reference geometry.

2. **Layer chosen by `at`, not `moving`.** `pinch` reuses the companion note's
   `at` keyword to pick which face materialises — it does **not** borrow the fold
   model's `moving`. `moving` selects a side to *move*; `pinch` moves nothing, so
   `moving` would be meaningless here. One keyword (`at`), two incidence contexts:
   selecting a segment of an existing bundle (companion note) and selecting the
   face a fresh `pinch` line cuts. Selector kinds:
   - `at .c` — the face carrying material point `.c`. **All points are material**
     (there are no table-space points; `.a`–`.d` especially so), so a point
     selector always identifies a layer — the ADR's "table-space selector can't
     disambiguate" caveat simply does not arise at creation.
   - `at #(…)` — the flap's face.
   - Flat single sheet: the line meets one face → `at` optional. Stack → required.
     A selector that hits no face is the companion note's **0-match error**.

3. **Full-chord subdivide (model (a)), shortness is display-only.** `pinch` cuts
   the **full chord** of its face and splits it in two, exactly as the *Material
   vs. display* section above describes — no new geometry kind, the #26 invariant
   (every edge is a face boundary or the paper edge) stays intact. The two halves
   are coplanar and flat, so the extra face + `Layer_order` entry are semantically
   inert. Rejected: a non-splitting "reference edge" that isn't a face boundary —
   it would push a special-case edge type through the whole topology and emit path
   for no real gain.

4. **Grammar.** `pinch <line> [at <selector>]`, a statement, optionally bound to
   `--name`; the result is a length-1 bundle usable anywhere `at` output is. The
   `at` selector is unambiguous for simple lines (`through .a .b` takes exactly two
   points), so parens are optional there; **parenthesise the line once it carries
   its own axis selectors** — `pinch (perp --l through .p) at .c` — so `at` binds
   to the `pinch`, not the inner axiom.
