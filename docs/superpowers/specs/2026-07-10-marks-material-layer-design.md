# Marks as a material non-subdividing layer — design (#26)

**Status:** Design, approved in brainstorming 2026-07-10. Resolves
[#26](https://github.com/tophcodes/beloch/issues/26) ("Marks cannot locate
interior points"). Supersedes the Slice 2 rule that *full* marks subdivide.
Next step: implementation plan (`writing-plans`). Branch:
`slice/marks-material-layer` off `main`.

Context: parent design
`docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`, Slice 2
design `docs/superpowers/specs/2026-07-10-mark-fold-slice2-design.md`. Memory:
`[[beloch-mark-fold-notation-design]]`, `[[meet-requires-material]]`,
`[[beloch-crease-segment-at-pinch-design]]`.

## 1. The problem (from #26)

Slice 2 shipped **non-subdividing record marks** so `@collapse`'s bisector-ray
logic would not be corrupted by reference creases splitting its rays. But that
made marks useless for their actual job — locating a landmark point you then
fold to. #26 lists three failures; they collapse to **one root cause**:

> A `mark` used as a meet operand must be *material* (crossable by `*`) but must
> **not** subdivide the real fold arrangement (must not split `@collapse`'s rays
> or clutter the working face partition).

Grounding the three failures:

- **Failure 1 — value line can't meet.** `--ac = through .a .c` (unmarked) has no
  material to cross. This is **correct by design** under the material-crossing
  model (`[[meet-requires-material]]`): the fix is "use `mark`", not "make value
  lines meetable".
- **Failure 2 — the `mark` workaround meets but subdivides.** `mark --ac …` today
  becomes a *real subdividing crease* (full chord → `F` edge), so two diagonals
  cost 4 faces / 8 edges and split every ray they cross. **This is the real
  defect.**
- **Failure 3 — record marks unreachable.** A consequence of there being no
  mid-face point constructor; dissolves once mark×mark meets yield chainable
  points (§3).

## 2. Approaches considered

- **A — Tagged subdividing edges (#26 as written).** Marks enter `st.edges` with
  a `mark` tag; they subdivide real faces; ~15 fold-time sites must filter the
  tag; emit keeps them. *Rejected:* the original ray-splitting defect **recurs**
  if any one filter is missed; face inflation everywhere; fragile.
- **B — Marks as a separate material layer (chosen).** Marks stay in
  `Fold_state.marks`, never enter `st.edges`, never partition real faces →
  fold-time algorithms are structurally untouched (zero filters). `*` reads mark
  chords. Emit computes the planar overlay of `real ∪ marks` and classifies each
  mark sub-segment. *The ray-splitting defect cannot recur — marks are absent
  from fold-time, not filtered-out-if-remembered.*
- **C — Promote-on-use hybrid.** Marks promote to subdividing edges only when a
  `*` references them. *Rejected:* state-dependent, spooky.

**Chosen: B.** Smallest change to the risky part (fold-time changes nothing);
all new complexity is one isolated, testable emit-time step; matches the
established material-crossing semantics.

## 3. Design

### 3.1 Data model

Marks stay the home of `Fold_state.marks : mark array`. A mark segment is now
**material** — crossable by `*`. Fold-time **never** promotes a full `MSeg` into
`st.edges`. The full-vs-dangling *subdivision* branch in `classify_mark_extent`
is removed: no mark subdivides the working arrangement. The **"leaves its flap"
cross-fold check stays** — a straight reference mark still may not span a crease
that folds (it would tear).

`mark_geom` is unchanged (`MSeg of point * point | MPoint of point`); marks
remain fold-invariant paper-space geometry carried through subdivide/fold/flip.

### 3.2 Binding

A `mark --ac = through .a .c` no longer resolves to `Material(cid, …)`. New
`crease_val` variant:

```
Mark of int * Geom.line   (* mark_id, birth line *)
```

- `materialize_crease` returns its `line`.
- `paper_line_of_crease` returns `(line, Some chords)`, sourcing `chords` from
  the mark's segments in `Fold_state.marks` (mirrors the `Material` branch but
  reads the mark layer, not `crease_segments`).

This is the **only** wiring `*` needs; the downstream meet code is unchanged.

### 3.3 Meet

`.ctr = --ac * --bd` with both operands `Mark` → intersect the two lines →
point, chainable as any value (feeds further scaffolds, §3 of #26 "chain of
scaffolds"). `Frozen` (unmarked value line) still errors *"--x is not a physical
crease, so it has no material mark to cross"* — unchanged, by design.

### 3.4 `fold` on a mark

`fold --ac` where `--ac` is a `Mark` reads its line and materializes a **fresh
real crease** via the normal fold path (real subdivision happens then). The mark
was never a crease; the fold makes one. Mark = construction intent; fold = the
real crease.

### 3.5 Fold-time algorithms — zero filters

`collapse` (bisector rays, ray split, validity/taco checks), `coplanar_clusters`
(flap graph), `layer_order`, the on-axis F→M/V upgrade, `edge_between`, and every
`crease_segments`/selection helper iterate `st.edges` = **real creases only**.
Marks are structurally invisible to them → the reference-creases-split-bisector-
rays defect **cannot recur**. No `mark`-tag needs threading through any
fold-time algorithm.

### 3.6 Emit — the one new step

In `fold_emit`, a new isolated step:

1. Compute the planar arrangement of `real_edges ∪ mark_segments` against the
   **final** fold arrangement — split both real edges and mark segments at their
   mutual crossings, so a mark×mark crossing (e.g. `.ctr`) and a mark×real
   crossing become shared vertices.
2. **Classify each mark sub-segment by endpoint incidence:**
   - **both endpoints material** (a corner, a boundary edge, or a real
     crease/vertex) → emit as a standard **`F`** crease in `edges_*` (CP-frame
     intent from `mintent`);
   - **any endpoint dangling** (mid-face) → emit into **`beloch:marks`** (extent
     kind + `mintent` colour + point-tick spec for `MPoint`).
3. **Coincidence:** where a mark segment coincides with a real crease, the real
   crease **supersedes** — the mark is dropped as redundant (its intent is
   carried by the real crease).

Classification is **emit-only**, re-derived against the final arrangement — it
never mutates fold-time state (per the "graduation timing = at emit only"
decision). Full diagonals therefore appear as `F` creases in the CP (both
endpoints are corners), so the construction that located `.ctr` is visible and
the vertex is explained.

`fold2svg` renders marks from `beloch:marks` as today (Slice 2, `001780a`);
"clean CP" is a **render concern** — a mode that hides `beloch`-tagged geometry
for a finished-model pattern. Core always preserves both channels.

### 3.7 Point marks (`at .p`, `MPoint`)

A point mark stays a tick in `beloch:marks`; it is **not** a meetable line (a
point has nothing to cross). It is now reachable in `.bel` because mark×mark
meets yield the chainable mid-face points that were previously unconstructible.

## 4. Worked example — centre of a square

```
paper square
mark --ac = through .a .c      ; material, non-subdividing
mark --bd = through .b .d
.ctr = --ac * --bd             ; locate the centre
```

- Fold-time: `st.edges` still holds only the 4 boundary edges; **1 face**. No ray
  splitting, `@collapse` unaffected.
- `.ctr`: intersection of the two mark lines, a chainable point value.
- Emit: overlay `{4 boundary edges} ∪ {--ac, --bd}` → split the two diagonals at
  `.ctr` → 4 diagonal sub-segments, each corner→`.ctr`, **both endpoints
  material** → 4 `F` creases meeting at the vertex `.ctr`. The CP explains
  itself; no orphan vertex.

Contrast Slice 2 today: 4 faces / 8 edges at fold-time, diagonals split every
crossing ray. Under B: 1 face at fold-time, the same visible CP at emit.

## 5. Scope

**In scope**

- `Mark(mark_id, line)` `crease_val` + `paper_line_of_crease`/`materialize_crease`
  wiring so `*` reads the mark layer.
- Remove the full-mark subdivision path (`dispatch_partial` always records; drop
  the `subdivide` branch for full marks); keep the "leaves its flap" check.
- `fold` on a `Mark` → real crease at fold-time.
- Emit-time planar overlay + boundary-incidence classifier +
  coincidence-supersede in `fold_emit`.
- Update goldens: full-mark examples (e.g. centre-finding) now 1 face at
  fold-time, same CP at emit; cube-root / diagonal scaffolds.

**Out of scope / deferred**

- Fuzzy/tolerance snapping (exact-incidence only, per Slice 2).
- `fold` moving-side inference (parent §7).
- Set-valued layer selection `#[…]`.
- "Clean CP" render mode toggle in `fold2svg` (design notes it as a render
  concern; not this slice unless trivial).
- Incremental (fold-time) mark graduation — explicitly rejected in favour of
  emit-only.

## 6. Risks

- **Emit-time planar overlay is new geometry.** Isolated to `fold_emit` and
  fully testable against goldens; no fold-time blast radius. This is the whole
  risk surface — deliberately concentrated here rather than smeared across ~15
  fold-time sites (the reason B beats A).
- **Coincident mark/real dedup** needs exact-rational coincidence detection
  (consistent with the exact-incidence discipline; no tolerance).
- **`beloch:marks` shape changes** as some marks now graduate to standard `F`;
  `fold2svg` reads the reduced set — verify render parity on dangling marks.
