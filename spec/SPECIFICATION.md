# Beloch — Language Specification

**This is the living specification.** It always describes the language *as it
currently is*. It grows as each implementation slice lands; it is not a changelog
and not a design doc.

- Each section is tagged with the version it was introduced in, e.g. *(since v0.0)*.
- **What**, not **why** or **how**: rationale for a choice lives in an ADR
  (`../decisions/`); how a slice is built lives in its (disposable) implementation
  plan. This file is the durable source of truth for syntax, semantics, and the
  output contract.
- Citations are clickable links to the [References](#references) section below;
  machine-readable entries live in
  [`../paper/references.bib`](../paper/references.bib). A locator such as §1.5
  points to a section *in that cited source*, not in this document. Full texts
  are in `../refs/` (gitignored).

Current version: **v0.8-dev** (axiom 6 — fold a point onto a line, crease through a fixed point); **v0.4-dev** (axiom 4 — project a point onto a line); **v0.3-dev** (axiom 5 — angle bisector); **v0.2** (axiom 3 — perpendicular through a point); **v0.1** (faces); **v0.0** (minimal core).

---

## 1. Overview *(since v0.0)*

Beloch is a declarative language for origami. A `.bel` program is **evaluated**
(not compiled to an executable) into a data artifact describing a paper state,
emitted as FOLD. See [ADR 0007](../decisions/0007-evaluator-not-compiler.md).

The language is built on the Huzita-Justin fold axioms
[[justin1986]](#ref-justin1986), using them as primitive operations. *(since
v0.7-dev)* It is an **action model**: a program is an imperative sequence of
folding actions on a stateful sheet (§4.6). The axioms locate *where* a crease
goes; the `@` modifier actually folds. A program evaluates to a folded state,
emitted as a dual-frame FOLD file — the flat **crease pattern** and the
**folded form** (§7). The flat crease pattern (no `@` folds) is the special case.
See [ADR 0011](../decisions/0011-action-model.md).

### A note on axiom numbering

Beloch uses the **classic Huzita-Justin numbering** of the fold axioms (the
numbering used by [[justin1986]](#ref-justin1986) and most origami-math
references), where:

- **axiom 1** = the fold through two given points;
- **axiom 2** = the fold placing one point onto another.

Beware: Hull's *Basic Origami Operations* list
[[hull2020]](#ref-hull2020) §1.5 uses a
**different** numbering — it inserts "locate the intersection of two lines" as
its O2, so Hull's O3 is the classic axiom 2. When this spec writes "axiom 2" it
means the classic one (point-onto-point), i.e. Hull's O3. This discrepancy is
recorded in [antipatterns.md](../antipatterns.md) so it isn't re-conflated.

For reference, the classic operations relevant so far
[[justin1986]](#ref-justin1986) §8.1: ① line through two points; ② point onto
point (perpendicular bisector); **③ the fold through a point perpendicular to a
line** (Hull's O5); ④ projection of a point onto a line parallel to another; **⑤
the fold placing one line onto another (the angle bisector; Hull's O4)**. Note
that the angle bisector is **axiom 5**, not axiom 3 — and it is the first axiom
whose result leaves ℚ (square roots). See
[antipatterns.md](../antipatterns.md).

---

## 2. The paper *(since v0.0)*

A program begins by declaring its sheet:

```
paper square
```

`paper square` is the unit square with four pre-bound corner points, named
counter-clockwise from the origin:

| name | coordinates |
|------|-------------|
| `.a` | `(0, 0)` |
| `.b` | `(1, 0)` |
| `.c` | `(1, 1)` |
| `.d` | `(0, 1)` |

v0.0 supports no other paper shape.

---

## 3. Values *(since v0.0)*

Two kinds of value, distinguished by sigil:

- **Point** — `.name`. The four corners, plus any point derived by a
  construction (§4.3).
- **Crease / line** — `--name`. The geometric value of a fold: an (infinite)
  line. On output it appears as the edges of the folded state's faces (§7), and
  with `@` it actually folds the paper (§4.6).

All geometry is exact (§6).

---

## 4. Operations

### 4.1 Axiom 1 — line through two points *(since v0.0)*

```
through .x .y
```

The unique fold line passing through points `.x` and `.y`
[[justin1986]](#ref-justin1986), [[hull2020]](#ref-hull2020) §1.5 (O1).
**Error** if `.x` and `.y` are the same point (no unique line).

### 4.2 Axiom 2 — fold one point onto another *(since v0.0)*

```
map .x onto .y
```

The fold that places `.x` onto `.y`: the perpendicular bisector of the segment
`x–y` [[justin1986]](#ref-justin1986),
[[hull2020]](#ref-hull2020) §1.5 (O3 in Hull's numbering; see §1).
**Error** if `.x` and `.y` are the same point.

*(since v0.6-dev: verb is `map … onto …`; was `fold … to …`.)*

### 4.3 Construction — intersection of two creases *(since v0.0)*

```
cross --c1 --c2
```

The point where the two creases' lines meet. This is a point *construction*, not
a fold axiom, in the classic numbering; it is Hull's basic operation O2
[[hull2020]](#ref-hull2020) §1.5 (O2).

*(since v0.7-dev)* The intersection is a table-space point; it resolves to the
**material point on the topmost layer** covering that spot (`Q2-B`). On the flat,
unfolded sheet there is exactly one layer, so this is just the point itself;
after folding, where several layers overlap, the visible top layer is taken —
the one your hand would touch. **Errors:**

- the two lines are **parallel** (no intersection);
- the intersection point is **off the paper** — no layer covers it (exact
  point-in-polygon test; the boundary counts as on the paper).

### 4.4 Axiom 3 — perpendicular through a point *(since v0.2)*

```
perp --l through .p
```

The fold line through point `.p`, perpendicular to crease `--l`
[[justin1986]](#ref-justin1986) §8.1 (operation ③), [[hull2020]](#ref-hull2020)
§1.5 (O5 in Hull's numbering; see §1). This is the first axiom taking a **crease**
as an operand.

**On the number of solutions.** Operation ③ admits *two* fold lines exactly when
`.p` lies **on** `--l`: the perpendicular through `.p`, and `--l` itself (a
reflection maps a line onto itself either across a perpendicular or across the
line itself; both pass through `.p` only when `.p ∈ --l`). The second is the
**trivial, identity-like** solution — re-creasing the existing line, producing no
new geometry. Beloch always returns the **perpendicular**: it is unique and is
the meaningful construction. We deliberately ignore the trivial solution,
assuming the program wants the meaningful variant. Consequently `perp` has **no
geometric precondition and never errors** (beyond undefined-name errors).

### 4.5 Axiom 5 — fold one line onto another *(since v0.3-dev)*

```
map --l1 onto --l2 toward .p
```

The fold placing line `--l1` onto line `--l2`: the **angle bisector**
[[justin1986]](#ref-justin1986) §8.1 (operation ⑤), [[hull2020]](#ref-hull2020)
§1.5 (O4 in Hull's numbering; see §1). Two intersecting lines have **two**
bisectors (perpendicular to each other); the optional `toward .p` selector picks
the one whose angular sector contains `.p`. Two **parallel** lines have a single
**midline**, and `toward` is ignored.

**Errors:** the two lines are the **same line**; the lines intersect and
`toward` is **omitted** (ambiguous); `.p` lies **on** `--l1` or `--l2`
(ambiguous).

This is the first axiom whose result leaves ℚ — the bisector of two rational
lines is generally irrational (slope `√2−1` for `y=0` and `y=x`). All geometry is
now computed over exact **constructible reals** (`Num`; see
[ADR 0010](../decisions/0010-constructible-real-numbers.md) and §6), so equality,
parallelism, and on-paper tests stay exact.

*(since v0.6-dev: verb is `map … onto …`; was `bisect …`.)*

### 4.5a Axiom 4 — project a point onto a line *(since v0.4-dev)*

```
map .p onto --l1 perp --l2
```

The fold that places point `.p` onto line `--l1` with a crease **perpendicular
to** `--l2`. Equivalently, `.p` is moved **parallel to** `--l2` until it lands on
`--l1` — the *projection of `.p` onto `--l1` parallel to `--l2`*
[[justin1986]](#ref-justin1986) §8.1 (operation ④). At most **one** solution, so
there is no `toward` selector.

**Numbering.** This is classic Justin **axiom 4**, which is Wikipedia's
Huzita-Hatori **O7** — *not* Wikipedia's O4 (that is Beloch's axiom 3,
perpendicular-through-a-point). See §1 and `antipatterns.md`.

**Errors:** `--l1` and `--l2` are **parallel** — no fold exists (zero solutions;
or, when `.p` lies on `--l1`, infinitely many — forbidden either way). When `.p`
already lies on `--l1` and the lines are not parallel, the crease is the
perpendicular to `--l2` through `.p` (one solution).

The result stays in ℚ — no square roots
[[justin1986]](#ref-justin1986) §8.2(a).

### 4.5b Axiom 6 — fold a point onto a line, crease through a fixed point *(since v0.8-dev)*

Justin operation ⑥ `(P → D, P' → P')`: fold `.p` onto line `--d` with a single
crease that keeps `.p'` fixed.

```
map .p onto --d through .p'              # ≤1 solution
map .p onto --d through .p' toward .x    # 2 solutions: pick the landing nearer .x
```

`.p'` lies on the crease, so it is equidistant from `.p` and the image `.p''` on
`--d`; `.p''` is therefore an intersection of the circle (centre `.p'`, radius
`|p'p|`) with `--d` — up to two of them, hence up to two creases (each the
perpendicular bisector of `.p` and its landing). Second-degree: square roots
only, so `Num` is unchanged — **cube roots still do not arise** (they wait for
axiom 7, the cubic Beloch fold ⑦). See "A note on axiom numbering" in §1.
As of the real-algebraic kernel (ADR 0012), `Num` represents arbitrary real
algebraic numbers (cube roots and the casus-irreducibilis cubics included);
axioms 1–6 are unchanged in behaviour. The axiom 7 statement surface itself is
the next slice.

`through` is the same verb as in axiom 3 (`perp --l through .p`): the crease
passes through the named point. `toward` is the same selector as axiom 5.

Errors: the lines/points being out of reach (`dist(p',D) > |p'p|`) raises *out of
reach*; two solutions without `toward` raises an ambiguity error naming the
selector; `.p` and `.p'` being the same point raises *no fold exists*. When `.p`
already lies on `--d`, the identity landing is dropped and the mirror landing
gives the crease.

### 4.6 Folding: `@` *(since v0.7-dev)*

A bare axiom is a **precrease**: it computes a crease line and marks it; the
paper stays flat. Prefixing it with `@` **performs the fold**:

```
@map .a onto .c moving .a            ; fold the flap containing .a, valley
@map .a onto .c moving .a mountain   ; ... as a mountain
@perp --l through .p moving .q        ; line-construction folds need `moving`
```

- **`moving .p`** picks the side that moves — the flap containing material point
  `.p`. For `@map .x onto .y` it defaults to `.x` (the moved point); the
  line-construction folds (`@through`, `@perp`, `@map --l onto --m`) have no
  natural default and **require** `moving`.
- **`mountain`** sets the fold direction; the default is **valley** (toward the
  viewer). Mountain/valley is not annotated — it is *derived* (see below).

**Folded state.** The paper is a stack of flat **faces** — each a convex polygon
in paper coordinates plus a rigid isometry placing it on the table — ordered
bottom→top (the layer stack). A flat fold (±180°) keeps everything in the table
plane, so the only "depth" is this stacking order. A simple fold reflects every
layer on the moving side of the crease line across it (an exact reflection — no
`sqrt`) and restacks: the moved flap, reversed, goes on top (valley) or
underneath (mountain). "Fold through all layers" is automatic.

**Derived mountain/valley.** Each crease's assignment is
`valley XOR (the cutting face is back-up)`, fixed when the fold runs. Because
stacked layers alternate front/back, one fold through a stack yields the correct
**alternating** M/V across layers (the accordion). Earlier creases keep their
assignment (material facts).

### 4.7 `flip` — turn the sheet over *(since v0.7-dev)*

```
flip
```

Turns the whole sheet over: every face's orientation inverts and the layer stack
reverses (so the previously bottom layer becomes reachable on top). Because
orientation inverts, a *subsequent* valley command is derived as a **mountain**
relative to the original front — i.e. "mountain = turn over, then valley." `flip`
takes no axis: with named points, where the sheet lands is irrelevant, so the
reflection uses an internal canonical axis (the footprint's vertical centerline).
A direction argument may be added later when the animation renderer needs it.

---

## 5. Naming and program structure *(since v0.0)*

A program is `paper square` followed by statements, executed top to bottom. A
name must be defined before it is used.

- **Crease statement** — binds a crease, or is anonymous; with `@` it also folds
  (§4.6):
  ```
  --d1: through .a .c              ; named precrease
  map .a onto .c                   ; anonymous precrease
  @map .a onto .c moving .a        ; fold (valley)
  ```
- **Point statement** — binds a derived point:
  ```
  .center: cross --d1 --d2
  ```
- **Flip statement** *(since v0.7-dev)* — turns the sheet over (§4.7):
  ```
  flip
  ```

Derived points and named creases are usable in any later statement. `;` begins a
line comment.

> Concrete syntax (keywords, sigils) is stable as of v0.0 but may still be
> revised before v1.0.

---

## 6. Exactness *(since v0.0)*

All coordinates and line coefficients are exact **constructible reals** (`Num`;
see [ADR 0010](../decisions/0010-constructible-real-numbers.md)). A line is
`a·x + b·y = c` with `a, b, c ∈ Num.t`.

`Num.t` is a recursive tower of quadratic extensions over ℚ: `Rat of Q.t` at the
base and `Ext(a, b, d)` = a + b√d for the irrational levels. The ℚ **fast-path**
applies for all values produced by axioms 1–4: their results stay in `Rat`, so
those operations pay no overhead over the previous ℚ representation. The `Ext`
constructor is introduced only by `sqrt`, which is first needed at axiom 5.

Axioms 1–4 over rational inputs remain **closed in ℚ**: no square roots arise.
At axiom 5 (the angle bisector) the result generally requires square roots —
degree-2-or-less extensions of the base field per [[hull2020]](#ref-hull2020)
§3.2. Cube roots do not arise until axiom 6 (the Beloch fold).

Equality, parallelism, and point-in-polygon are therefore **exact throughout** —
no epsilon, no tolerance, no sampling. The only place a `float` appears is
`to_float` in the serialisation of `vertices_coords` to FOLD JSON; internal
values are never truncated.

---

## 7. Output: the FOLD contract *(since v0.0; dual-frame since v0.7-dev)*

`beloch fold FILE.bel` emits a [FOLD](https://github.com/edemaine/fold) file
[[foldformat]](#ref-foldformat) with **two frames** built from the folded state's
faces: the flat **crease pattern** (frame 0, the top-level dictionary) and the
**folded form** (`file_frames[0]`). A program with no `@` folds still emits both;
the folded form then coincides with the flat sheet.

The planar graph is the face set: vertices are deduplicated by paper coordinate
(vertices shared across faces along a crease coincide), each face is one polygon,
edges are the deduplicated polygon edges. Square-boundary edges are `"B"`; an
internal edge is a crease.

**Frame 0 — `creasePattern`:**

- `file_spec`, `file_creator: "beloch 0.3.0-dev"`,
  `frame_classes: ["creasePattern"]`
- `vertices_coords` — `[x, y]` per vertex, in **paper** coordinates. Exact values
  are rendered to JSON decimal at serialization (non-terminating reals rounded
  *in the output only*; internal values stay exact).
- `edges_vertices` — `[v0, v1]` index pairs.
- `edges_assignment` ([[foldformat]](#ref-foldformat) §"Edge information") — `"B"`
  for paper-boundary edges, **derived `"M"`/`"V"`** for folded creases (§4.6),
  and `"U"` for an unfolded precrease (a crease line with no fold yet). One
  physical fold through several layers can yield different M/V per layer (the
  accordion), since each crease edge carries its own derived assignment.
- `faces_vertices` — each face's vertex indices, counter-clockwise. A program
  with no creases yields the single square face `[[0, 1, 2, 3]]`.
- `beloch:edges` — custom property ([[foldformat]](#ref-foldformat) §"Custom
  Properties") carrying, per crease edge, its originating operation (`"axiom1"`,
  `"axiom2"`, `"axiom3"`, `"axiom5"`), the source point/crease names, the source
  span, and the bound **`"name"`** (e.g. `"d1"` for `--d1: …`, else `null`).
  Additive: stock FOLD consumers ignore it; `tools/fold2svg.mjs` uses it to
  colour/label creases.

**`file_frames[0]` — `foldedForm`** (`frame_parent: 0`, `frame_inherit: true`, so
it inherits the topology and overrides only the coordinates):

- `vertices_coords` — the same vertices in **table** (folded) coordinates: each
  face's paper polygon through its isometry. Flat folds stay in the plane, so
  these are 2D; stacking is conveyed by `faceOrders`, not a z-offset.
- `edges_foldAngle` — `+180` for valley, `−180` for mountain, `0` otherwise; the
  sign matches `edges_assignment`.
- `faceOrders` — `[f, g, s]` layer-ordering triples for face pairs whose table
  footprints **overlap**; `s = +1` if `f` is above `g` (toward `g`'s normal),
  `−1` below ([[foldformat]](#ref-foldformat) §"Layer information"). Emitted only
  for overlapping pairs (empty when nothing overlaps, e.g. a flat program).

The renderer/animation client is a separate consumer; `tools/fold2svg.mjs` draws
frame 0 by default and the folded form with `--folded`.

---

## 8. Errors *(since v0.0)*

Every error is a compile error with a source span; the first matching error wins
and the process exits non-zero:

- parse error;
- axiom 1 or 2 whose two points are at the **same place** (coincident — which can
  also happen *after* folds bring two material points together);
- `cross` on parallel creases (no intersection);
- `cross` whose intersection is **off the paper** (no layer covers it);
- `map --l1 onto --l2` (axiom 5) that is ambiguous — intersecting lines with no
  `toward`, or a `toward` point lying on a fold line;
- a `@` fold on a line-construction axiom (`@through`, `@perp`, `@map --l onto --m`)
  with no `moving`, or a `moving` point lying on the fold axis (no side);
- reference to an undefined point or crease name.

---

## Appendix A — grammar (informal) *(since v0.0)*

The Menhir grammar is authoritative once written; this sketch is a guide.

```
program       := "paper" "square" stmt*
stmt          := crease_stmt | point_stmt | flip_stmt
crease_stmt   := [ CREASE_NAME ":" ] [ "@" ] axiom [ "moving" point_operand ] [ "mountain" ]
point_stmt    := POINT_NAME ":" point_expr
flip_stmt     := "flip"
axiom         := "through" point_operand point_operand          ; axiom 1
               | "map" point_operand "onto" point_operand       ; axiom 2
               | "perp" line_operand "through" point_operand     ; axiom 3
               | "map" point_operand "onto" line_operand "perp" line_operand  ; axiom 4
               | "map" line_operand "onto" line_operand [ "toward" point_operand ]  ; axiom 5
               | "map" point_operand "onto" line_operand "through" point_operand
                     [ "toward" point_operand ]                                  ; axiom 6
point_expr    := "cross" line_operand line_operand              ; line intersection (binding RHS)
point_operand := POINT_NAME | ".(" line_operand line_operand ")"     ; named, or inline cross
line_operand  := CREASE_NAME | "--(" point_operand point_operand ")" ; named, or inline through
POINT_NAME    := "." ident
CREASE_NAME   := "--" ident
```

A bare axiom statement is a *precrease* (computes a crease line, paper stays
flat). The `@` prefix performs the fold (§4.6); `moving`/`mountain` describe it.
`flip` turns the whole sheet over (§4.7). *(since v0.7-dev)* Any operand may be an
**inline anonymous construction** — `--(.a .b)` is the line through two points,
`.(--a --b)` the point where two creases meet; these nest freely and coexist with
the `cross`/`through` keywords (which remain for named bindings). Brackets appear
only as operands, never as a binding right-hand side.

---

## Appendix B — not yet in the language

Deferred, in rough order of likely arrival: non-flat (constructible-angle) folds ·
`rotate` · fold maneuvers (reverse/squash/sink/petal, via `unfold` + layer
selection) · axiom 7 (cubic Beloch fold, needs real-algebraic number kernel) ·
regions · parts/imports · `step` blocks · a dedicated render/animation engine ·
YR diagrams. These are not part of the language until a slice lands and this spec
is extended.

**Landed:** faces (v0.1); axiom 3 — perpendicular (v0.2); axiom 4 — projection (v0.4-dev); axiom 5 — angle
bisector (v0.3-dev); the `map … onto …` verb and the `@` fold modifier
(v0.6-dev); and *(v0.7-dev)* the **action model** — `@` fold execution, the
folded-state runtime, derived mountain/valley, the dual `creasePattern` +
`foldedForm` FOLD output, `flip`, and inline anonymous operands
(`--(.a .b)` / `.(--a --b)`). See
[ADR 0011](../decisions/0011-action-model.md). Mountain/valley is *derived* from
fold actions, not a separate annotation pass. *(v0.8-dev)* axiom 6 — fold a
point onto a line with the crease through a fixed point (`map .p onto --d through
.p'`, optional `toward` for disambiguation).

---

## References

Machine-readable entries: [`../paper/references.bib`](../paper/references.bib).
Each entry links to a public source where one exists, and to the local full text
in `../refs/` (gitignored — local checkout only).

<a id="ref-hull2020"></a>
**[hull2020]** Thomas C. Hull. *Origametry: Mathematical Methods in Paper
Folding.* Cambridge University Press, 2020.
[doi.org/10.1017/9781108778633](https://doi.org/10.1017/9781108778633) ·
[local PDF](../refs/hull2020.pdf).
The fold axioms and Hull's Basic Origami Operations are in §1.5 "The Basic
Origami Operations".

<a id="ref-justin1986"></a>
**[justin1986]** Jacques Justin. *Résolution par le pliage de l'équation du
troisième degré et applications géométriques.* L'Ouvert, no. 42 (March 1986),
pp. 9–19. [local PDF](../refs/justin1986.pdf).
First complete statement of the seven fold axioms (classic numbering).

<a id="ref-foldformat"></a>
**[foldformat]** Erik D. Demaine, Jason S. Ku, Robert J. Lang. *FOLD File Format
Specification* (v1.2).
[github.com/edemaine/fold](https://github.com/edemaine/fold) ·
[local copy](../refs/foldformat.md).
Relevant sections: "Edge information: `edges_...`" (edge assignments) and
"Custom Properties" (the `namespace:key` convention used by `beloch:*`).
