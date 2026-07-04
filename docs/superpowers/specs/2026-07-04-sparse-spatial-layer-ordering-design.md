# Sparse spatially-indexed layer ordering

**Datum:** 2026-07-04
**Base:** `main` (feec9b9, post-#56)
**Motivation:** Scaling spike (this session) — the folded-state evaluation is
`O(faces²)` per fold because the layer order is a dense `rel array array` and
`build_order` runs `convex_overlap` on every `i<j` pair. Measured: ~256 faces
0.37s, ~512 faces 1.5s, ~1024 faces 6s, ~2048 faces 24s per fold. This caps
practical folded programs (and thus tessellations) at ~1–2k faces.

## Goal

Make layer ordering scale sub-quadratically for **spatially-distributed** fold
patterns (tessellations, where only `O(faces)` pairs actually overlap locally),
lifting the practical ceiling from ~2k to tens of thousands of faces — while
keeping every result byte-identical to today.

## Honest scope

The win is for patterns whose faces overlap **locally** (tessellations, pleats
spread over the sheet). A fully-overlapping stack (e.g. repeated in-place
halving) has genuinely `O(faces²)` layer relations and stays `O(faces²)` — that
is inherent, not a defect, and is rare in real origami. This slice targets the
tessellation case explicitly.

## Success criteria

- **Byte-identical output**: every golden `.fold` (esp. the faceOrders arrays)
  is unchanged. This is the hard gate — a golden diff means a real regression.
- Full test suite green.
- A distributed pleat/tessellation of N faces builds in measured sub-quadratic
  time (a new scaling test asserts the curve, e.g. doubling N well under 4×
  time on the spread case).
- No numerical approximation in the decision path — overlap is still decided by
  exact `Geom.convex_overlap`; the spatial index only culls candidate pairs
  conservatively.

## Architecture

### New module `lib/layer_order.ml`

The order logic is a cohesive sub-unit with a clear interface; extract it from
`fold_state.ml` (already 575 lines) into its own module so it is testable in
isolation and `fold_state` shrinks. Abstract type + interface:

```
type rel = Above | Below | Apart      (* moved here from Fold_state *)
type t                                 (* sparse: stores only OVERLAPPING pairs *)

val empty     : t
val get       : t -> int -> int -> rel
  (* Apart when the pair is absent (= not overlapping). O(1)-ish. *)
val build     : Geom.point array array -> (int -> int -> rel) -> t
  (* faces given as their table-space polygons; rel_of supplies the relation
     for each overlapping pair (from parent inheritance, etc.). Uses the
     sweep-and-prune broad phase below. *)
val iter      : t -> (int -> int -> rel -> unit) -> unit
  (* over stored (overlapping) pairs, each unordered pair once as i<j. *)
val above_neighbors : t -> int -> int list          (* j with get i j = Above *)
val flip      : t -> int -> t                        (* n -> remap k↦n-1-k, negate *)
```

**Representation.** Per-face adjacency of overlapping pairs, each carrying its
`rel ∈ {Above, Below, Apart}`. The three-way distinction is load-bearing and
preserved exactly:

- **absent** = the pair does **not** overlap on the table (truly apart).
- **present with `Apart`** = the pair **overlaps** but has no decided order —
  this is exactly a tortilla-tortilla violation, which `validity_error` must
  still detect.
- **present with `Above`/`Below`** = decided order.

Concretely: `overlaps : (int * rel) list array` indexed by face id, storing each
pair once canonically (i<j) plus the negated view for i>j, or a symmetric
`(int, rel) Hashtbl` — the exact container is a plan-level tuning choice; the
interface above is the contract. Lookup must stay near-O(1) even when one face
overlaps many (dense-stack case), so a hashtable keyed on the canonical pair is
the safe default; a per-face adjacency list is kept for iteration.

### Sweep-and-prune broad phase (exact)

`build` replaces the `O(n²)` `convex_overlap` loop with a sweep-and-prune:

1. Compute each face's **exact** table-space bounding box (`Num` min/max over
   its polygon vertices). No float.
2. Sort face indices by bbox `xmin` (`Num.compare`).
3. Sweep in that order, maintaining an active set of faces whose `xmax ≥` the
   current face's `xmin`. For each new face, compare only against the active
   set; drop actives whose `xmax <` the new `xmin`.
4. For an x-overlapping candidate pair, check bbox-y overlap (exact), then run
   exact `Geom.convex_overlap` on the polygons. On overlap, store
   `rel_of i j`.

Complexity `O(n log n + k · c)` where `k` = x-interval-overlapping pairs and `c`
= `convex_overlap` cost. For distributed patterns `k = O(n)`; for a fully
overlapping stack `k = O(n²)` (inherent). **Finds exactly the same overlapping
pairs as today's `O(n²)` loop** (same exact `convex_overlap` as the final test),
so the relation — and thus all output — is unchanged.

## Consumers to adapt

All within `fold_state.ml` and `fold_emit.ml` (the only files touching `order`):

- `validity_error`: cycle DFS over `Layer_order.above_neighbors`; tortilla check
  over `Layer_order.iter` picking `Apart` entries (overlap-but-undecided).
- `topmost_preimage`: `Layer_order.get st.order i j`.
- `subdivide` and `fold_with_records`: `Layer_order.build` with the existing
  `rel_of` closure (parent-relation lookup now via `Layer_order.get st.order`).
  Semantics identical.
- `flip`: `Layer_order.flip st.order n`.
- `fold_emit.to_json_folded`: collect pairs via `Layer_order.iter`, **sort by
  `(fi, gi)` ascending**, emit — reproducing today's `for fi … for gi>fi …`
  emission order exactly, hence byte-identical faceOrders.

`Fold_state.t` changes `order : rel array array` → `order : Layer_order.t`, and
`rel`/`negate` move to `Layer_order` (re-exported or referenced).

## Error handling

- `validity_error` behaviour is unchanged (same messages, same conditions):
  stacking cycle (Above-cycle over overlapping faces) and tortilla-tortilla
  (overlap-but-Apart). Taco-taco / taco-tortilla remain deferred to the pocket
  slice as today.
- The sweep-and-prune is a pure broad-phase; it can never drop a real overlap
  (bboxes are conservative supersets of the exact polygons), so it cannot cause
  a missed relation or a wrong validity verdict.

## Testing

- **Golden byte-identical** (hard gate): all `tests/test_golden.ml` `.fold`
  outputs unchanged. The layer-ordering slice #21 used this exact gate.
- **`Layer_order` unit tests**: on random face-polygon sets, assert `build`
  (sweep-and-prune) produces the same relation as a reference `O(n²)`
  `convex_overlap` build for every pair; `get`/`iter`/`flip`/`above_neighbors`
  behave per contract; the absent-vs-Apart distinction holds.
- **Scaling test** (`Slow`): a distributed pleat tessellation of growing N;
  assert per-fold / total time grows sub-quadratically (doubling N stays well
  under 4× the time) — contrasting the current dense behaviour. Complements the
  committed `bench/` harness.
- Existing `test_fold_state`, `test_geom`, `test_e2e`, `test_eval` green.

## Non-goals

- No change to the fold semantics, the layer *model* (framing A: sequence
  determines order), or the validity rules. Pure representation + broad-phase
  swap.
- Not speeding up the inherently-`O(n²)` fully-overlapping-stack case.
- No taco-taco / taco-tortilla (still the pocket slice).
- No language-level loops / parametric tessellation (a separate slice; this one
  makes the *evaluation* scale so that slice's output is computable).

## Plan-level tuning points (settle in the plan, non-blocking)

- Exact container for the sparse order (hashtable vs per-face adjacency vs both).
- Whether `build` takes table polygons or the `face` array (avoid recomputing
  `table_poly_of`).
- Sweep axis (x by default; a longest-spread axis is a possible refinement, not
  required).
