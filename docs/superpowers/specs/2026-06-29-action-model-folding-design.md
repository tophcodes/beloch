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
| Exactness | Exact 3D, **constructible targets**; `Num` carries the folded geometry |
| Thickness | Zero-thickness model; thickness is a display-only ε layer offset; engineering/rigid-panel origami **out of scope** |
| Runtime state | Faces (flat-coordinate polygons) + per-face exact isometry into 3D + an **addressable, insert-anywhere layer stack** |
| Mountain/valley | **Derived** from the action (rotation direction) + accumulated flips — never annotated |
| Fold ladder | Stufe 1 simple fold → Stufe 2 layer selection / landing / validity check → Stufe 3 unfold → named maneuvers as sugar |
| Syntax | `axiom` = precrease (flat line, today's behavior); `@axiom` = also fold. `moving .p` clause (defaulted for point-moving axioms), `mountain` keyword (default valley) |
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

### 3.2 Exactness

A flat fold (±180°) is a reflection; the rest position stays exact in `Num`. Constructible
3D angles (±90°, ±60°, ±120°, ±45°, …) are also exact because their `sin`/`cos` are
constructible — so "exact 3D" is reachable (Stufe 1.x+), but **Slice 1 is flat-only**.
Animation between rest states needs arbitrary-angle trig → floating point, **display only**.

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
paper stays flat. This is exactly v0.0–v0.4 behavior — fully backward compatible.

A `@`-prefixed statement also **folds**:

```
--m: bisect --l1 --l2 toward .p        # precrease only: line, paper stays flat
@fold .a to .c                         # fold: valley, flap containing .a rotates over
@fold .a to .c moving .a mountain      # explicit moving side + direction
@bisect --l1 --l2 toward .p moving .a  # construction axiom: moving side required
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

### 4.2 Naming collision

`fold` is already axiom 2's verb (`fold .a to .b`). The `@` modifier disambiguates
(`@fold` = perform axiom-2 fold *and* keep folded). No verb rename needed.

## 5. Output

The same run emits a FOLD file with two frames:

- **`creasePattern`** — the flat CP, as today (`vertices_coords`, `edges_vertices`,
  `edges_assignment`, `faces_vertices`, `beloch:edges`).
- **`foldedForm`** — 3D `vertices_coords`, `faceOrders`, and `edges_foldAngle`
  (sign matches derived `edges_assignment` M/V per `refs/foldformat.md`).

`edges_assignment` M/V is **computed** from each fold's rotation direction and the face's
accumulated orientation parity (front/back), not annotated.

## 6. Slice 1 — scope

**In:**
- Imperative evaluation; state threads through statements.
- Precrease axioms reused unchanged (now order-sensitive once paper is folded).
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
- Non-flat constructible 3D angles ("fold until edge meets…") — immediate follow-slice.
- `flip` / `rotate` whole-sheet isometries — fast follow.
- Folding *animation* (angle interpolation) — tooling concern.

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
