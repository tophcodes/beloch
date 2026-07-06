# 0017 — A flap is a coplanar cluster of faces, not a single precrease polygon

## Status
Accepted (2026-07-06) — implemented in
[docs/superpowers/specs/2026-07-06-flap-coplanar-cluster-design.md]. Acceptance
refined one point: `#(...)` is cluster-valued only where it names a **physical
flap** (`moving`, `up to`); as a **segment/sector address** (`at #(...)`,
`@collapse over/under #(...)`) it stays **face-fine** — see *Granularity split*
below. Originally filed Proposed (2026-07-06).

This is the repository's first `Proposed` ADR (0001–0016 are all `Accepted`).
It records a design change that came out of a live debugging session on
`examples/bases/rabbit-ear.bel`; it has **not** been implemented or accepted.
The format lists it (`Proposed`) as a valid status; this entry sets the
precedent for using it.

## Context

ADR 0016 fixed the *operand type* consumed by `moving`, `up to`, and the
`#(...)` incidence selector: a **flap**. The fold-scope design
(`docs/superpowers/specs/2026-07-05-fold-scope-design.md`) and the current
evaluator resolve that flap type to a single **face** — one convex polygon in
the fixed partition `subdivide` carves. A face boundary is created the moment
**any** crease crosses a polygon (ADR 0014: creasing runs `subdivide`, which
cuts every face the axis crosses and tags each resulting edge with the shared
`crease_id`). Crucially, that partition is cut by *precreases* too: a bare
`map X onto Y` bind materialises a crease bundle and subdivides, even though
nothing folds — the new edges are assignment `U` (unfolded), physically flat,
coplanar with their neighbour across the edge (`lib/fold_state.ml`:
`type assign = M | V | U`; `subdivide` emits `eassign = U`).

The spec chose this face-per-precrease-polygon granularity deliberately, to get
partial-scope folds (`up to`, petal folds, top-flap-only) cheaply: the
fold-scope design notes "the per-flap face sets give us [depth varying along the
crease] for free" (§ *Validity*), and `select_scope`
(`lib/fold_state.ml`) reuses that same fine face partition everywhere —
computing per-face `piece`s, `overlap`, and `outer` stack relations over raw
face indices.

A debugging session on `examples/bases/rabbit-ear.bel` (verified empirically
against the running evaluator, not reasoned from the source) found this
granularity causes two concrete problems:

**1. Surprising `#(...)` failures on a still-flat sheet.** The precrease step
alone — three bare binds `--v = map .a onto .b`,
`--ba = map --(.a .b) onto --(.a .m)`, `--bb = map --(.b .a) onto --(.b .m)` —
splits the square into 6 faces around the incenter `.o`, *before any `@fold`
runs*. Two corners, `.a` and `.d`, land on two **different** face polygons
(adjacent, edge-sharing, distinct). So `--bb at #(.a .d)` — meaning "the segment
of `--bb` on the flap that holds both corners" — fails with

> those points aren't all on one flap

(the `` `Zero `` branch of `flap_of_points`, `lib/fold_state.ml:352`, surfaced
through `at_matches`/`SelFlap` in `lib/eval.ml`). Direct instrumentation of
`flap_of_points` confirmed this is *correct* for the current definition (no two
faces contain both points), **not** a bug in that function. It is a granularity
mismatch: the user's — and the physically natural — model is "nothing folded ⇒
still one flap," while the implementation's model is "any precrease line, folded
or not, is a flap boundary."

**2. A confirmed lookup bug that is a direct symptom of (1).** After
`@fold --ba moving .b mountain` folds one small corner flap, a second fold
`@fold --bb at #(.d .m) moving #(.a .pl) up to #(.a .pl)` computes the
**correct** isometry for the face carrying `.a` — verified by dumping the raw
`beloch:faces_matrix` output: the moved face gets the mathematically correct
translation (e.g. `(0.5528, 0.8944)`, matching an isolated single-fold control
run). But the FOLD table position reported for the named point `.a` still comes
back as the stale, unmoved `(0, 0)`. Root cause: `.a` sits exactly on the
boundary between the just-moved face and a **different, adjacent** face that is
still coplanar with it (its dividing edge is a `U` precrease) but was not in
this fold's scope. The point→position lookup (`faces_containing` /
`table_position`) picks the wrong owning face when a shared boundary vertex's
two adjacent faces diverge in movement state. This cannot occur if a flap is a
coplanar cluster: `.a`'s whole still-flat neighbourhood is one flap, so it is
either entirely inside or entirely outside a fold's moving set, never
straddling it.

Both symptoms have the same root: the flap operand is defined at *precrease*
granularity, but the meaningful physical unit is the *coplanar region*, which
only fractures when a crease is actually **folded** (`U → M/V`).

## Decision

Redefine **flap** — the operand type consumed by `moving`, `up to`, and the
`#(...)` incidence selector (ADR 0016) — as a **maximal connected cluster of
faces that are still physically coplanar**: faces reachable from one another
through edges whose crease assignment is still `U` (unfolded). Two faces
separated only by a `U` edge are the **same** flap. The instant that specific
edge's assignment transitions `U → M/V` (its crease is actually folded), the
flap **splits into two** at exactly that edge, and stays split thereafter.

Formally: over the current `Fold_state.t`, build the graph whose nodes are faces
and whose edges are the interior face-adjacencies with `eassign = U`. A flap is
one connected component of that graph. The split rule is local and exact — a
flap divides at the precise edge whose assignment changes, at the moment the
fold that changes it runs; no other flap is affected.

**"Face" is unchanged.** The fine per-precrease-polygon partition (ADR 0014's
subdivision granularity, needed for crease/segment bundle *addressing* — `at`,
`pinch`, `crease_segments`) keeps its current meaning and stays fine-grained.
This ADR does **not** change how creases/segments subdivide the sheet, how
edges carry `crease_id`, or how a bundle enumerates its segments. It changes
**only** the coarser flap grouping that sits *on top of* faces for scope and
incidence.

What changes, all to operate on coplanar-clusters instead of raw face indices:

- **`flap_of_points` (`lib/fold_state.ml:352`)** — instead of "the unique face
  whose paper polygon contains every point," returns "the unique **flap**
  (coplanar cluster) containing every point." Points that fall on adjacent faces
  joined by a `U` edge now resolve to one flap. `Zero`/`Ambiguous` keep their
  meaning at cluster granularity.
- **`#(...)` as a physical-flap operand (`resolve_flap_cluster`, `lib/eval.ml`)**
  — `moving`'s point/line/`#(...)` sugar and the `up to` anchor/target become
  **cluster**-valued. Callers that today hold a single face index (to pick a fold
  side, or the scope anchor) hold a cluster (a set of faces), or a representative
  the lookup needs. **`at #(...)` and `@collapse over/under #(...)` do NOT** —
  they stay face-fine (`face_of_points` / `resolve_sector_face`); see below.
- **`moving` and `up to`** — the anchor and range are chosen among **flaps**
  (clusters), then expanded to the constituent faces for the actual reflection.
  A point/line/`#(...)` operand resolves to the cluster it is incident to; the
  reflection still applies face-by-face underneath.
- **`select_scope` (`lib/fold_state.ml:385`)** — the `piece` / `overlap` /
  `outer` / stack-walk machinery ranges over **clusters** where it currently
  ranges over faces: candidacy, overlap in the crease region, and the
  outer-contiguous-prefix (buried/`outer`) check are judged between coplanar
  clusters, so a cluster moves or stays as a unit. (Whether the per-face `piece`
  computation is kept and aggregated per cluster, or recomputed at cluster
  granularity, is an implementation detail — see open questions on `depth may
  vary along the crease`.)
- **Point→position lookup (`faces_containing` / `table_position`)** — a boundary
  vertex shared by faces in the same flap is unambiguous (they share an
  isometry, being coplanar), so the stale-position bug (2) disappears; a vertex
  on a *folded* edge legitimately belongs to two flaps and is disambiguated the
  same way stacked material already is (ADR 0014: layer identity).

The split rule makes the "crease all, fold some" case (fold-scope design, and
spec §4.6) fall out cleanly: a bare bind creases all layers (`U` edges — same
flap, no split); `@fold … up to …` folds some (those edges become `M/V` — the
flap splits there, and only there).

### Granularity split: clusters for scope, faces for addressing

Implementation surfaced a real conflict this ADR originally glossed: `#(...)`
serves two purposes with **opposite** granularity needs on a still-flat sheet.

- As a **physical-flap operand** (`moving`, `up to`) it means "this coplanar
  region" → wants the **coarse cluster**. A flat sheet is one flap: correct.
- As a **segment/sector address** (`at #(...)`, `@collapse over/under #(...)`) it
  disambiguates *which* segment of a crease bundle, or *which* stacked sector,
  by naming the face it belongs to → wants the **fine face**. On a flat sheet
  the whole sheet is one cluster, so a cluster-valued `#(...)` would name
  *everything* and could no longer pick one of several coplanar segments.

The load-bearing counterexample is `examples/syntax/collapse-midpaper.bel`:
`--h at #(.q .tm)` selects one of two coplanar segments of `--h` by naming a
flap; under clusters both segments share the one flat flap and the selection
becomes ambiguous. So the two uses **must** resolve at different granularities.

Decision: `#(...)` is cluster-valued **only** in `moving` / `up to`
(`resolve_flap_cluster`). `at #(...)` and `@collapse over/under #(...)` keep the
old face-fine resolution (`face_of_points` / `resolve_sector_face`). Consequence:
this ADR's Context example `--bb at #(.a .d)` — an `at`-address — deliberately
stays face-fine and still errors on a fully-flat sheet with `.a`/`.d` on distinct
faces; the flat-sheet resolution win applies to the *scope* uses, which was the
functionally load-bearing case (defects 1 and 2 both arose in `moving`/`up to`
resolution). `pinch` and `crease_segments` were already face-fine and unchanged.

## Alternatives considered

- **Keep flap = face; fix the lookup bug (2) locally.** Rejected: it treats the
  symptom, not the cause. The point→position ambiguity is one consequence of the
  same over-fine granularity that also produces (1); a local fix leaves
  `#(.a .d)`-style failures on flat sheets, and every future scope/incidence
  site inherits the same trap.
- **Merge precrease faces back into one polygon (undo the subdivision for flat
  creases).** Rejected: it destroys ADR 0014's addressing granularity — the
  segment bundle needs the fine partition to enumerate and select segments
  (`at`, `pinch`). Faces must stay fine; only the flap *grouping* should coarsen.
- **Make the user disambiguate (`#(.a .d …)` with more points, or `at` with a
  segment selector).** Rejected: it pushes an implementation artifact onto the
  language surface. On a still-flat sheet the natural referent is one flap; the
  language should not demand extra constraints to name a region physics has not
  yet divided.

## Consequences

- **Simpler for the user, matching physical intuition.** In
  `examples/bases/rabbit-ear.bel`, `--bb at #(.a .d)` would very likely resolve:
  before any `@fold`, `.a` and `.d` lie in faces joined only by `U` precreases,
  so they fall in the same coplanar cluster, and `flap_of_points` returns one
  flap. "Still flat ⇒ still one flap" becomes true in the implementation, not
  just the mental model. (To be confirmed on the actual repro when implemented —
  stated here as the expected outcome, not verified against a build.)
- **The confirmed position bug (2) is eliminated by construction**, not patched:
  a point in a still-flat neighbourhood belongs to exactly one flap, which is
  wholly inside or wholly outside any fold's moving set, so its owning face after
  a fold is unambiguous.
- **New implementation machinery: a live coplanar-connected-components
  computation.** Most naturally: a graph over faces joined by `U`-assigned
  interior edges, giving each face a flap (cluster) id. It must reflect the
  current `Fold_state.t` at every resolution point.
  **Folds don't only split clusters — `unfold` is on the roadmap
  (spec Appendix B: "fold maneuvers (reverse/squash/sink/petal, via `unfold` +
  layer selection)"), and unfolding a crease (`M`/`V` reverting to `U`) merges
  two flaps back together.** Today's evaluator has no `unfold` yet, so within
  the *current* language a fold only ever splits (this ADR's scope) — but that
  is a fact about today's operation set, not a property of the model, and it
  will stop holding the moment `unfold` ships. Note also that this cuts the
  other way for the data structure, not just the direction of change:
  union-find is efficient at *merging* (`union`) and has no native support for
  *splitting* — so a plain union-find is actually the wrong fit for the split
  a fold does today, and would only become a good fit for the merge `unfold`
  will eventually do. The robust choice either way is to recompute connected
  components from the current `U`-edge set on resolution (or incrementally
  maintain them by re-flooding just the affected component on a split, and
  unioning on a future `unfold`), not to bake in an assumption that the
  relation only ever coarsens or only ever fractures.
- **Face addressing is untouched.** `at`, `pinch`, `crease_segments`, `crease_id`
  tagging, and the FOLD `U`/`M`/`V` edge output all keep working on faces exactly
  as today. Only `moving` / `up to` / `#(...)` change referent.

### Open questions / risks

- **Interaction with `select_scope`'s `outer` / `overlap` / stack-order checks.**
  These currently compare per-face `piece`s in the crease region using
  `Layer_order` over face indices. Lifting them to clusters must preserve
  "depth may vary along the crease" (fold-scope design § *Validity*): different
  faces of one cluster may sit at different stack depths over different portions
  of the crease. Whether the outer-contiguous-prefix test stays correct when the
  moving unit is a multi-face cluster spanning several depths is **not yet
  verified** and is the single most important thing to settle before
  implementing — it is where the coarser flap and the still-fine
  depth-along-crease model could genuinely conflict.
- **Bent-crease detection.** `@fold` across a bent crease is already an error
  (ADR 0014, spec §4.6). Whether the coplanar-cluster split changes which folds
  count as "bent under the moving set" — or leaves it unchanged, since that check
  is over the crease bundle's segments, not flaps — needs checking, not assuming.
- **Performance on large face counts.** Recomputing connected components at every
  flap resolution is `O(faces + edges)` per resolution; on large crease patterns
  this may matter. Whether recompute-each-time is acceptable or incremental
  maintenance is required is an open question — flagged, not answered, because it
  has not been measured.

## References

- ADR 0014 (a crease is a bundle of segments — why faces stay fine-grained)
- ADR 0016 (typed operands: the flap operand type this ADR redefines)
- `docs/superpowers/specs/2026-07-05-fold-scope-design.md` (the per-face
  granularity choice this revisits; § *Validity* on depth-varying-along-crease)
- `spec/SPECIFICATION.md` §4.6 (`@` / `@fold` / `moving` / `up to`), §4.8 (`at`)
- `examples/bases/rabbit-ear.bel` (the repro for both findings)
- `lib/fold_state.ml` (`flap_of_points` :352, `select_scope` :385,
  `type assign`, `subdivide`); `lib/eval.ml` (`resolve_flap_face`,
  `at_matches`/`SelFlap` ~306–435)
- [demaine2007, §14.1] (simple folds; the model behind `select_scope`)
