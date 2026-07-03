# 2026-07-03 — creating creases: bind (whole bundle) vs `pinch` (one segment)

Companion to `2026-07-03-crease-segment-at-operator.md`. That note covers
*referencing* a segment (`at`, a bundle → length-1 bundle projection). This one is
the **creation-time** side: when a crease is laid across a stack, how much of it
materialises. **Open design — insight + a proposed primitive, not fully
converged.**

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

## Open questions

- **Does `pinch` fold, or only mark?** Intuition: `pinch` is mark-only
  (subdivide one face, no fold); actual folding stays with `@`. Confirm `pinch` is
  never combined with `@`, or define what `@pinch` would mean.
- **Interaction with `@` / `moving` / `mountain` (§4.6).** A flap *is* a layer, and
  `moving .p` already picks a flap; make sure `pinch`'s layer selection and the
  fold model's side selection don't become two ways to say one thing.
- **Absent layers.** A line need not cross every layer; bind over a stack simply
  cuts the faces it meets. Fine for bind; for `pinch`, an `at` selector that hits
  no segment is already the companion note's 0-match error.

## Not deciding yet

Left open: whether `pinch` is strictly mark-only, the `@`/`moving` reconciliation,
and the exact `pinch` statement grammar. Next step is a focused pass on the
mark-vs-fold boundary once the `at` reference side is settled.
