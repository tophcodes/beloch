# Making illegal folded states unrepresentable (design review, 2026-07-15)

Conceptual review (Fable model), prompted by recurring geometry bugs where the
evaluator emits physically-invalid folds that pass the current checks — a flap
folding to the wrong side (vertex at negative coords, outside the paper), face
tears, self-intersections, wrong mover. Grounded in `refs/` (demaine2007,
hull2020, hullzakharevich2023, justin1986). Advisory — informs a future refactor,
not yet implemented.

## The core diagnosis

The literature models a flat folded state as a pair: an isometric folding map `f`
plus a layer ordering `λ` satisfying Justin's three non-crossing conditions —
and *nothing else is free* [demaine2007, §11.4; hull2020, §6.5;
hullzakharevich2023, §2.1]. Beloch's `Fold_state.t` stores strictly MORE degrees
of freedom than that pair has, and every extra degree of freedom is where a bug
lives.

### Where inconsistency enters
- **1a. Per-face isometries are free variables** (`fold_state.ml:8` `{paper; iso}`).
  The gluing condition that makes it a folding map — adjacent faces differ
  exactly by the reflection across their shared crease [hull2020 Def 6.5, Thm
  6.6] — is a comment, checked nowhere. A torn state is representable. The one
  anti-tear guard (`scoped_fold_hinge_closed`) covers only the scoped `up to`
  path; every other construction site re-establishes no-tearing by hand.
- **1b. `edges` duplicate adjacency the polygons already determine** — index
  bookkeeping maintained in 2½ copies (`subdivide`, `fold_with_records`,
  `subdivide_paper`, `flip`'s manual remap). Desync → phantom/missing hinge, and
  the taco checks trust exactly this hand-maintained data.
- **1c. Layer order is an arbitrary relation table, filled by rule, checked
  after.** Acyclicity, decidedness, taco conditions all post-hoc; `collapse`
  generate-and-filters over all linear extensions. The v1 "no sector-tucking"
  limitation is an artifact of enumerating whole-sector ranks.
- **1d. One fold decision, three independently coded consequences** — the parity
  rule `valley <> (det_sign iso < 0)` at `fold_state.ml:1152`, `:1226`,
  `collapse.ml:94`; stacking direction separately at `:1181` and `collapse.ml:262`.
  A sign slip in any copy = "flap folds to the wrong side" (passes Kawasaki/
  Maekawa, which are vertex-local and side-blind).
- **1e. `eassign` stored, not derived** — MV is a function of `(f, λ)`
  [hullzakharevich2023 §2.1]; Beloch patches it after the fact (collapse upgrade
  pass, on-axis upgrade, #27 stale-F).
- **1f. No choke point** — `validity_error` runs at 2 sites, skipped after
  `flip`; any new op can mint an unchecked state.
- **1g. The mover pick** (`eval.ml:940`) has no downstream cross-check; a
  wrong-but-coherent side sails through.

## Candidate models
- **A. Hinge-graph folding map.** Faces partition the sheet; hinges carry
  `folded : bool` (flat-only, ADR 0015). A face's isometry is DERIVED as the
  reflection-path product from a root face (= σf, [hull2020 Def 6.5]; already
  what `Collapse.sector_isometries` does for the fan). Makes tears, stale
  isometries, mover/stayer mismatch *unrepresentable*. Unifies
  `fold_with_records` and `collapse` state construction.
- **B. Total stacking order behind a smart constructor.** Replace the relation
  table with a rank permutation; `Above`/`Below`/`Apart` derived. Cycles &
  undecided overlaps become unrepresentable. Taco-taco / taco-tortilla
  [hull2020 §6.5 Prop 6.13] remain as THE one residual invariant, in a single
  `Fold_state.make : … -> (t, violation) result` with `t` abstract in a new
  `fold_state.mli`. Caveat: general layer feasibility is NP-hard [demaine2007
  §13.2; hull2020 Thm 6.17], so keep it scoped/incremental as today.
- **C. Silhouette containment — REJECTED as an invariant.** "Stays in [0,1]²" is
  NOT a law of legal folding (fold a large part over a strip → legitimately
  outside the footprint). The true per-fold fact is HALF-PLANE containment
  (moved material lands on side −s of its axis) — a theorem of reflection, so
  checking it catches only internal sign bugs. Add as a one-predicate tripwire,
  not a model.
- **D. Derived M/V.** Define `eassign` as a function of the two face placements
  + their layer relation [hullzakharevich2023 §2.1], computed at emit time;
  keep `eintent` stored (user intent). Deletes both upgrade passes + the
  triplicated parity rule.

## Recommended direction
**B first, then A, D falls out of A, C's half-plane tripwire immediately.**
B = highest bug-class-killed-per-line + creates the missing choke point;
A removes the tear class and dedups the subdivision bookkeeping (likeliest
"new config, new bug" source).

Migration sketch:
1. **Choke point (small PR):** `fold_state.mli` with `t` abstract + one
   constructor running `validity_error`; route `collapse` candidates and `flip`
   through it. Add the half-plane assertion in `fold_with_records`.
2. **Rank-based order:** `Layer_order.t` → `{rank; overlap}`; `fold_with_records`
   computes the spliced permutation directly; `collapse` feeds `linear_extensions`
   ranks in. Delete cycle/tortilla scans (now unrepresentable); keep taco checks
   in the constructor.
3. **Hinge graph authoritative:** hinges primary; `face.iso` a memo from
   reflection-path product; three `child_on` copies merge into one.
4. **Derived eassign:** delete upgrade passes + parity duplicates; one
   `mv_of_hinge`.

Not fixed by this (stated so nobody expects it): the SEMANTIC choice of which
flap `toward`/`moving` names (1g) is language design, not data model — but step 3
makes the pick happen exactly once (one fold-event record), and `.bel`
acceptance tests over `toward` guard the rest.

Key files: `lib/fold_state.ml`, `lib/collapse.ml`, `lib/layer_order.ml`,
`lib/eval.ml` (940–1012); `lib/flatten.ml` is already purely functional.
