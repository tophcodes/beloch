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
  with face ordering is required; see the open layer problem. Fisher reached the
  same conclusion in 1994: "cyclic layering relationships can occur in
  origami ... so it would not be possible to simply give each face some kind
  of layer number" [fisher1994, §6.1].
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
- **Ida's Eos/Orikoto numbering ≠ classic Huzita-Justin numbering either.**
  Ida [ida2020, Table B.1] uses the Huzita-Hatori order: his O6 is the
  simultaneous two-point fold (Beloch axiom 7) and his O7 is Hatori's fold
  (Beloch axiom 4). Translate before comparing any Eos construction with a
  `.bel` program.
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

## Axiom 3 is the perpendicular-through-a-point, not the angle bisector

An early journal note (`notes/2026-06-28-3.md`) labelled "axiom 3" as the
angle bisector (line onto line). That is wrong. The authoritative classic table
is [justin1986] §8.1: operation ③ `(P → P, D → D)` is "Perpendiculaire menée de
P à D" — the fold through a point perpendicular to a line (Hull's O5). The angle
bisector is operation ⑤ `(D → D')` (Hull's O4), and it is the first axiom whose
result leaves ℚ (square roots). Don't re-conflate them: axiom 3 = perpendicular
through a point (rational, landed v0.2); axiom 5 = angle bisector (irrational).

## The fused `step` construct (2026-07-02, first step/macro spec)

The first approved step/macro spec made one `step` construct carry scoping
*and* diagram grouping, and gave `$name` three meanings at once: display
label (evaluated immediately, scope discarded), stored macro (deferred),
retained namespace (needed by post-hoc `export`). Consequences, per the
review in #29: post-hoc `export { --pq } $thirds` either failed or re-ran
the body — physically double-folding the paper; a parameter list silently
switched the evaluation model; the spec's own flagship example was
undefined under its own scope rule; several examples didn't parse.
Nine commits on `worktree-feat+step-macros` implement this design.

Fix (revised spec, same date): one construct per meaning — `def` (never
runs) / `apply` (only execution form, yields retained instance) / `export`
(reads, never runs) / `step` (panel marker, display only) — and one sigil
per meaning: bare identifiers for defs, `$` only for instances. Don't
re-fuse the axes: display grouping and scoping always come apart under
pressure ("group without hiding" and "hide without grouping" both exist).

## Table-space point values / topmost-layer cross resolution (Q2-B, v0.7-dev → killed v0.19-dev)

`cross` used to intersect the operands' current table lines and resolve the
table point to the material point on the *topmost layer covering that spot* —
"the one your hand would touch". Wrong twice over. Physically: paper is opaque;
the topmost face can carry **neither** crease, so no layer actually shows the
crossing your hand touches (`fold-top-two.bel`'s bottom-edge cross resolved to
a point on the *top* edge of the sheet). Semantically: it made a point
*construction* depend on the fold state, while creases are permanent scars
whose paper-space crossing never moves. The bundle case was also ill-posed:
segments scored through several layers are coincident on the table only at
birth, so "the" table line of a crease stops existing after the next fold.

Fix: crossings are computed in paper space, on the material marks (§4.3,
v0.19-dev); table space survives only as transient geometry inside axiom
evaluation, never as a value. Rule of thumb since: **if a construct's result
can name a layer, something is wrong — layers are for folding, values are
material.**
