# 0003 — Restart from a minimal formal core, don't patch the 2018 design

**Status:** Accepted

## Context

Beloch was first attempted in 2018 (then "OrigamiDL"). That design grew by
accumulating features — `step`, landmarks, `part`/import, special folds, runtime
directives — until it felt expressive, then hit a wall: layers and folded-state
ordering, which made the accumulated features mutually inconsistent. The project
went dormant for ~8 years for that structural reason, not for lack of interest.

The 2018 issues (ambiguity, special folds, "things go 3D", layer numbering in
the bookmark example) still read as the right questions. They are evidence the
problem is real and hard — not a design to be repaired.

## Decision

Do **not** patch the 2018 design or "fix the layer problem" inside it. Restart
from the smallest core that has a rigorous, fully defensible semantics, and grow
it deliberately, never implementing further than what's been formally designed.

Inversion of control for language design: instead of "here's what I want to
express, find the semantics", go "here's a minimal semantics I can fully defend,
now see what it expresses".

The 2018 issues become the **test suite**, not design input: "can the
ground-up minimal core recover what the ad-hoc design tried to express?"

First increment target (v0.0): one square of paper, the seven axioms (or even
just axiom 1 to start), one type (crease line), output to FOLD. **No** layers,
folded state, regions, or composition yet. Add one concept at a time, extending
the formalism with each.

## Alternatives considered

- **Continue/patch the existing design.** Rejected — there is nothing to debug;
  the design was incomplete in a way that made further design impossible.
  Patching produces something broken just well enough to ship.
- **Design the whole language up front, then implement.** Rejected — that
  waterfall is exactly what stalled in 2018 and how PhD students burn five years
  without shipping. Design and implementation proceed in tight cycles.

## Consequences

- Slower-feeling start (formal semantics for a tiny subset before features), but
  a foundation that won't need replacing again.
- Every feature must arrive with its semantics written down first.
- Reading the literature happens interleaved with design, not as a phase before
  it (see `../notes/` journal and `../bibliography.md`).
