# Flap = coplanar cluster of faces (ADR 0017 implementation)

**Date:** 2026-07-06
**ADR:** [0017 — A flap is a coplanar cluster of faces, not a single precrease
polygon](../../../decisions/0017-flap-is-coplanar-not-precrease-partition.md)
(Proposed → this spec is the implementation; acceptance flips it on merge)

## Problem

Today the **flap** operand type (consumed by `moving`, `up to`, and the `#(...)`
incidence selector — ADR 0016) resolves to a single **face**: one convex polygon
in the fine partition `subdivide` carves. A face boundary appears the moment
*any* crease crosses a polygon — including a bare `map X onto Y` **precrease**
that folds nothing and leaves the sheet flat (the new edges are assignment `U`,
physically coplanar with their neighbour).

That precrease granularity causes two concrete defects (ADR 0017 §Context, both
verified empirically against the running evaluator):

1. **`#(...)` fails on a still-flat sheet.** On the rabbit-ear precrease step,
   corners `.a` and `.d` land on two *different* (adjacent, edge-sharing) faces,
   so `--bb at #(.a .d)` — "the segment on the flap holding both corners" — fails
   with `those points aren't all on one flap`, even though nothing is folded.

2. **Stale point→position lookup.** A scoped fold moves face `F` but leaves its
   `U`-adjacent neighbour `G` behind. Their shared `U` edge is now physically
   torn (F flipped, G flat) yet still tagged `U`. A point on that edge
   (`table_position` / `faces_containing`) resolves to the wrong owning face and
   reports a stale position.

Both share one root: the flap is defined at *precrease* granularity, but the
meaningful physical unit is the *coplanar region*, which only fractures when a
crease is actually **folded** (`U → M/V`).

## Decision

Redefine **flap** as a **maximal connected cluster of faces still physically
coplanar**: faces reachable from one another through interior edges whose crease
assignment is still `U`. Two faces separated only by a `U` edge are the **same**
flap; the instant that edge folds (`U → M/V`) the flap splits there, exactly and
only there.

**"Face" is unchanged.** The fine per-precrease partition (ADR 0014) keeps its
meaning for crease/segment *addressing* (`at`, `pinch`, `crease_segments`,
`crease_id` tagging, FOLD edge output). This changes **only** the coarser flap
grouping that sits on top of faces for scope and incidence.

### Key design choice: cohesion, not a cluster-wide rewrite of `select_scope`

ADR 0017 flags one open question as the most important to settle: lifting
`select_scope`'s per-face **depth-along-crease** reasoning (per-face `piece` /
`overlap` / outer-prefix, `demaine2007 §14.1`) to clusters risks breaking it —
a multi-face cluster can sit at different stack depths over different portions of
one crease, so a cluster-to-cluster "outer" relation may be ill-defined.

**We do not lift that machinery to clusters.** We keep `select_scope`'s per-face
`piece` / `overlap` / `outer` / buried-check *exactly as today*, and add a single
**cohesion constraint**: the moving set may never tear a coplanar cluster —
`U`-adjacent faces move together. Concretely, cohesion is an extra closure edge
in the existing fixpoint: if any face of a cluster moves, all faces of that
cluster move. This:

- fixes defect (2) **by construction** — a still-flat neighbourhood is one flap,
  wholly inside or wholly outside any fold's moving set, so `table_position`
  never straddles a torn `U` edge; `table_position` needs **no change**;
- preserves "depth varies along the crease" **for free** — the piece/overlap/
  layer math stays per-face; only *membership* is coarsened;
- is the smallest, lowest-risk change that satisfies the ADR.

Defect (1) is fixed by making `flap_of_points` (and the `resolve_flap_face` /
`side_of_flap_arg` / `at_matches` call sites) **cluster-valued**.

## Components

### A. Coplanar-cluster computation — `lib/fold_state.ml` (new)

A function over the current `Fold_state.t` assigning each face a cluster id:

```
val coplanar_clusters : t -> int array
(* clusters.(i) = component id of face i in the graph whose nodes are faces
   and whose edges are interior adjacencies with eassign = U *)
```

Build: union/flood over `st.edges` keeping `e.left >= 0 && e.right >= 0 &&
e.eassign = U`; connected components by BFS/union-find over `n = |faces|`.
`O(faces + edges)` per call.

ADR 0017 §Consequences argues against baking in "folds only ever split": `unfold`
(roadmap) will *merge* clusters. The robust choice is **recompute from the
current `U`-edge set at each resolution point** — no incremental cache, no
split/merge bookkeeping. Recompute-each-time is `O(faces + edges)`; performance
on large crease patterns is flagged but not optimised now (§Open questions).

Helper for the multi-point / cluster-membership tests:

```
val cluster_of_points : t -> Geom.point list -> [ `Cluster of int list | `Zero | `Ambiguous ]
(* the unique cluster (as its face-index list) whose union of paper polygons
   contains every point; `Zero if no single cluster does, `Ambiguous if >1 *)
```

`flap_of_points` (line 352) is **replaced** by / re-expressed through
`cluster_of_points`: a set of points resolves to one flap iff a single cluster
contains all of them (points on a shared `U` edge count as inside both faces →
same cluster → resolves; the old `[i] | [] | _` face-count logic becomes a
cluster-count logic).

### B. `flap_of_points` → cluster (fixes defect 1) — `lib/fold_state.ml:352`

Return the containing **cluster** instead of the unique containing face. Signature
shifts from `[ \`Face of int | \`Zero | \`Ambiguous ]` to a cluster result (a face
list, or a representative + membership — whatever the call sites need; see C).
`Zero`/`Ambiguous` keep their meaning at cluster granularity.

### C. Call sites → clusters — `lib/eval.ml` (~306–476)

- **`at_matches` `SelFlap` (line 351)** — a segment is incident to the flap iff
  *either* of its faces (`s.faces = (l, r)`) is in the cluster, not just equals a
  single face index. `Zero`/`Ambiguous` errors unchanged in wording.
- **`resolve_flap_face` (line 378)** — currently returns one face index. It now
  resolves the operand to a **cluster**. Downstream consumers differ:
  - `target_of` / `select_scope` anchor & target want a **face predicate or
    representative**, not a bare index — a `TargetFace t` becomes "any face in the
    cluster" (a `TargetHinged`-style predicate, or the cluster's face set).
  - `side_of_flap_arg_res` (line 442) must test the **whole cluster** against the
    axis: the cluster straddles iff *any* member face has vertices on both sides;
    lies on one side iff *all* member faces do. Same `OnAxis` / `Straddles`
    verdicts, computed over the union.
  - The `FlapLine` branch (crease-named / `at`) already yields a set of candidate
    faces; it collapses to the set of clusters those faces belong to, and errors
    "touches N flaps" now count **clusters**, not faces.
- **`faces_containing` (line 367)** stays (it feeds `resolve_flap_face`'s
  `FlapPoint` branch); its result is mapped through `coplanar_clusters` to a
  cluster before the uniqueness check, so a point on a `U` boundary no longer
  reports "lies on a crease shared by N flaps".

Exact return shapes are an implementation detail for the plan; the contract is:
every flap operand resolves to a cluster, and every consumer that held a single
face index now holds the cluster (its face set) or the representative it needs.

### D. `select_scope` cohesion (fixes defect 2) — `lib/fold_state.ml:385`

Leave `piece` / `cand` / `overlap` / `outer` / `find_targets` / the buried check
untouched. Add cluster cohesion to the closure fixpoint (lines ~456–468): the
moving set is closed under **both**

1. the existing rule — a candidate `g` outside a moving `m` over the crease
   region must move (`outer g m`); and
2. **new** — a face `g` `U`-adjacent to a moving face `m` (same cluster) must
   move.

Rule 2 uses `coplanar_clusters st`: `inm.(g)` becomes true whenever any face in
`g`'s cluster is in `inm`. The buried-flap check runs **after** cohesion, so if
pulling in a cluster member buries the anchor, that is a legitimate "cannot move a
buried flap" error (the fold genuinely can't be done as written) — same error
surface as today, wording unchanged.

Also feed cohesion to the **default (non-`up-to`) scope** predicate in `eval.ml`
`run_fold_checked` (lines 716–722): today "a face moves iff it has a piece on
`move_side`". A face straddling the axis is subdivided by the fold crease (a
legit `M/V` split), so default scope only tears along the axis — **verify** this
already respects clusters and add cohesion only if a repro shows a tear. (Default
scope moving a half-plane should not leave a flat `U`-neighbour behind on the
*same* side; confirm with a test before adding code here — YAGNI.)

### E. `table_position` / `faces_containing` — unchanged

No code change. With cohesion (D) guaranteeing clusters never tear, a point in a
still-flat neighbourhood belongs to one flap that moves as a unit, so its
`U`-adjacent faces always agree on position — the existing "any containing face
works" invariant holds again. This is the "fixed by construction" claim; a
regression test (defect 2 repro) guards it.

### F. Error-message wording

Existing messages already say "flap" ("those points aren't all on one flap",
"lies on a crease shared by N flaps; name the flap with `#(...)`", "touches N
flaps"). With clusters these become *true* (a flat sheet is one flap) and mostly
fire less often. Audit each for correctness under the new granularity; keep
wording where it still reads right.

## Testing

TDD, rabbit-ear geometry as the source of both repros (note: the ADR's exact
repro lines are *not* in committed `examples/bases/rabbit-ear.bel`, which uses
`@collapse`; they were live-debug constructs — we reconstruct them as tests).

1. **Defect 1 — `#(...)` on a flat sheet.** Precrease a square (bare binds, no
   `@fold`), then a statement using `#(.a .d)` (two corners on different precrease
   faces). Assert it resolves (no "those points aren't all on one flap"). Red
   before, green after B/C.
2. **Defect 2 — stale position after scoped fold.** Reproduce the ADR scenario:
   precrease, `@fold` one corner flap, then a scoped `@fold ... moving #(...) up
   to #(...)` whose anchor face is `U`-adjacent to an out-of-scope face; assert
   the named point's FOLD table position is the moved (correct) value, not the
   stale `(0,0)`. Red before, green after D.
3. **Cluster split on fold.** After a real `@fold` of the crease between two
   faces, assert those faces are now in **different** clusters (the `U→M/V`
   transition splits the flap), and a `#(...)` spanning both now errors
   `Ambiguous`/`Zero` as appropriate.
4. **Regression.** Full existing example + test suite green — especially
   `rabbit-ear.bel`, the fold-scope `up to` examples, and taco/layer-order tests
   (`select_scope`'s per-face math must be byte-stable where no cluster spans the
   moving boundary).

Success criteria: defect tests 1–2 red→green, split test 3 green, entire suite
(4) green, `dune build` + `dune runtest` clean.

## Open questions / risks (from ADR 0017, status here)

- **Depth-along-crease vs `select_scope`** — *resolved by scope*: we keep the
  per-face machinery and only add membership cohesion, so the conflict the ADR
  feared never arises. (If a future change *does* lift overlap/outer to clusters,
  this returns — out of scope here.)
- **Default-scope tear** — *to verify with a test* (component D); add cohesion to
  the default predicate only if a repro demonstrates a tear. Do not add
  speculatively.
- **Bent-crease detection** — `@fold` across a bent crease is already an error
  (ADR 0014). The check is over the crease bundle's *segments*, not flaps, so the
  cluster change should leave it untouched; add a regression test asserting a
  bent-crease `@fold` still errors, don't assume.
- **Performance** — recompute-each-time is `O(faces + edges)` per resolution.
  Flagged, not optimised; revisit only if a real crease pattern shows it matters.
- **`unfold` (future)** — merges clusters. Recompute-from-current-`U`-edges
  handles merge and split identically; no assumption baked in that the relation
  only coarsens or only fractures.

## Non-goals

- No change to `subdivide`, `crease_id` tagging, segment enumeration, or FOLD
  `U`/`M`/`V` edge output (faces stay fine-grained).
- No incremental cluster cache / union-find persistence (recompute each time).
- No `pinch` / `at` addressing change (they operate on faces/segments).
- No lifting of `overlap` / `outer` / stack-order to clusters.
