# 2026-07-03 — rendering sim: per-step DOF management for realistic collapse

Far-future rendering note (nowhere near current kernel roadmap). Capturing the
framing before it evaporates. Goal: turn folded states into believable
floppy-paper animation, not rigid kinematic morphs.

## Base physics model

Bar-and-hinge / mass-spring shell (à la Ghassaei's *Origami Simulator*,
Filipov/Tachi/Paulino MERLIN bar-and-hinge — **neither in `refs/` yet; verify
before formalizing**):

- **Creases → torsional hinges.** Two params, not one: a **rest angle** (sharp
  crease holds its fold, rest ≠ flat) and a **stiffness k**. "Crease hardness" =
  hard crease → nonzero rest angle **+ low k** (weakened fibers = floppy hinge
  that stays folded).
- **Facets bendable**, not rigid — diagonal bending hinges, own stiffness.
  Facets store bending energy transiently; this is what lets paper squeeze
  through a bind.
- **Layer count → stiffness** but bending scales ~t³, between `n·t³`
  (free-sliding sheets) and `(n·t)³` (bonded). Layers mainly show via
  **collision/thickness constraints**, not just stiffer springs.
- **Anisotropy is free** — emerges from the crease graph (stiff across facets,
  floppy along creases). Don't author a global tensor. (Paper grain, if wanted,
  *is* a global param.)
- **Curvature not from counts** — from inextensibility: Gaussian curvature ≈ 0
  (developable), concentrated at creases, smooth bending only along facet
  rulings.

## The real idea — per-step DOF management

Origami Simulator throws away what Beloch has: it ramps *all* rest-angles at
once, flat→final, with no notion of a step or an active crease. Beloch is
procedural — **each step knows its active fold axis.** Strictly more info.

Naive "crank force on one crease until something moves" = greedy descent → jams
in first local min, or unphysical snap-through/blowup. The real-life move
("relax fold A to collapse B, then redo A") is *climbing out* of a local min —
temporarily raising energy. Monotonic force can't go uphill.

Reframe: don't seek the **final** minimum. Per step, seek a good **intermediate
to launch the next step from.** Each step, partition creases:

- **active** — drive angle toward this step's goal
- **committed / frozen** — prior folds → hard constraint / high k, preserve
- **relaxable** — let open to clear the bind → drop k / free angle, then
  **re-freeze back to committed angle after** (verify snap-back — otherwise
  earlier folds drift; that's the bug that will bite)

### Choosing the relax-set (the hard part)

Cheap → smart:

1. **Adjacency** — relax creases sharing a vertex/facet with the active crease.
   Local neighborhood of the collapse. Often enough.
2. **Blocking-force ranking** (the good one) — solve with all frozen; if it jams
   (residual high, target angle unreached), the frozen constraints carrying the
   **most reaction force** are the binds. Release those, re-solve, re-tighten.
   This is **active-set constraint relaxation**, same trick contact solvers use.

### Crisp framing: it's degrees of freedom

Frozen set *removes* DOF; a single-DOF rigid mechanism folds along one forced
path. The relaxable set *adds back just enough DOF* to clear the bind. "Which
crease to relax" = "which extra DOF to unlock this step." Not blind annealing —
the fold sequence gives semantic priors that **seed the active-set**, far cheaper
than global search.

So: OS = blind global morph. Beloch wants **per-step constrained rigid-fold +
compliant escape valve**, relax-set chosen by blocking force. The give-and-take
is *directed*, not emergent-from-cranking.

## Forks to decide later

- **All-at-once collapse** (global ramp) vs **sequential YR-diagram folding**
  (step-at-a-time). Latter makes "relax A" an explicit choreography/planning
  problem, not just physics — and YR diagrams are a stated Beloch output.

## Citation debt

Rigid-foldability, DOF-of-crease-pattern, single-vs-multi-DOF folding paths =
origami **math**, not just graphics — Tachi's rigid-origami work is home turf.
Not formalized here from memory (per project citation discipline). Before this
becomes spec: get Tachi + rigid-foldability + a bar-and-hinge paper into `refs/`
and `paper/references.bib`.
