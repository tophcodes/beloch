# mark / fold — Slice 2 design (partial marks / the pinch)

**Status:** Design, approved in brainstorming 2026-07-10. Resolves the open
questions (§10) of the parent design
[`2026-07-09-mark-fold-crease-notation-design.md`] for the Slice 2 scope. Next
step: implementation plan (`writing-plans`). Branch: `slice/mark-fold-2-pinch`
off `main`.

Parent design and Slice 1 context:
`docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md` and
`docs/superpowers/plans/2026-07-09-mark-fold-slice2-handoff.md`. Memory:
`[[beloch-mark-fold-notation-design]]`, `[[beloch-sightline-to-pinch-interim]]`,
`[[beloch-crease-segment-at-pinch-design]]`.

## 1. What Slice 2 delivers

The **non-subdividing partial mark** — the pinch / reference crease that does
*not* re-segment everything it crosses. Slice 1 shipped the surface + `U`→`F`
cutover but kept `mark` subdividing exactly like the old precrease. Slice 2 makes
a mark that ends **mid-face** a real, non-subdividing record — the fix the whole
redesign was for.

Core deliverables (all in scope):

- Partial-mark data model (`marks : mark array` on `Fold_state.t`).
- Extent syntax `mark --l between .a .b` (segment) and `mark --l at .p` (point).
- Exact-incidence snapping only (fuzzy/tolerance snapping **deferred**).
- `mark … valley/mountain` direction → CP-frame M/V intent (foldedForm stays `F`).
- Layer selection `#[…]` (singleton), with a defined default flap.
- Combined bind-and-write `mark --l = <motion>`.
- `beloch:marks` FOLD custom field + `fold2svg` rendering.

Deferred (out of Slice 2): fuzzy/tolerance snapping · `fold` moving-side
inference (parent §7) · set-valued `#[.c .d]` · partial `fold` · history→CP
intent. See §7.

## 2. Resolved open questions

The five open questions (parent §10) and the two surface opens, as decided in the
2026-07-10 brainstorm:

1. **Does a *full* `mark` subdivide or become a record?** — **Full marks
   subdivide** (Slice 1 behaviour kept, behaviour-preserving, matches parent §5:
   "a real crease… divides the face"). Only genuinely **mid-face (dangling)**
   extents become records. The discriminator is *boundary-incidence, not syntax*
   (§4).
2. **Snapping tolerance & trigger timing** — **Exact-incidence only.** A mark
   endpoint is made incident to an existing vertex **only** on exact rational
   equality, re-checked lazily. No tolerance, no float, zero deliberate
   inexactness. Fuzzy/tolerance snapping is deferred until a concrete example
   needs it.
3. **`at .p` single-point extent & rendering** — Model stores the **exact point**
   plus the **line** it sits on (for orientation). It emits into the `beloch:`
   FOLD namespace, **not** the standard `edges_*` arrays. `fold2svg` draws a short
   tick centred on `.p`, oriented along `line`, fixed display length.
4. **Marks emit default** — **Split by boundary-incidence** (§4/§5): a mark that
   subdivides a face emits as a standard `F` edge; a dangling/point mark emits
   into the `beloch:marks` custom field. Never a fake display-length segment in
   the standard CP.
5. **Set-valued layer selection** — **Deferred.** `#[…]` is singleton. Default
   flap when omitted = the **carrying flap** of the operand geometry; ambiguous
   (aligned stacked layers) → error naming candidates.

Surface opens:

- **Bind-and-write form** — **include** the combined `mark --l = <motion>`
  (binds the name and marks in one statement); the two-statement form still works.
- **`fold` moving-side inference** (parent §7) — **deferred** to a fold-focused
  slice; orthogonal to marks.

## 3. Data model

New `marks : mark array` on `Fold_state.t`, **beside** `edges`:

```
mark = {
  geom      : Seg of point * point | Point of point ;  ; exact paper-space extent
  line      : Geom.line ;                              ; orientation (the motion's line)
  intent    : M | V ;                                  ; CP-frame colour
  crease_id : int ;                                    ; identity, rides with the name's bundle
  layer     : face ref ;                               ; which flap it sits on
}
```

Properties (parent §5), enforced by construction:

- **Not a face-boundary edge.** Marks do **not** participate in `subdivide`, the
  coplanar-cluster / flap graph (`fold_state.ml` ~:382, ADR 0017), ray-splitting,
  or `Layer_order`. So a mark **splits no rays, is no flap boundary, and can end
  mid-face** — exactly a physical dangling pinch.
- **Rides isometries** with its `layer` like any material (moves with folds).
- **`assign` unchanged** — no new variant on `M | V | F`; a mark lives outside the
  edge partition. It is "F-like" only in spirit.
- **#26 invariant intact** — every *edge* still borders faces or the paper edge;
  marks are not edges.

## 4. Eval — the `mark` arm (boundary-incidence driven)

The `mark` arm decides subdivide-vs-record **per the extent's geometry against
the current flap arrangement**, not from the surface keyword. `mark --l between
.a .b` where `.a` and `.b` both lie on face boundaries is *identical* to
`mark --l` clipped to `[a,b]` — it renders `F` edges. The record model kicks in
only for dangling ends.

**Algorithm:**

1. **Resolve extent** from the motion `line`:
   - full chord (default) — the line's whole intersection with the target;
   - `between .a .b` — clip `line` to the segment `[a, b]` (`≡ --l & .a & .b`);
   - `at .p` — the single point `.p` on `line`.
2. **Resolve flap:** `#[…]` selection if present, else the **carrying flap** =
   the flap holding the operand geometry (the material of the points/line the
   extent is built from). If that geometry is material on several stacked layers
   (aligned corner), it is **ambiguous → error** naming the candidate flaps,
   requiring `#[…]`.
3. **Walk the extent through that flap's arrangement.** A flap is a coplanar
   cluster: **its internal edges are all `F`; every `M`/`V` edge is a flap
   boundary.** Therefore:
   - Extent crosses only `F` edges, spanning **boundary-to-boundary** → **call
     the existing `subdivide`** (emits `F` edges, splits the flap's faces). Full
     chord and both-endpoints-on-boundary `between` take this exact path.
   - Extent **ends mid-face** (an endpoint is interior to a face) → the boundary
     portion still subdivides (**split at the last `F`-crossing**); the remaining
     **dangling stub** (last crossing → interior endpoint) becomes a
     `beloch:marks` **record** (no subdivide).
   - `at .p` with `.p` mid-face, or a `between` wholly interior to one face →
     **pure record**, no subdivide.
   - Extent would cross an `M`/`V` edge (i.e. leave the flap) → **error**:
     `extent of <mark> crosses folded crease <e> (it leaves its flap)`. In a valid
     mark, `M`/`V` never appears mid-extent.
4. **Exact-incidence snapping.** When a record endpoint is **rationally equal** to
   an existing vertex, reuse that vertex (incidence, not perturbation). No
   tolerance, no fuzzy match. This is the only snapping in Slice 2.
5. **Direction / intent.** Default **valley**; `mark … mountain` sets `intent =
   M`. A mark is always `F` in the foldedForm frame; its `intent` populates the
   creasePattern frame (subdividing marks colour their `F` edge in the CP frame;
   record marks carry `intent` in `beloch:marks`).

Extension points from Slice 1: the `mark`/`fold` eval arms and `resolve_markable`
(`` `Fresh ``/`` `Existing ``); `BindLine`/`Frozen` + `promote_crease` already
model "value line → materialise later" and host the combined bind-and-write form.

## 5. FOLD emission & rendering

`fold_emit` already emits dual frames (creasePattern intent + foldedForm dihedral)
and several `beloch:` custom fields (`beloch:edges`, `beloch:named_lines`,
`beloch:faces_matrix`, …). Custom `namespace:key` fields are sanctioned by the
FOLD spec (`refs/foldformat.md` §Custom Properties) and are the established Beloch
pattern.

- **Subdividing marks** → standard `F` in `edges_assignment` (they already flow
  through `edges`); M/V intent to the creasePattern frame. External FOLD tools see
  a clean, exact crease pattern.
- **Record marks** (dangling segments + points) → new **`beloch:marks`** field: a
  list of `{ kind: "seg"|"point", coords, line, intent, crease_id, layer }`. Exact
  rational coordinates; never a fake display-length segment in the standard arrays.

`fold2svg` reads `beloch:marks`:

- `seg` → a thin reference line between its two exact endpoints.
- `point` → a short **tick** centred on the point, oriented along `line`, with a
  fixed display length (display-only; the material extent is the exact point).

Scaffold-vs-shown visibility is a display concern (design leans "emit, display can
hide scaffold marks"); Slice 2 emits all record marks, and `fold2svg` shows them.

## 6. Surface syntax

```
; mark: crease flat, extent-aware
mark --l                         ; full chord, valley intent  (subdivides)
mark --l mountain                ; full chord, mountain intent
mark --l between .a .b           ; segment; F edges if boundary-to-boundary, else record
mark --l at .p                   ; single reference point = record + display tick
mark --l #[.c]                   ; on the flap carrying .c
mark .a onto .b                  ; inline motion sugar (from Slice 1)

; combined bind-and-write (new in Slice 2)
mark --l = map .a onto .b [between .a .b | at .p] [mountain|valley] [#[.c]]

; two-statement form still works
--l = map .a onto .b
mark --l between .a .b
```

`fold` is unchanged in Slice 2 (full chord only; `moving`/`up to`/scope
machinery as today). `moving`-side inference stays deferred.

## 7. Verification / acceptance targets

The payoff Slice 1 did **not** deliver — partial marks are the fix:

- `examples/iteration/003` and `004`: currently **error** (`no common interior
  vertex`) because corner→apex reference creases scored as full `through` creases
  split the bisector rays. Rewrite those landmarks as **partial marks** (mid-face
  records that don't cross/segment the bisectors) → `collapse` selects the right
  segments again → these examples pass. **This is the primary acceptance test.**
- `examples/syntax/cube-root.bel`: keeps its Messer-exact landing; its CP loses
  the interim full-chord scaffolding — landmarks become short reference marks →
  clean CP.
- Rewrite the interim-`through` scaffolds listed in
  `[[beloch-sightline-to-pinch-interim]]` to partial marks.
- Golden/snapshot updates for the migrated examples; new golden coverage for a
  dangling `at .p` mark and a `between` mark that (a) spans a face and (b) ends
  mid-face.

## 8. Deferred / follow-up (unchanged from parent §8, plus this slice's)

- **Fuzzy/tolerance snapping** — the "close enough after a later crease" incidence
  cleanup. Slice 2 does exact-incidence only.
- **`fold` moving-side inference** (parent §7).
- **Set-valued layer selection** `#[.c .d]` — reopens the deferred segment-set
  value (ADR 0016). Singleton only.
- **Partial `fold`** — needs rigid/flat-foldability solving + render-side panel
  subdivision.
- **History → CP-frame M/V** — auto-populating an unfolded crease's intended
  colour from fold history.

## 9. References

- Parent: `docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`
  (§4 extent, §5 marks-as-records, §8 deferred, §10 open questions).
- Handoff: `docs/superpowers/plans/2026-07-09-mark-fold-slice2-handoff.md`.
- ADR 0014 (crease = bundle of segments), ADR 0016 (typed operands / singleton
  slots), ADR 0017 (flap = coplanar cluster).
- `refs/foldformat.md` (§Custom Properties; `edges_assignment` B/M/V/F/U).
- `lib/fold_state.ml` (`type assign`, `edge`, `subdivide`), `lib/eval.ml`
  (`mark`/`fold` arms, `resolve_markable`, `BindLine`/`Frozen`,
  `promote_crease`), `lib/fold_emit.ml` (dual-frame + `beloch:` custom fields),
  `tools/fold2svg.mjs`.
- Memory: `[[beloch-mark-fold-notation-design]]`,
  `[[beloch-sightline-to-pinch-interim]]`,
  `[[beloch-crease-segment-at-pinch-design]]`, `[[beloch-flatten-selector-design]]`.
