# Beloch — Action Model & Folding Engine (Design)

- **Date:** 2026-06-29
- **Status:** Design — approved in brainstorming, pending ADR + implementation plan
- **Supersedes:** the planned "mountain/valley annotation" slice (made obsolete; see below)

## 1. Context — the pivot

Beloch shipped v0.0–v0.4 as a **crease-pattern construction language**: statements
are Huzita-Justin axioms operating on the *flat* sheet, evaluated (order-independent)
into a flat crease pattern emitted as FOLD. Exact rational/constructible geometry
(`Num`). This is the "origami as compass-and-straightedge" tradition.

The next planned slice was *mountain/valley annotation* (label each crease `M`/`V`).
Brainstorming surfaced that this was the wrong frame. Two observations drove the pivot:

1. **There is no mountain fold on a flat desk.** Physically a fold is one action —
   you valley-fold a flap toward you. "Mountain" only exists relative to a *side*
   (a valley seen from the back, or after a flip). M/V is therefore not intrinsic to
   the act of folding; it is a property of *which face you look at*.
2. **The original intent of Beloch was to describe the exact actions you perform on
   real paper** — including folding *through all layers* of an already-folded stack.
   That is a fundamentally different (and more powerful) model than CP construction.

So Beloch pivots to an **action model**: a `.bel` program is an *imperative sequence
of folding actions* on a stateful sheet. The flat crease pattern and mountain/valley
become **derived outputs**, not the source of truth. The axiom/`Num` work is not
discarded — the axioms remain the "where does the crease go" primitive, now applied to
the current paper state.

### Why this is worth doing (landscape check, 2026-06-29)

A quick web survey of the prior art:

- **Embedded Languages for Origami-Based Geometry** (Haskell eDSL, 7 axioms,
  constraint analysis, *basic* folding animation) — overlaps Beloch's *axiom* layer
  only; construction-flavored, not an action/layer/folded-state model. The pure-axiom
  niche is occupied; the axioms alone are **not** novel.
- **Kleinlaut** ("3D origami programming language") — **does not exist**. It appears on
  exactly one AI-generated SEO content-farm page with no repo, syntax, or second source.
  The only real "Kleinlaut" is a German wooden-origami shop.
- **OrigamiDL** (`origami.muehl.dev`) — the author's own earlier, unfinished take.
  Beloch is its successor.
- **Origami Shape Language (OSL)**, MIT Amorphous Computing — origami as a *metaphor*
  for programmable self-assembly, not a paper-folding tool.

The **combination** that is unoccupied, as far as this check shows:

> textual **action sequence** + **exact** constructible arithmetic *through the fold* +
> **action-derived layer ordering** (validity by construction) + **dual exact output**
> (FOLD `creasePattern` *and* `foldedForm`).

The **exactness through folding** is the sharpest, most defensible edge: Origami
Simulator and Rabbit Ear are floating-point/physics; exact folded coordinates (provable
references, no drift across many steps) are rare.

(Landscape check is quick, not exhaustive. The maneuver→primitive decomposition and any
thick-panel claims are *not* grounded in `refs/` — drop sources in before formalizing.)

## 2. Locked decisions

| Topic | Decision |
|---|---|
| Model | Action model (imperative folding) — CP construction becomes the precrease sub-layer |
| Exactness | Exact 3D for constructible/geometric targets; **arbitrary numeric & animated angles** via **constructible-rational approximation** (stays in `Num`, drift-free; float is *never* used for representation, only — optionally — inside the rendering client) |
| Thickness | Zero-thickness model; thickness is a display-only ε layer offset; engineering/rigid-panel origami **out of scope** |
| Runtime state | Faces (flat-coordinate polygons) + per-face exact isometry into 3D + an **addressable, insert-anywhere layer stack** |
| Mountain/valley | **Derived** from the action (rotation direction) + accumulated flips — never annotated |
| Fold ladder | Stufe 1 simple fold → Stufe 2 layer selection / landing / validity check → Stufe 3 unfold → named maneuvers as sugar |
| Syntax | `axiom` = precrease (flat line); `@axiom` = also fold. Verb set `through` · `perp` · `map … onto …` (superposition axioms 2 & 5 unified, type-dispatched — renames `fold`/`bisect`). `moving .p` clause (defaulted for point-moving axioms), `mountain` keyword (default valley) |
| References | **Material-persistent** points; flap = "the flap containing `.p`"; `cross` generalized to line × line (crease *or* paper edge) |
| Output | Dual FOLD: `creasePattern` frame + `foldedForm` frame |
| Program structure | Imperative — statements evaluated in order, state threads through (bare precreases commute until the first fold) |

## 3. Architecture

### 3.1 Runtime state (the folded state)

The paper between actions is the standard FOLD `foldedForm`:

- **Faces** — polygons in flat (unfolded) paper coordinates. Construction stays
  *intrinsic*: creases are always expressed in flat coordinates.
- **Per-face isometry** — a rigid map placing each face into 3D, built as a composition
  of reflections (flat folds) / rotations. For flat folds these are reflections, so
  coordinates stay in the constructible field (`Num`).
- **Layer ordering** — an addressable, ordered stack supporting insert-at-position.
  Stufe-1 *behavior* is simple ("the moved flap lands on top"), but the *representation*
  must already allow inserting layers at arbitrary positions, because reverse/petal/sink
  (Stufe 2/3) tuck layers *between* existing ones. This is the FOLD `faceOrders` model.

Why zero-thickness: with zero thickness, stacked faces share a plane and would
interpenetrate — `faceOrders` exists precisely to say which is on top. This is the
standard origami-math / FOLD idealization (`refs/foldformat.md`; ground exact loci in
`demaine2007` / `hull2020` when writing the ADR).

### 3.2 Exactness and the fold angle

The fold angle of a crease is a **first-class `Num` value per crease**. It arises two ways:

- **Target-derived** — "fold flat" (±180°), "fold edge onto edge", "fold to reference X".
  The angle falls out of the geometry and is **exact-constructible by construction**.
  A flat fold is a reflection; the rest position stays exact in `Num`. Other constructible
  angles (±90°, ±60°, ±120°, ±45°, …) are exact too because their `sin`/`cos` are
  constructible.
- **Given / parameterized** — an explicit angle, possibly a *named, animatable parameter*
  (e.g. a crane's wings at an arbitrary display angle, or a wing-flap animation that drives
  the dihedral back and forth). Arbitrary real angles are generally **not** constructible
  (`cos 50°` is not), so they are snapped to a **constructible-rational approximation**.

The constructible reals are dense in ℝ, so any angle is approximable to any tolerance.
Crucially, snapping to a *constructible* (not float) value keeps the whole downstream
geometry in the `Num` tower and **composes drift-free** across many folds — exact rationals
do not accumulate floating-point error the way a float chain would. The exact core therefore
**never falls back to float for representation**; float, if used at all, lives only inside
the rendering client's frame interpolation.

**Slice 1 is flat-only** (±180°). Given/parameterized non-flat angles are an architecture
goal reserved here and a near follow-slice — the isometry-based state already carries them.

### 3.3 Reference model (material-persistent)

A point name denotes a **material point of the paper** that persists through folds.
`.a` is always the same material point; after folding it is located at its image under
the accumulated isometry. Folding *moves* names, never invalidates them. New points
(crease endpoints, intersections) are named at construction time, exactly like `cross`
today. Flaps/faces are referenced by a containing point ("the flap with `.a`") — the same
reference kind `moving .a` needs.

Spatial/visible references ("the top-right corner now", "the topmost layer") are
explicitly **not** the foundation: they are ambiguous (coincident stacked points),
brittle, and break exactness. They may be an optional convenience layer much later.

To name crease/edge intersections, `cross` generalizes from crease×crease to **line ×
line**, where a line is a crease *or* a paper edge (including folded boundary edges).

### 3.4 Validity

Stufe 1 is **valid by construction**: folding all layers on one side of a line is always
physically realizable, and layer order is determined by the action sequence — no
NP-hard flat-foldability / layer-ordering search. The fold pipeline reserves a
**pluggable validity-check slot** (self-intersection / reachability) that Stufe 2 fills
once arbitrary layer selection + insertion can express impossible moves.

## 4. Syntax

### 4.1 Precrease vs. fold

A bare axiom statement is a **precrease**: it computes a crease *line*, marks it, the
paper stays flat. (Behavior is v0.0–v0.4's; the *verbs* change — see 4.2.)

A `@`-prefixed statement also **folds**:

```
--m: map --l1 onto --l2 toward .p      # precrease only: line, paper stays flat (axiom 5)
@map .a onto .b                        # fold: valley, flap containing .a rotates over (axiom 2)
@map .a onto .b moving .a mountain     # explicit moving side + direction
@map --l1 onto --l2 toward .p moving .a # line-onto-line fold: moving side required
```

- **`@` prefix** marks "and keep folded." Chosen as a sigil (consistent with Beloch's
  `.`/`--` sigils; continuity with OrigamiDL). The one risk — a quiet one-character
  carrying the biggest semantic jump in the language (flat line vs. folded 3D state) —
  is mitigated by keeping it a *line-front prefix* (highly visible) and by linter/renderer
  rendering folded vs. flat statements distinctly.
- **`moving .p`** selects the moving flap (the flap containing material point `.p`).
  Defaulted for point-moving axioms (`@fold .a to .c` → flap with `.a`); **required** for
  line-construction axioms (`through` / `perp` / `bisect`) which have no natural default.
- **`mountain`** sets rotation direction; default is **valley** (toward viewer).

### 4.2 Verb set (renamed) — `map … onto …`

Because a bare statement is a *precrease* (it does not fold), the verb must name the
**geometric operation**, not the physical act. `fold` (axiom 2) is therefore renamed:
the superposition axioms — a reflection placing one object **onto** another — unify under
one verb, dispatched by operand type:

- `map .a onto .b` — point onto point → **axiom 2** (perpendicular bisector). Unique.
- `map --l1 onto --l2 toward .p` — line onto line → **axiom 5** (angle bisector). `toward`
  picks the sector (two solutions).

This mirrors the spec's own wording ("fold one point/line **onto** another", §4.2/§4.5) and
**generalizes forward**: future point-onto-line folds become `map .p onto --l through .q`
etc. — one `map` family instead of a per-axiom verb zoo. Axiom *numbers* move to reference
docs; the surface is intent-driven. (Exact numbering of the point-onto-line axioms: see the
6/7 numbering watch-point in `antipatterns.md`.)

The non-superposition axioms keep their own verbs — they are not "X onto Y": `through .a .b`
(axiom 1, incidence) and `perp --l through .p` (axiom 3, perpendicular). Verb set is thus
`through` · `perp` · `map … onto …`.

**Breaking change:** renames `fold`→`map …onto…` and `bisect`→`map …onto…`. Acceptable
under the pivot's version bump; existing examples/tests are migrated in the slice.

## 5. Output — FOLD as intermediate format

FOLD is the intermediate artifact; both representations live in **one file** via FOLD's
multi-frame mechanism (`refs/foldformat.md`):

- **Frame 0 (key frame) = `creasePattern`** — the flat CP, as today (`vertices_coords`,
  `edges_vertices`, `edges_assignment`, `faces_vertices`, `beloch:edges`). Chosen as the
  key frame because multi-frame support is *optional* in FOLD — a dumb consumer that
  ignores `file_frames` then still sees a sensible flat pattern.
- **`foldedForm` frame** (in `file_frames`) — 3D `vertices_coords`, `faceOrders`, and
  `edges_foldAngle` (sign matches derived `edges_assignment` M/V). Uses `frame_parent` +
  `frame_inherit` to inherit topology from the CP frame and override only coordinates —
  one combinatorial complex, two geometries.

`edges_assignment` M/V is **computed** from each fold's rotation direction and the face's
accumulated orientation parity (front/back), not annotated.

The action-model semantics that generic FOLD tools don't understand ride in a **`beloch:`
custom namespace** (as `beloch:edges` already does): material-point identity, fold-action
provenance, moving flap, step grouping, and the (possibly parameterized) fold-angle target.
Generic tools ignore these; Beloch's own client reads them.

### 5.1 Rendering & animation — own client engine

Two-tier consumer story (this is the existing architecture: ADR 0001 core/edge, ADR 0002
FOLD-extended output, ADR 0009 Rabbit Ear):

- **Generic FOLD tools** (Origami Simulator, Rabbit Ear) consume the standard fields — used
  only as a free **correctness check / fallback viewer**, *not* the product renderer.
- **Beloch's own rendering/animation engine** (the TS/web edge, to be built later) is the
  product renderer: **style-controllable**, consuming FOLD + `beloch:` metadata, targeting
  tutorials, blog, and store ("look what you can fold") with an automatically generated fold
  sequence and animation in a chosen visual style.

Motion has two regimes, both handled by the *own* engine, both display-only / approximate:

- **Rigid-rotation motion** — a simple fold's flap, or a parameterized angle sweep (e.g. a
  crane flapping its wings), is a rigid rotation about the crease; exact (or constructible)
  per frame, easy. This covers Slice 1 and parameterized-angle animation.
- **Deforming (cloth-like) motion** — pocket maneuvers (reverse/squash/sink/petal) are
  generally *not* rigidly foldable mid-motion: the paper must transiently bend, and tucking
  into a pocket is a self-collision / layer-reorder event. Animating these needs face
  **tessellation + relaxation** (mass-spring / constraint), the hard part of the future
  engine. Rest states stay rigid and exact regardless. (Rigid-foldability: `demaine2007`;
  the relaxation mechanic mirrors Origami Simulator / Ghassaei 2018, **not** in `refs/` —
  add before formalizing the animation layer.)

Animation is **never baked as float keyframes into the exact artifact**: emit exact CP +
exact rest `foldedForm` + `beloch:` action metadata (order, flap, angle target); the engine
interpolates.

## 6. Slice 1 — scope

**In:**
- Imperative evaluation; state threads through statements.
- Precrease axioms (semantics reused; verbs renamed to `map … onto …`, now order-sensitive
  once paper is folded; existing examples/tests migrated).
- `@` fold modifier — **simple flat fold** (±180°): all layers on the moving side, valley
  default / `mountain`; `moving .p` with point-axiom default.
- Folded-state runtime: faces + exact reflection isometries + addressable layer stack
  (Stufe-1 landing = on top).
- Material-persistent references; flap-by-containing-point.
- `cross` generalized to line × line (incl. paper edges) — enough to name new points.
- Dual FOLD output (`creasePattern` + `foldedForm`), derived M/V.

**Out (deferred; architectural hooks reserved):**
- Layer selection / insert-between / validity check (Stufe 2).
- `unfold` (Stufe 3).
- Named maneuvers — reverse / squash / sink / petal — as sugar (Stufe 3+).
- Non-flat angles — both target-derived ("fold until edge meets…") and given/parameterized
  (arbitrary, constructible-rational-approximated; animatable, e.g. wing-flap) — near
  follow-slice; isometry state already carries them.
- `flip` / `rotate` whole-sheet isometries — fast follow.
- The **own rendering/animation engine** (TS/web edge): style-controllable tutorial/blog/
  store output, rigid-rotation then later deforming (cloth-like) motion. A separate
  build; the OCaml core only emits FOLD + `beloch:` metadata for it to consume.

**Success criteria:**
- A `.bel` program that precreases and then `@`-folds produces a FOLD file whose
  `foldedForm` frame folds correctly in Origami Simulator / Rabbit Ear.
- Folded coordinates are exact (constructible) at rest.
- Derived `edges_assignment` matches the fold directions performed.
- All v0.0–v0.4 programs still evaluate identically (precrease backward compatibility).

## 7. Explicitly out of scope

- **Engineering / rigid-panel thickness** (hinge offset, panel collision, modified
  kinematics) — a different problem class and arguably a different product. Display-ε only.
- **Spatial/visible reference model** as a foundation.
- **Self-intersection during motion** beyond the Stufe-2 static validity check.

## 8. Follow-ups before implementation

- Write an **ADR** recording the pivot (this design is its input); update
  `spec/SPECIFICATION.md` as part of the implementation slice.
- When formalizing Stufe 2/3, add `refs/` sources for maneuver mechanics and (if ever
  pursued) thick-panel origami, per project citation discipline.
- Confirm exact FOLD loci (`demaine2007` / `hull2020`) for the zero-thickness +
  layer-ordering rationale in the ADR.
