# Dead ends & antipatterns

Approaches tried and rejected, with *why*. The most valuable and most neglected
research artifact: when you're stuck in eight months thinking "what if we just…",
check here first. Raw material for the paper's design-discussion section. Append
ruthlessly — a dead end recorded is a dead end you don't walk twice.

(For forward-looking decisions, see `decisions/`. This file is for what *didn't*
work, including things inherited as warnings from the 2018 attempt.)

## Inherited from the 2018 design (OrigamiDL)

- **Layer number = fold depth + 1 (the bookmark heuristic).** Won't hold up.
  Real origami layer order is a *partial order* on faces determined by the folded
  state, not a tree. This is what FOLD's `faceOrders` uses and what the flat-
  foldability literature uses. Tagging vertices with a layer number also breaks
  for fold-line vertices that sit on neither layer. → A proper folded-state model
  with face ordering is required; see the open layer problem.
- **Region ≠ layer (conflation).** A *region* is an area of paper addressed by a
  predicate; a *layer* is a z-ordering of overlapping areas. The 2018 spec used
  `#region` to do both. We likely need both concepts, kept distinct.
- **Accumulate features until expressive, then formalize.** This is how the 2018
  design hit mutual inconsistency at the layer problem and stalled. Replaced by
  the minimal-formal-core approach — see decisions/0003-restart-from-minimal-core.md.
- **"There is a unique fold" (from the axiom phrasing).** False in general:
  axiom 5 has up to 2 solutions, axiom 6 up to 3. Disambiguation must be
  first-class and ergonomic, not an afterthought.

## Watch-points & traps

- **Hull's BOO numbering ≠ classic Huzita-Justin numbering.** Hull [hull2020,
  §1.5] inserts "locate the intersection of two lines" as his O2, so his O3 is
  the classic axiom 2 (point-onto-point). Beloch uses the *classic* numbering.
  Do not cite "Hull O2" for Beloch's axiom 2 — that would be wrong (Hull's O2 is
  line intersection, which Beloch exposes as the `cross` construction). Caught
  during the v0.0 spec write by checking `refs/hull2020.txt` instead of trusting
  memory.
- **ℚ stops being closed at axioms 5/6.** Exact rational arithmetic
  ([ADR 0008](decisions/0008-exact-rational-arithmetic.md)) covers axioms 1–2
  and line intersection perfectly, but square roots (axiom 5) and cubic roots
  (axiom 6) leave ℚ. Don't assume the rational engine extends to the full axiom
  set — that boundary needs a constructible/algebraic number representation,
  decided when those axioms land.

## Build/toolchain gotchas (v0.0 implementation)

- **Dune wrapped-library facade needs explicit re-exports.** The library is
  named `beloch` and there is a `lib/beloch.ml`, so dune treats it as the main
  module and does NOT auto-expose sibling modules to external code (tests, the
  CLI). Each new `lib/<mod>.ml` must be re-exported via `module Mod = Mod` in
  `lib/beloch.ml`, and external code reaches it as `Beloch.Mod` (tests `open
  Beloch`). Inside the library, siblings see each other by bare name as usual.
- **`fold_emit` must not reference `Beloch.version`.** `lib/beloch.ml` re-exports
  `Fold_emit`, so `fold_emit.ml` referencing the `Beloch` facade is a module
  cycle. The `file_creator` string is a literal `"beloch 0.0.0-dev"` kept in
  sync with `Beloch.version` by hand. Same trap applies to any sibling that
  wants the version.

## Known v0.0 limitations (follow-ups, from the whole-branch review)

- ~~**No edge-level dedup in `planarize`.**~~ RESOLVED in v0.1 (Task 2): planarize
  now dedups edges by sorted `(min v0 v1, max v0 v1)` and planarizes the boundary
  uniformly, producing a simple graph.
- **Corner set / boundary winding duplicated** between `Eval.corners` and
  `Planarize`. Fine for the single square shape; consolidate into one paper
  abstraction when a second shape lands.
- **e2e test fixture path** (`../../../examples/`) is a brittle sandbox-relative
  climb; harden with a dune `deps` stanza if the layout ever shifts.
- **`Faces.index_in` returns -1 silently** (v0.1). If a neighbour is ever absent
  from a vertex ring (can't happen with the current symmetric, clipped graph),
  `next` walks a wrong half-edge instead of failing. Add `assert (i >= 0)` before
  axiom 3 introduces richer interior geometry. (Whole-branch review recommendation.)
- **Face tests assert count only** (v0.1). No test pins explicit CCW vertex
  indices/winding for a known region. Add one when axiom 3 lands, as a guard
  against a `next`-direction regression.

## Rejected approaches (this attempt)

_(none yet — append as they happen)_
