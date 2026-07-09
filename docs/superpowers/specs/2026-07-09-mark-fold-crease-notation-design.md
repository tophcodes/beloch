# mark / fold — a crease is motion × disposition × extent

**Status:** Design, approved in brainstorming 2026-07-09. Supersedes the
`pinch`-as-full-chord model (`notes/2026-07-03-crease-layer-selection.md`,
decision 3) and the `@`-as-fold marker. Next step: implementation plan.

## 1. Summary

Split what today is fused into one act. Right now a bare axiom statement
(`map .a onto .b`) *materialises* a flat crease and subdivides the sheet, and
`@` promotes it to a fold. This design separates the three things a crease
actually is:

- **Motion / line description** — `map … onto …`, `through`, `perp`.
  A pure **read**: a geometric line (in the flat-foldable case), computed, never
  touching the paper. Bindable: `--l = map .a onto .b` scores nothing.
- **Disposition** — what physically happens to the paper. Two verbs:
  - **`mark`** — crease and leave flat (FOLD `F`, carrying M/V *intent* for the
    crease pattern). Does not move layers. May be **partial** → this is `pinch`.
  - **`fold`** — crease and keep folded (FOLD `M`/`V`). Moves layers.
- **Extent** — full chord (default), `between .a .b`, or `at .p` (a single
  reference point). Only `mark` is partial in this slice.

`@` is retired as a marker. `map`/`through`/`perp` become values; the writes are
the keyword verbs `mark`, `fold` (and `collapse`, `flip`). This
*completes* the read/write law (§4.10, shipped v0.20-dev): today `through` is the
one write but `map`-as-statement is also a write — an inconsistency. After this,
**all** line descriptions read; only `mark`/`fold`/`collapse` write.

## 2. Motivation

1. **Finishes §4.10.** One rule, no exceptions: descriptions read, dispositions
   write.
2. **Gives `pinch` a home that actually works.** The abandoned full-chord model
   (materialise the whole chord, draw it short) would still *materially* split
   every ray the chord crosses — the exact defect `pinch` was meant to avoid. A
   `mark` is a **non-subdividing** record, so it doesn't split rays.
3. **Unblocks the regressions.** `iteration/003`, `004` and the cluttered
   `cube-root` CP (see [[beloch-sightline-to-pinch-interim]]) all come from
   scoring point-locating scaffolds as full `through` creases, which splits the
   bisector rays. A pure-geometry binding (scores nothing) plus `mark` (scores
   only where needed) fixes both.
4. **Corrects the FOLD assignment.** Beloch emits `U` for flat precreases
   (`fold_emit.ml:68`). Per `refs/foldformat.md`, a creased-but-flat edge is
   **`F`** ("present but not folded"); `U` means *direction unknown*, which
   Beloch never is. The cutover fixes this and drops `U` from output entirely.
5. **Reads like origami.** You either **mark** (stays flat) or **fold** (stays
   folded). The verb names the residual state.

## 3. The model

A crease operation = **motion × disposition × extent × layers**.

### Motion (read)

The Huzita–Justin axioms are one problem: *find the reflection(s) whose crease
satisfies these incidence constraints.* The surface already encodes exactly that,
in words:

| motion | constraint | axiom |
|---|---|---|
| `through .a .b` | **the one non-reflection**: the line through two points | 1 |
| `map .p onto .p'` | point → point (⟂ bisector) | 2 |
| `perp --l through .p` | perpendicular through a point | 3 |
| `map .p onto --l perp --m` | point → line, crease ⟂ `--m` | 4 |
| `map --l onto --m` | line → line — the angle bisector | 5 |
| `map .p onto --l through .p'` | point → line, through a fixed point (quadratic) | 6 |
| `map .p onto --l and .q onto --m` | two point → line — cubic Beloch fold | 7 |

(Numbering per `spec/SPECIFICATION.md` §4 / `refs/justin1986.md`; the obsolete
`bisect` verb is now `map --l onto --m`.) `through` is the odd one: no motion, no
reflection — a straight description.
That's *why* it too belongs on the read side, not (as §4.10 has it now) the sole
write. Motions are values: bindable (`--l = map .a onto .b`), usable in any line
operand slot (meet `*`, filter `&`, etc.). **A motion alone touches nothing.**

### Disposition (write)

| verb + dir | foldedForm | CP frame | meaning |
|---|---|---|---|
| `mark … valley` | `F` | `V` | valley reference/memory crease |
| `mark … mountain` | `F` | `M` | mountain reference/memory crease |
| `fold … valley` | `V` | `V` | fold up, stays folded |
| `fold … mountain` | `M` | `M` | fold down, stays folded |

Default direction is **valley**. There is no directionless `F`: physically you
always crease *some* way, so an unfolded crease still carries an M/V intent — that
intent is the CP-frame colour. This is why the two FOLD frames Beloch already
emits (creasePattern = intent, foldedForm = current dihedral) are exactly the
right home: a `mark` is `F` in the folded form and `M`/`V` in the crease pattern.
(Populating the CP-frame intent from fold history is a **follow-up**, §8.)

### Extent

- **full chord** (default) — the motion's whole intersection with the target.
- **`between .a .b`** — only the segment between two exact points. `pinch`.
- **`at .p`** — a single reference point on the line (extent = the point; drawn
  as a short display tick). `pinch`.

`fold` is **not partial** in this slice (full chord only). Partial folding leaves
the paper non-flat and needs rigid/flat-foldability solving plus render-side
panel subdivision for warping — deferred (§8).

### Layers

Which layer(s) a `mark`/`fold` acts on is chosen **logically**, not by physical
ε-proximity: after halving the sheet you may want to mark the *bottom* layer even
though the reference line is drawn on top. Selection is the existing flap operand
`#[…]` (ADR 0016/0017), singleton by default; the set-valued case is deferred
(§8).

## 4. Surface syntax (sketch)

Illustrative — exact productions are for the plan. Open syntactic choices are
flagged `(open)`.

```
; motions are values — no material effect
--l  = map .a onto .b
--pb = through .a .b

; mark: crease flat (F + M/V intent), optionally partial
mark --l                         ; full chord, valley intent
mark --l mountain                ; full chord, mountain intent
mark --l between .p .q           ; partial  = pinch
mark --l at .m                   ; single reference point = pinch
mark --l #[.c]                   ; on the layer carrying .c
mark .a onto .b                  ; inline motion sugar (anonymous)

; fold: crease and keep folded (moves layers)
fold --l moving .a               ; up, stays folded; moving side
fold --l mountain moving .a
fold .a onto .b                  ; inline sugar — as terse as today's @map

; naming a materialised crease           (open: bind-and-write form)
;   either  --l = map .a onto .b ; mark --l
;   or a combined   mark --l = map .a onto .b   (TBD in plan)
```

Clauses that already exist stay: `moving`, `up to`, and (for `fold`) the whole
fold-scope machinery (§4.6). `flip` stays a bare keyword. `@collapse` loses its
`@` → **`collapse`** (keyword verb, same operands).

### Migration (conceptual)

| today (v0.20-dev) | after |
|---|---|
| `map .a onto .b` (bare precrease) | `mark .a onto .b` |
| `--d = map .a onto .b` (named precrease) | `--d = map .a onto .b` (geometry) + `mark --d` when it should score |
| `@map .a onto .b moving .p` | `fold .a onto .b moving .p` |
| `@fold --d moving .p [mountain]` | `fold --d moving .p [mountain]` |
| `@collapse …` | `collapse …` |
| emitted `U` for flat creases | emitted `F` |

This is a second notation cutover after #24, but the surface stays close: `@map`
→ `fold`, `@fold` → `fold`, bare `map` → `mark`. Corpus, embedded test sources,
`spec/SPECIFICATION.md`, and examples all migrate (the #24 method — parallel
subagents over disjoint files — worked well).

## 5. Marks: the non-subdividing record

The key data-model addition. A `mark` is **not** an entry in the face-boundary
edge set (`Fold_state.edges`); it is a separate record:

```
mark = {
  geom      : segment | point ;   ; paper-space extent
  intent    : M | V ;             ; CP-frame colour
  crease_id : int ;               ; identity, rides with the name's bundle
  layer     : face ref ;          ; which layer it sits on
}
```

Stored in a parallel `marks : mark array` on `Fold_state.t`. Properties that fall
out of *not* being a face boundary:

- **Does not subdivide** → splits no rays, is no flap boundary → **can end
  mid-face** (a dangling reference crease — exactly a physical pinch). A real
  crease (`fold`, or a full `mark`) must span boundary-to-boundary because it
  divides the face; a partial `mark` needn't.
- **`assign` is unchanged.** We do *not* add a variant to `M | V | U`; a mark is
  "F-like" (exists, not folded) only in spirit, and lives outside the partition.
- **Rides isometries** like any material on its layer (moves with folds).
- **#26 invariant intact** — every *edge* still borders faces or the paper edge;
  marks are not edges.

### FOLD emission

A mark is emittable as a raw `edges_vertices` entry with assignment `F` (and its
M/V intent goes to the crease-pattern frame), **or** omitted when it is
scaffold-only. `edges_vertices` is already a superset of face boundaries, so a
non-face-bounding edge is valid FOLD. Display decides visibility: scaffold marks
hidden by default, pinch marks shown.

### Snapping (marks only)

A controlled, mark-only incidence cleanup: when a mark endpoint lands close
enough to an existing edge/vertex *after a later crease*, it is made incident to
it. This auto-segments a flap-aligned pinch onto the "meaningfully needed" ray of
the main piece. It is the **only** deliberate inexactness, quarantined to marks —
never structural, the underlying points stay rational. Tolerance and trigger
timing are `(open)` for the plan.

## 6. Assignment & FOLD

FOLD `edges_assignment` values (`refs/foldformat.md`): `B` boundary, `M`
mountain, `V` valley, **`F` flat = present but not folded**, `U`
unassigned/unknown, `C`/`J` n/a here. `edges_foldAngle`: + valley, − mountain, 0
flat/unassigned.

Beloch after this slice emits only `B`, `M`, `V`, `F`. `U` is dropped — we always
know the disposition. Flat `mark`s are `F` in the folded form; their M/V intent
lives in the creasePattern frame.

## 7. Direction & moving inference

`--l = map .a onto .b` records *how it was constructed* — `.a` moves onto `.b`.
So `fold --l` without an explicit `moving` can **infer** the moving side from the
construction. If `--l` has since been subdivided (its construction rule no longer
determines a single side), inference is ambiguous → require `moving`, error
naming the candidates (the existing ambiguity-error culture, ADR 0016). Precise
inference rules are `(open)` for the plan.

## 8. Deferred / follow-up

- **History → CP-frame M/V.** Track per-segment fold direction so an unfolded
  crease keeps its intended colour. This slice lands the two-frame *structure*
  and the `mark` intent; auto-populating intent from fold history is a later
  slice.
- **Partial `fold`.** Needs rigid/flat-foldability solving + render-side panel
  subdivision (warping developable surfaces). Render/animation-engine territory.
- **Set-valued layer selection.** `#[.c .d]` marking several layers reopens the
  deferred segment-set value (ADR 0016 decision 2). Singleton only for now.
- **Single-point mark extent.** `at .p` display-tick length is display-only;
  exact-model extent is the point. Fine, but the tick rendering is `(open)`.
- **3D** — the next design pass (§9).

## 9. Future: 3D (captured for the next pass)

The exactness question, and its pre-answer, recorded here so the 3D pass starts
from it:

> **Q (Toph, 2026-07-09):** If we do 3D, does the picture just gain a third axis
> to compute coordinates in? Rotation is sin/cos and thus irrational — do we lose
> exactness in 3D? How do we reconcile exact 2D with inexact 3D? And: can we still
> give "arbitrary angles" in a *non-transcendental* frame as an approximation, for
> things like "continuously subdivide this flap and curl it toward one side"?

**Pre-answer sketch.**

- *Irrational ≠ inexact.* The qqbar/`Num` kernel already represents algebraic
  irrationals (√2, ∛2) exactly. The real divide is **algebraic vs.
  transcendental**, not rational vs. irrational.
- *Never store an angle.* A 3D fold is an **isometry with algebraic matrix
  entries**, exactly as a flat fold is a reflection matrix — never a "180°".
- *Incidence keeps it algebraic.* Origami is driven by landing constraints ("fold
  until .a is on .b / on a line / on a plane"), which are polynomial equations in
  the rotated coordinates. With `cos²θ + sin²θ = 1`, `cos θ`/`sin θ` are then
  **algebraic** even though the arc θ is transcendental. Algebraic reals are
  closed under composition, so any incidence-driven fold sequence stays exact —
  same kernel. **Exact 2D and exact 3D are one regime.**
- *The one break* is a free arc angle (`fold … 50 degrees`): `cos 50°` is
  transcendental → inexact, quarantined as a float display/target layer like
  display-ε.
- *Arbitrary angles without transcendence (the curl case):* approximate any angle
  by a **rational point on the unit circle** — `(cos, sin) = ((1−t²)/(1+t²),
  2t/(1+t²))` for rational `t` — giving an exact (even rational) rotation
  arbitrarily close to any target. A smooth curl = a sequence of small such
  rotations along a subdivided crease, exact-algebraic, approximating the curve as
  finely as the subdivision. This is how developable curling is discretised
  anyway. So "curl toward one side" is exact, not transcendental.
- *Honest costs* (work, not exactness loss): `Geom`/`Isometry` generalise 2D→3D
  (numbers stay algebraic); multi-vertex rigid states are coupled polynomial
  systems (algebraic but possibly high-degree — the known kernel scaling walls);
  target reachability becomes a solvability question.

When 3D starts, the algebraic-vs-transcendental line gets its own ADR.

## 10. Open questions (for the plan)

- Bind-and-write surface form (`mark --l = motion` vs two statements).
- Snapping tolerance and trigger timing.
- Single-point `at .p` tick rendering.
- Direction/`moving` inference precise rules.
- Whether marks default to emitted-and-hidden or omitted in FOLD.

## 11. References

- `spec/SPECIFICATION.md` §4.6 (`@`/`moving`/`up to`), §4.8 (`&` filter), §4.9
  (`@collapse`), §4.10 (read/write law — this design completes it).
- ADR 0014 (crease = bundle of segments), ADR 0016 (typed operands / singleton
  slots), ADR 0017 (flap = coplanar cluster).
- `refs/foldformat.md` (`edges_assignment` B/M/V/F/U, `edges_foldAngle`).
- `lib/fold_state.ml` (`type assign`, `edge`, `subdivide`), `lib/fold_emit.ml`
  (`U`→`F` at :68, dual-frame emit), `lib/parser.mly` (statement grammar,
  `AT`-marker productions to retire).
- Memory: [[beloch-crease-segment-at-pinch-design]],
  [[beloch-sightline-to-pinch-interim]], [[beloch-flatten-selector-design]].
- `notes/2026-07-03-crease-layer-selection.md` (the superseded full-chord model).
