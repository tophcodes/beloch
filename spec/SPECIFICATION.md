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

Current version: **v0.3-dev** (axiom 5 — angle bisector) — in progress; **v0.2** (axiom 3 — perpendicular through a point); **v0.1** (faces); **v0.0** (minimal core).

---

## 1. Overview *(since v0.0)*

Beloch is a declarative language for origami. A `.bel` program is **evaluated**
(not compiled to an executable) into a data artifact describing a paper state —
for v0.0, a flat crease pattern emitted as FOLD. See
[ADR 0007](../decisions/0007-evaluator-not-compiler.md).

The language is built on the Huzita-Justin fold axioms
[[justin1986]](#ref-justin1986), using them as primitive operations.

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
  line. For output it is clipped to the paper (§7).

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
[[hull2020]](#ref-hull2020) §1.5 (O2). **Errors:**

- the two lines are **parallel** (no intersection);
- the intersection point is **not on the paper** — decided by an exact
  point-in-polygon test; the boundary counts as on the paper.

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

---

## 5. Naming and program structure *(since v0.0)*

A program is `paper square` followed by statements, executed top to bottom. A
name must be defined before it is used.

- **Crease statement** — binds a crease, or is anonymous:
  ```
  --d1: through .a .c     ; named
  map .a onto .c          ; anonymous
  ```
- **Point statement** — binds a derived point:
  ```
  .center: cross --d1 --d2
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

## 7. Output: the FOLD contract *(since v0.0)*

`beloch fold FILE.bel` emits a [FOLD](https://github.com/edemaine/fold) file
[[foldformat]](#ref-foldformat) describing the flat crease pattern.

Each crease line is clipped to the paper polygon to a segment. All on-paper
crease-crease intersections are computed and the segments are split there, with
vertices deduplicated and duplicate/coincident edges removed, producing a
**simple** planar graph of vertices and edges. *(since v0.1)* The bounded faces
of that graph — the paper regions enclosed by creases and the boundary — are
extracted by exact planar face traversal and emitted as `faces_vertices`.

Emitted fields:

- `file_spec`, `file_creator: "beloch 0.2.0-dev"`,
  `frame_classes: ["creasePattern"]`
- `vertices_coords` — `[x, y]` per vertex. Exact ℚ values are rendered to JSON
  decimal at serialization (non-terminating rationals are rounded *in the output
  only*; internal values stay exact).
- `edges_vertices` — `[v0, v1]` index pairs
- `edges_assignment` ([[foldformat]](#ref-foldformat) §"Edge information") — `"B"` for the four
  paper-boundary edges; **`"U"`** (unassigned) for every crease. v0.0 does not
  model fold direction (mountain/valley), so `"U"` is the honest label; claiming
  `"V"` would assert an uncomputed direction.
- `faces_vertices` *(since v0.1)* — for each bounded face, its vertex indices in
  counter-clockwise order. The unbounded outer face is excluded. A program with
  no creases yields the single square face `[[0, 1, 2, 3]]`.
- `beloch:edges` — custom property ([[foldformat]](#ref-foldformat) §"Custom Properties") carrying, per
  crease edge, its originating operation (`"axiom1"` / `"axiom2"`), the source
  point/crease names, the source span, and the bound **`"name"`** — the crease
  name as a string (e.g. `"d1"`) if the statement was named (`--d1: …`), or
  `null` for an anonymous crease. This field is additive: stock FOLD consumers
  ignore unknown keys. `tools/fold2svg.mjs` uses it to label named creases on
  the diagram (on the line, ~18% in from one end, with a white halo to avoid
  colliding with corner labels). Used for provenance and source mapping.

---

## 8. Errors *(since v0.0)*

Every error is a compile error with a source span; the first matching error wins
and the process exits non-zero:

- parse error;
- axiom 1 or 2 with two identical points;
- `cross` on parallel creases;
- `cross` whose intersection lies off the paper;
- reference to an undefined point or crease name;
- `@` fold statement — folding is not yet implemented.

---

## Appendix A — grammar (informal) *(since v0.0)*

The Menhir grammar is authoritative once written; this sketch is a guide.

```
program     := "paper" "square" stmt*
stmt        := crease_stmt | point_stmt
crease_stmt := [ CREASE_NAME ":" ] [ "@" ] axiom [ "moving" point_ref ] [ "mountain" ]
point_stmt  := POINT_NAME ":" point_expr
axiom       := "through" point_ref point_ref            ; axiom 1
             | "map" point_ref "onto" point_ref         ; axiom 2
             | "perp" crease_ref "through" point_ref     ; axiom 3
             | "map" crease_ref "onto" crease_ref [ "toward" point_ref ]  ; axiom 5
point_expr  := "cross" CREASE_NAME CREASE_NAME    ; line intersection
crease_ref  := CREASE_NAME
point_ref   := POINT_NAME
POINT_NAME  := "." ident
CREASE_NAME := "--" ident
```

A bare statement is a *precrease* (computes a crease line, paper stays flat). The `@` prefix marks an actual fold (`moving`/`mountain` describe it); fold **evaluation** is not yet implemented — `@` statements currently raise a compile error.

---

## Appendix B — not yet in the language

Deferred, in rough order of likely arrival: folded state · axioms 4, 6, 7 ·
regions · parts/imports · `step` blocks · `flip`/`rotate` · YR diagrams. These
are not part of the language until a slice lands and this spec is extended.

(Axiom 5 — angle bisector — landed in v0.3-dev. Axiom 3 — perpendicular through a
point — landed in v0.2. Faces landed in v0.1.)

*(since v0.6-dev)* The `map … onto …` verb (axioms 2 and 5) and the `@` fold
modifier (`moving`/`mountain`) surface have landed; see
[ADR 0011](../decisions/0011-action-model.md). Mountain/valley direction is now
*derived* from fold actions (see the action-model design doc) rather than being a
separate annotation pass. The folded-state runtime (`foldedForm`, derived M/V,
dual FOLD output) is deferred to a later plan.

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
