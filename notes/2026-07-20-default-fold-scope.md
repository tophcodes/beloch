# Default fold scope: prefix-to-anchor, not through-all (design, 2026-07-20)

Prompted by a `paper square` model whose final `fold map .b onto .o` flipped the
entire sheet instead of folding one ear. Root cause was not the target point
(`.o = --ea * --eb` correctly resolves to the incenter of triangle a–b–c); it was
the **default fold scope**. Today `fold` with no `up to` moves *every layer on the
anchor's side of the axis* — an all-layers simple fold — so the ear fold swept up
roughly half the model. Scoping it down hit a catch-22 (below). This note changes
the default.

## The catch-22 we are removing

For the ear, `.b` is the tip and it lands on the b–o crease shared by the ear's
two layers (folded faces f1 = {centre, b, o}, f2 = {b, (0.586,0.586), o}). So:

- `fold map .b onto .o up to .b` → `.b lies on a crease shared by 2 flaps; name
  the flap with #[...]` (the error text mis-says `#(...)`).
- `fold map .b onto .o moving #[.b .n]` (with `.n = --ea * --bc` picking f2) →
  resolves the flap, then `#[...] straddles the fold axis; anchor with a point
  instead` — the ear spans x=0.5.
- The spec's own out (`a point anchor disambiguates the side by itself`) loops
  back to `.b`, which is the shared-crease vertex. No named point sits interior
  to the moving portion of the ear.

The tip you would physically grab is exactly the point the current model cannot
anchor on.

## The change

**Default scope (no `up to`).** The moving set is the **outside-contiguous
prefix** of the layer order over the crease region — top for valley, bottom for
mountain (unchanged invariant; [demaine2007, §14.1]) — down to **and including**
the flap(s) that carry the anchor operand. It is no longer "all layers on the
anchor's side".

- Anchor operand = the `moving` operand when present, or the **implied source
  point** on a map fold (`fold map .b onto .o` → `.b`).
- `moving` now names the **deepest** flap of the (outside-anchored) moving prefix,
  not a free "start-of-set anchor". The prefix always runs from the outside; the
  operand fixes how deep it reaches.

**Shared-crease anchor — option (a).** When the anchor point lies on N contiguous
flaps (a shared crease), **all** of them are included, down to the deepest. The
default-scope path no longer raises `lies on a crease shared by 2 flaps`; it takes
the whole contiguous run. This is what "fold b's ear" means. (Option (b) —
topmost single layer only — is dropped: folding one layer of a two-layer flap is
generally not a valid simple fold without a petal/other move first.)

**Straddle dissolves.** The default path already clips each face to `move_side`
(`Geom.clip_convex_halfplane`, eval.ml:1093) and needs no side-committed `#[...]`
anchor, so a straddling ear flap is no longer an error. `fold (map .b onto .o)`
(moving implied from `.b`) folds the ear.

## First folds are unchanged

A first fold on flat paper has one flap (the sheet). The prefix down to the
anchor's flap is that single flap, clipped to `move_side` — the same half-sheet as
before. The new default only differs once a multi-layer stack exists and the old
default reached *past* the anchor flap into deeper layers.

## Folding deeper (interim "fold more")

Explicit `up to <flap>` is **unchanged** and is the interim way to fold past the
anchor flap into deeper layers — the eventual dedicated "fold more" surface is out
of scope here. Existing multi-layer folds that relied on the all-layers default
and genuinely need the deeper layers get an explicit `up to <deepest-flap>` added;
their goldens regenerate. Folds on flat/single-layer regions need no change.

## Scope of the implementation slice

In:
- Rewrite the `up_to = None` branch (eval.ml:1085–1096): compute the
  outside-contiguous prefix down to the anchor flap(s) instead of all faces with a
  `move_side` piece. Reuse the anchor-resolution used by `up to`, relaxed so a
  shared-crease point yields the contiguous run rather than an ambiguity error.
- Fix the error text `#(...)` → `#[...]`.
- Update spec §fold prose (SPECIFICATION.md ~575–655): the default is the
  prefix-to-anchor, `moving` names the deepest flap, all-layers is no longer the
  default. Version note under v0.19-dev / next `-dev`.
- Regenerate affected goldens; add a `tests/cases/fold/` case for the ear
  (shared-crease anchor, straddling flap, default scope) and one asserting a
  multi-layer default now stops at the anchor flap.

Out:
- Dedicated "fold more" / "through all" keyword.
- Option (b) single-layer scoping.
- Any change to explicit `up to` semantics.

## Open implementation questions (for the plan, not the design)

- Exact prefix walk when the anchor flap(s) are not the outermost run — does a
  stationary flap covering the anchor in the crease region still raise the buried
  -anchor error, or does the prefix simply include the covering layers? (Spec
  §fold buried-anchor rule suggests: include them or it's an error; keep that.)
- `moving --line` anchor under the new default: the line names a flap; if it
  straddles, clip to `move_side` like the point path, or keep the current
  straddle rejection for lines? Decide in the plan.
