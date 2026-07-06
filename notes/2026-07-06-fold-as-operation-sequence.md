# 2026-07-06 — why imperative fold sequences work at all

Loose realization, capturing before it evaporates. Two related but separable
claims; kept as one note since they're cause → effect of each other.

## Claim 1: the operation vocabulary is small

Origami — real, physical, folded-by-hand origami — reduces to a sequence of
operations drawn from a small, finite alphabet: the Huzita–Justin axioms (see
[[beloch-two-layer-design]] for the capability/sugar split over them), plus a
handful of structural modifiers (mountain/valley, fold-through-N-layers,
crease-only vs fold). That's it. Nobody folds paper via an operation outside
this set — the axioms are provably a complete basis for single-fold flat
origami moves.

This is *not* obvious a priori. Compare: sculpting clay, or free-hand paper
crumpling, has no comparable finite move-set — you'd need continuous
deformation fields to describe it. Origami is unusually, almost suspiciously,
discrete.

## Claim 2: the 2D idealization tracks the physical process closely enough

Because the move-set is small *and* each move has a clean flat-folded
mathematical idealization (ADR 0015 — flat-folded states only), we can apply
these operations **imperatively, in program order**, and get a data structure
that corresponds to an actual foldable physical object — not just an abstract
combinatorial artifact that happens to satisfy crease-pattern axioms.

That correspondence is the whole bet the language makes. It's what lets a
`.bel` program read as a straight-line imperative script (statement N mutates
global mesh state, no solver, no backtracking) instead of requiring physical
simulation (see [[beloch-render-engine-design]] and the fold-sim note,
`2026-07-03-fold-sim-dof.md`, for how much is thrown away by staying at the
flat-folded idealization — thickness, friction, DOF-during-collapse are all
punted to a *separate*, later, rendering-only concern).

## Why this matters

The two claims together are *why* Beloch-the-language can exist as a
programming language rather than a physics engine: small alphabet + faithful
idealization ⇒ deterministic imperative evaluation ⇒ a program is a real
recipe for a real fold, not just a symbol string that happens to type-check.
See `2026-07-06-fold-history-as-diff.md` for what the resulting evaluated
structure actually looks like once you take this seriously.

## Citation debt

"HJ axioms are a complete basis for flat single-fold operations" is a
citable origami-math claim (Justin / Hull's completeness results) — not
formalized here from memory per project citation discipline. Ground it in
`refs/` before this framing appears in a spec or paper section.
