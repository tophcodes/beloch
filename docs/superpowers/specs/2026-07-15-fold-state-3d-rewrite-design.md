# Fold-state rewrite: 3D-native, illegal states unrepresentable (design)

## Status

Proposed (2026-07-15). A clean rewrite of the folded-state core (`Fold_state`,
`Collapse`, `Layer_order`) to (a) make geometrically-inconsistent states
*unrepresentable* rather than caught post-hoc, and (b) become **3D-native** —
delivering ADR 0015's stated goal ("3D is a goal, not a carried feature"). Grows
out of issue #48 and the refs-grounded review `notes/2026-07-15-folded-state-invariants-review.md`.

**No legacy.** The old representation is replaced wholesale, not shimmed behind
compatibility accessors. The 7 in-flight branches that touch `fold_state.ml`
will rebase against the new API once.

## Motivation

Recurring geometry bugs — most recently a `flatten` derive folding a flap off
the sheet (#48) — share one root: `Fold_state.t` stores more degrees of freedom
than a legal folded state has. A folded state is a folding map `f` + a layer
ordering `λ` satisfying Justin's non-crossing conditions, and nothing else
[demaine2007 §11.4; hull2020 §6.5]. Beloch stores per-face isometries as free
variables, duplicated adjacency, an arbitrary layer-relation table, stored M/V,
and the fold-sense parity rule in three places. Each extra freedom is where an
inconsistent state (tear, wrong fold sense, undecided overlap) becomes
representable. Simultaneously the model is flat-only (2D isometries), while ADR
0015 names 3D as the intended endpoint.

## The model

`Fold_state.t` becomes **abstract** (`fold_state.mli`), built only via a smart
constructor. Internally it is a **hinge graph** (the face-adjacency graph):

- **Nodes = faces:** 2D paper polygons that partition the sheet (`Geom.point
  array`, sheet coordinates). The *paper* is 2D and exact; the 2D construction
  kernel (axioms, meet/join, crease pattern) is untouched.
- **Edges = hinges:** each shared crease between two adjacent faces, carrying its
  crease line + a **dihedral angle `θ ∈ Rat·π`** (rational multiples of π).
  `θ = 0` is a flat/unfolded crease (F/U); `θ = ±π` is a flat fold (the current
  ±180° behaviour). The graph is **undirected**.
- **Face placement is DERIVED, not stored.** `face_iso : t -> int ->
  Isometry3.t` is a **3D rigid motion**, computed as the product of the
  per-hinge motions along a spanning-tree path from a root face (identity). A
  hinge with angle θ contributes a **rotation by θ about its crease axis**
  (memoized BFS). This is the folding map σf [hull2020 Def 6.5] — already the
  shape of `Collapse.sector_isometries` for the single-vertex fan.

**Why 3D-native reproduces flat exactly.** A 3D rotation by **π** about a crease
line (in the z = 0 plane) *is* the 2D reflection across that line. So with all
angles in `{0, ±π}` the derived placements stay in the plane and equal today's
flat folded state — bit-for-bit, `cos π = −1`, `sin π = 0`, no new kernel. A
partial fold (`θ = rπ`, `r ∉ {0, ±1}`) lifts faces out of the plane into 3D.

**Layer ordering** is a **rank permutation** (`int array`), not a relation table.
`above`/`below` are derived (rank comparison for coincident-plane faces; true z
otherwise). In a flat state all faces are coplanar, so rank *is* the stacking; in
3D it breaks ties only for coincident faces. Cycles and undecided overlaps become
unrepresentable. The taco-taco / taco-tortilla non-crossing conditions [hull2020
§6.5] are the one residual invariant, checked in the constructor over the flat
projection.

**M/V is derived** (`mv : t -> crease_id -> mv`) from the two face placements +
their layer relation [hullzakharevich2023 §2.1]; `eintent` (user's crease-pattern
colour) stays stored. No stored `eassign`, no upgrade passes, no triplicated
parity rule.

**Smart constructor:** `make : faces:… -> hinges:… -> layer:int array -> (t,
violation) result`, running the non-crossing checks + a half-plane/consistency
assertion. `t` abstract in `fold_state.mli` ⇒ no module can mint an unchecked
state.

### Made unrepresentable
- **Tears** — a face's placement is a function of the graph; adjacent faces
  differ by exactly their hinge's motion, definitionally. No independent
  per-face isometry to desync.
- **Stacking cycles / undecided overlaps** — a rank permutation cannot cycle and
  decides every pair.
- **M/V contradicting geometry** — MV is derived, not stored.
- **Unchecked states** — `t` abstract; construction only through `make`.

## Exact arithmetic

- **Flat-first (this rewrite):** angle domain `{0, ±π}`. `cos, sin ∈ {1, −1, 0}`
  — no new kernel; `Isometry3.t` (3×3 rotation + translation over `Num.t`) with
  the rotation-by-π case. Reproduces current flat behaviour exactly.
- **Rational-π 3D (next stage, additive):** `θ = rπ` for rational `r`. `cos(rπ)`,
  `sin(rπ)` are **algebraic** (cyclotomic — real parts of roots of unity), so
  representable in the existing qqbar/`Num` kernel. Adds a `Num` constructor for
  `cos(rπ)`/`sin(rπ)` (via cyclotomic minimal polynomials); **no model change** —
  only the hinge angle's domain widens. Covers every "nice" origami angle
  (π/2 → 0,1; π/3 → ½,√3/2; π/4 → √2/2; …).
- Floats are **not** used for folded coordinates — Beloch stays exact in 3D.

## Clean-rewrite strategy

Old out, new in — no compatibility shim in the end state.

1. **New `Fold_state` module fresh** (`.ml` + `.mli`, abstract `t`; hinge graph;
   derived 3D `face_iso` flat-first; rank order; derived MV; `make`). Ships with
   its **own invariant tests** — construct known folds (single fold, rabbit ear,
   waterbomb) and assert the invariants + parity with today's flat coordinates.
   The new model is proven in isolation before any consumer attaches. Introduce
   `Isometry3` (3D rigid motion over `Num.t`) alongside/replacing 2D `Isometry`
   for placements (2D `Isometry` stays for the construction kernel).
2. **Rewrite `Collapse` + fold construction** against the new module: the
   sector fan becomes the generic reflection/rotation-path product; layer
   enumeration feeds the rank.
3. **Port consumers** (`eval`, `flatten`, `fold_emit`, the render bridge, tests)
   to the new API — all ~159 field-access sites move to accessors.
4. **Delete the old** — `Fold_state` internals, the `Layer_order` relation table,
   the M/V upgrade passes, the three `child_on` subdivision copies.

Trade-off (accepted): the build is **red during the port** (2–3); the new
module's own invariant tests are the confidence anchor, not the old suite. One
coordinated branch (`feat/fold-state-invariants`), not staged PRs.

## Stage decomposition

- **Stage A — flat-first 3D-native core.** The new module + `Isometry3` +
  smart constructor + rank order + derived MV, angles `{0, ±π}`. Port all
  consumers; delete old. End state: clean, 3D-native representation producing
  today's flat folded states exactly. This is the bulk.
- **Stage B — rational-π angles (additive).** `Num.cos_rpi`/`sin_rpi` (cyclotomic)
  + a surface/API to set a hinge to a partial angle; the folded state lifts into
  3D. No model change. Includes 3D self-intersection and 3D-aware rendering
  (the render `folded` view already has a 3D slot planned).

## Scope / deferred
- **This spec ships Stage A** (flat-first 3D-native rewrite). Stage B (partial
  angles) is the additive follow-up once the model is in.
- Which flap `toward`/`moving` names is language semantics, not data model — one
  fold-event record consumed once (step 3's side effect), guarded by `.bel`
  acceptance tests.
- 3D self-intersection, non-flat layer semantics, and the fold-*animation*
  (forward-only intermediate angles) ride on Stage B.

## References
- ADR 0011 (action model), 0014 (crease bundle), **0015 (flat-only today, 3D the
  goal — this delivers it)**, 0017 (flap coplanar).
- `notes/2026-07-15-folded-state-invariants-review.md` (the refs-grounded model
  analysis); issue #48.
- [demaine2007 §11.4, §13.2]; [hull2020 §6.5, Def 6.5, Thm 6.6, Prop 6.13];
  [hullzakharevich2023 §2.1].
