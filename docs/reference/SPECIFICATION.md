# Beloch — Language Specification

**This is the living specification.** It always describes the language *as it
currently is*. It grows as each implementation slice lands; it is not a changelog
and not a design doc.

- Each section is tagged with the version it was introduced in, e.g. *(since v0.0)*.
- **What**, not **why** or **how**: rationale for a choice lives in an ADR
  (`../decision/`); how a slice is built lives in its (disposable) implementation
  plan. This file is the durable source of truth for syntax, semantics, and the
  output contract.
- Citations are clickable links to the [References](#references) section below;
  machine-readable entries live in
  [`../bibliography/references.bib`](../bibliography/references.bib). A locator such as §1.5
  points to a section *in that cited source*, not in this document. Full texts
  are in `../refs/` (gitignored).

Current version: **v0.27-dev** (paper-incidence filter for axioms 6 and 7:
a candidate crease that cuts no face is dropped before the ambiguity check,
the way axiom 5 already does it (§4.5); a single survivor is taken silently
even when `toward` is written, `toward` selects among the survivors only, and
an empty survivor list is its own error, distinct from *out of reach*);
**v0.26-dev** (layer placement and the reverse fold:
`fold … over/under <flap>` splices the moved block into the stack beside a
named flap; `reverse` runs an inside or outside reverse fold as two placed
half-folds over one line; both derive their crease letters from the finished
stack);
**v0.25-dev** (free point on a line — 1-DOF reference point
along a line's material bundle; `.p = free on --l from .x at <rational>`, `at`
optional (default `t = 1/2`); `free` is provenance, not a kernel relaxation —
the result is an ordinary exact point; `beloch:free` FOLD emission, a
forward-compat hook for a future renderer slider);
**v0.24-dev** (default fold scope — no `moving`/`up to` folds
the **outside-contiguous prefix** of the layer order down to and including the
anchor flap, not every layer on the anchor's side; a point on a crease shared
by several flaps seeds the whole contiguous run; `moving` now names the
**deepest** flap of that prefix; a bare axiom-5 line-onto-line fold with no
`moving` and no implied point still falls back to the all-layers set;
`up to` is unchanged as the interim way to fold past the anchor flap; see
[`docs/notes/2026-07-20-default-fold-scope.md`](../notes/2026-07-20-default-fold-scope.md));
**v0.23-dev** (**`flatten` generalizes `collapse`, one
solver pipeline, stayer convention** — single-vertex flat-folding is renamed
`flatten`. Every statement runs one pipeline, no modes: `()` items state the
rays (the shipped `&`/`\` selectors narrow a multi-segment crease when
needed, but no longer must — the stayer filter prunes wrong segment choices
on its own) and any known material facts (`mountain`/`valley`, `over`) as
hard constraints; a bare element is solver-assigned, not defaulted to
valley; the solver derives the M/V of every unmarked ray, the one emergent
ray when the given ray count is odd — the swivel rabbit-ear move no Huzita
axiom constructs directly — and the stacking, all subject to
Maekawa/Kawasaki and anchored on the **stayer**, the material that does not
move: fixed by convention (the leading two elements' <180° arc) or named
explicitly with `(staying <flap>)`, replacing the reserved `standing` slot;
and `{toward <point>}`, an item in braces rather than a trailing keyword,
selects among survivors by a three-stage rule (position class, min-mountain
canon, rank dipole) only when more than one remains — never mandatory. The
item list drops `and` for parenthesized juxtaposition (`flatten (--a & .p)
(--b & .q) …`); `flatten` is bindable, so an emergent crease — otherwise
unconstructible — gets a name, and its tip point becomes selectable);
**v0.22-dev** (**partial marks — the pinch** — `mark
<construction> between .a .b` / `at .p` clip a mark's extent; an extent that ends
mid-face is a non-subdividing *record* — splits no rays, can dangle mid-face —
instead of subdividing everything it crosses, discriminated by
boundary-incidence rather than which form was written; `mark … valley|mountain`
sets a crease-pattern-frame M/V *intent* on records the same way it does on
subdividing marks; `#[...]` picks the flap a record lands on; `mark --l =
<construction> [extent] [dir] [#[...]]` combines bind-and-write; records emit into a
`beloch:marks` FOLD custom field and `render-svg` draws them as a dashed
reference line or short tick, distinct from live `F`/`M`/`V` edges);
**v0.21-dev** (**mark/fold notation** — `map`/`through`/`perp`
constructions are pure reads: bindable line values, touching nothing; the writes are
the keyword verbs **`mark`** (crease and leave flat, FOLD `F`) and **`fold`**
(crease and fold, FOLD `M`/`V`), alongside `collapse` and `flip`; `@` is
retired entirely from the grammar — this completes the read/write law begun
in the v0.20-dev cutover (through was its one write; now it too is a read));
**v0.20-dev** (`@collapse` — single-vertex collapse: n ≥ 4
material creases sharing one interior vertex fold straight to the flat end
state in one step — rabbit ear, waterbomb — checked by Kawasaki/Maekawa/local
validity, `over` disambiguates the layer order, `standing` is reserved
syntax the evaluator does not yet implement; **notation cutover** — reads are
operators (meet `*`, filter `&`, drop `\`, union `[]`, the incident-to-all
selectors `.[] --[] #[]`), the one write was the keyword `through`);
**v0.19-dev** (material crossings live in paper space, on the marks; no table-space point values; axiom 5 `toward` is a fold direction, not a sector, with a paper-incidence filter for the omitted case and a derived `moving`); **v0.18-dev** (fold scope — flap-typed `moving`, `up to` for some-layers simple folds, `@fold` along material creases); **v0.17-dev** (crease-segment selection — the `&` filter: a crease name is a bundle, projected to one segment by incidence); **v0.16-dev** (`def`/`apply`/instances, qualified access, `export`; `=` binding separator); **v0.9-dev** (axiom 7 — cubic Beloch fold, two points each onto a line); **v0.8-dev** (axiom 6 — fold a point onto a line, crease through a fixed point); **v0.4-dev** (axiom 4 — project a point onto a line); **v0.3-dev** (axiom 5 — angle bisector); **v0.2** (axiom 3 — perpendicular through a point); **v0.1** (faces); **v0.0** (minimal core).

---

## 7. Output: the FOLD contract *(since v0.0; dual-frame since v0.7-dev; multi-frame since v0.16-dev)*

`beloch fold FILE.bel` emits a [FOLD](https://github.com/edemaine/fold) file
[[foldformat]](#ref-foldformat) with **two or more frames** built from the
folded state's faces: the flat **crease pattern** (frame 0, the top-level
dictionary) and one or more **folded form** frames (`file_frames`). A program
with no `fold` actions still emits at least one folded-form frame; it then
coincides with the flat sheet.

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
  for paper-boundary edges, **derived `"M"`/`"V"`** for folded creases (`BELOCH-WRITES.md`),
  and *(since v0.21-dev)* `"F"` — present but not folded — for a `mark`ed
  crease (a crease line with no fold yet); its M/V *intent* still lives in the
  crease-pattern frame. `"U"` is never emitted: Beloch always knows a crease's
  disposition. One physical fold through several layers can yield different
  M/V per layer (the accordion), since each crease edge carries its own
  derived assignment.
- `faces_vertices` — each face's vertex indices, counter-clockwise. A program
  with no creases yields the single square face `[[0, 1, 2, 3]]`.
- `beloch:edges` — custom property ([[foldformat]](#ref-foldformat) §"Custom
  Properties") carrying, per crease edge, its originating operation (`"axiom1"`,
  `"axiom2"`, `"axiom3"`, `"axiom5"`), the source point/crease names, the source
  span, and the bound **`"name"`** (e.g. `"d1"` for `--d1 = …`, else `null`).
  *(since v0.16-dev)* A crease bound inside a retained instance carries its
  **qualified name** — `--pq` bound inside `$p1 = apply …` is named `"p1.pq"`,
  collision-free across repeated `apply`s of the same `def`. `"name"` is
  `null` for creases bound to a `_`-temp (`BELOCH-NAMES.md`, Names) and for creases produced by a
  naked (unbound) `apply`. Additive: stock FOLD consumers ignore the field;
  `render/render-svg` uses `"name"` to color/label creases.
- `beloch:marks` — custom property *(since v0.22-dev)* carrying the
  **non-subdividing record marks** (`BELOCH-WRITES.md`) that a `between`/`at` extent ending
  mid-face produces — reference/pinch creases that are not part of
  `edges_vertices`/`edges_assignment` at all. A list of `{"kind": "seg", "a",
  "b", "line", "intent", "crease_id"}` (a dangling segment, exact paper
  coordinates) or `{"kind": "point", "p", "line", "intent", "crease_id"}` (a
  single reference point); `"line"` is the mark's supporting line, for
  orientation only. Additive: stock FOLD consumers ignore it; `render/render-svg`
  draws `seg` entries as a thin dashed reference line and `point` entries as a
  short tick along `"line"`, both visually distinct from live `F`/`M`/`V` edges.
- `beloch:free` — custom property *(since v0.25-dev)* carrying every **free
  point** (§4.3a), keyed by point name (instance-qualified inside an applied
  `def`, e.g. `"d1.m"`, matching `beloch:edges`' `"name"`). Each entry is
  `{"t", "endpoints", "source_line"}`: `"t"` is the exact rational, emitted as
  a **string** (e.g. `"1/2"`), not rounded to a JSON float, so a future
  consumer can recover it exactly; `"endpoints"` is `[[x0, y0], [x1, y1]]`,
  the bundle's two furthest-out points (`t=0`, `t=1`) in paper coordinates,
  rendered to JSON decimal like `vertices_coords`. This is a
  forward-compatibility hook for tooling — a future renderer MAY read it to
  build a `t`-slider over the endpoints; no renderer consumes it yet.

**`file_frames` — one `foldedForm` frame per fold**: a flat baseline frame for
the unfolded sheet, followed by one frame per fold/collapse action, in program
order (the numeric folding sequence). Each frame is **self-contained**
(`frame_parent: 0`, `frame_inherit: false`) rather than inheriting the parent's
topology — an earlier frame's state has fewer faces than the final crease
pattern, so it cannot share the parent's vertex/face indexing. Each frame
carries its own:

- `vertices_coords` — this state's vertices in **table** (folded) coordinates:
  each face's paper polygon through its isometry. Flat folds stay in the plane,
  so these are 2D; stacking is conveyed by `faceOrders`, not a z-offset.
- `edges_vertices`, `edges_assignment`, `faces_vertices` — this state's own
  topology (indices are local to the frame, not shared with frame 0 or other
  folded-form frames).
- `edges_foldAngle` — `+180` for valley, `−180` for mountain, `0` otherwise; the
  sign matches `edges_assignment`.
- `faceOrders` — `[f, g, s]` layer-ordering triples for face pairs whose table
  footprints **overlap**; `s = +1` if `f` is above `g` (toward `g`'s normal),
  `−1` below ([[foldformat]](#ref-foldformat) §"Layer information"). Emitted only
  for overlapping pairs (empty when nothing overlaps, e.g. a flat program).
- `"beloch:source_line"` — the 1-based source line of the fold that produced
  this frame, or `null` for the baseline frame; a statement-level source map
  for a folding-diagram player.

The top-level frame (frame 0) is always the final, cumulative crease pattern —
it does not change with the number of frames. A program with no folds emits
exactly one folded-form frame (the flat baseline), self-contained rather than
`frame_inherit: true`.

The renderer/animation client is a separate consumer; `render/render-svg` draws
frame 0 by default and a folded form with `--folded`.

---

## Appendix A — grammar (informal) *(since v0.0)*

The Menhir grammar is authoritative once written; this sketch is a guide.

```grammar
program       := "paper" sheet stmt*                              ; docs/reference/BELOCH-GRAMMAR.md, "Programs"
stmt          := crease_stmt | point_stmt | flip_stmt | flatten_stmt
crease_stmt   := CREASE_NAME "=" "(" axiom ")"                    ; a read — binds a line value, scores nothing
               | CREASE_NAME "=" line_operand                     ; a read — binds an existing line: name, join, selector, filter or union
               | "mark" item* output                              ; crease flat, an anonymous construction or an existing line as one of the items (item syntax, since v0.27-dev)
               | "fold" item* output                               ; crease and fold
               | "reverse" item* output                            ; reverse fold (since v0.26-dev)
item          := "(" item_body ")"
item_body     := markable
               | "moving" flap_operand                             ; fold, reverse
               | "up" "to" flap_operand                            ; fold only
               | "mountain"                                        ; fold, mark
               | "valley"                                          ; mark only
               | ( "over" | "under" ) flap_operand                 ; fold only
               | "outside"                                         ; reverse only
               | "on" flap_operand                                 ; mark only
               | "between" point_operand point_operand             ; mark only
               | "at" point_operand                                ; mark only
markable      := axiom | align | line_operand                     ; since v0.21-dev; align since v0.23-dev
align         := "align" CREASE_NAME* align_part+                   ; see docs/reference/BELOCH-CONSTRUCTIONS.md; `toward` and `moving` are items there
output        := [ "as" CREASE_NAME [ "!" ] | "into" CREASE_NAME ]
point_stmt    := POINT_NAME "=" line_operand "*" line_operand     ; meet (binary), bare at a binding's RHS: the point where two lines cross
               | POINT_NAME "=" ".[" line_operand+ "]"            ; meet (n-ary): the point on all listed lines
               | POINT_NAME "=" free_point                          ; free point: docs/reference/BELOCH-GRAMMAR.md, "Free points"
flip_stmt     := "flip"
axiom         := "through" point_operand point_operand          ; axiom 1 — a read (construction, since v0.21-dev)
               | "map" point_operand "onto" point_operand       ; axiom 2
               | "perp" line_operand "through" point_operand     ; axiom 3
               | "map" point_operand "onto" line_operand "perp" line_operand  ; axiom 4
               | "map" line_operand "onto" line_operand       ; axiom 5
               | "map" point_operand "onto" line_operand "through" point_operand  ; axiom 6
               | "map" point_operand "onto" line_operand
                     "and" point_operand "onto" line_operand    ; axiom 7
flap_operand  := point_operand | line_operand | "#[" point_operand+ "]"              ; since v0.18-dev
POINT_NAME    := "." ident
CREASE_NAME   := "--" ident
INSTANCE_NAME := "$" ident

; since v0.20-dev — `BELOCH-WRITES.md`; `@` dropped v0.21-dev; renamed `collapse`→`flatten`,
; paren-juxtaposition items, bindable v0.23-dev; one-pipeline model,
; the `toward` item (was a trailing keyword), `valley` marker v0.23-dev;
; stayer convention, `staying` replaces reserved `standing` v0.23-dev;
; `toward` moves from a braced clause to a parenthesized item like the
; rest, and binding moves from a `CREASE_NAME "="` prefix to the `output`
; clause above, v0.27-dev
flatten_stmt  := "flatten" flatten_item+ output
flatten_item  := "(" flatten_elem ")"
               | "(" over_flap "over" over_flap ")"
               | "(" "staying" flap_operand ")"
               | "(" "toward" point_operand ")"
flatten_elem  := line_operand [ "mountain" | "valley" ]
over_flap     := point_operand | "#[" point_operand+ "]"

```

A construction (`through`/`map`/`perp`) is a pure read: it computes a line but
touches nothing (§4.10). `mark` creases it flat; `fold` creases and folds it:
its items state `(moving …)` to anchor the fold, `(up to …)` to scope it,
`(mountain)` to set its direction (`BELOCH-WRITES.md`). Either verb, given a `line_operand`
item instead of a construction, acts on an existing material crease instead of
computing a new line. `flip` turns the whole sheet over (`BELOCH-WRITES.md`) and takes no
item. *(since v0.7-dev)* Any operand may be an **inline read** (§4.10): `--x
* --y` (or `.[--x --y]`) is the point where two lines meet; `.a * .b` (or
`--[.a .b]`) is the existing crease/edge through two points; `--l & c` /
`--l \ c` filter a bundle; `[…]` unions bundles. These select existing
geometry, never score a crease, and nest freely; the polymorphic `*` reads
as a meet when its operands are lines and a join when they are points.
*(since v0.21-dev)* `@` is retired entirely: writing to the paper always
goes through `mark`, `fold`, `reverse`, or `flatten`. A meet, a bundle read
(a name, `&`/`\`, or `[…]`), and a construction are each also valid directly as a
binding's right-hand side, matched to the sort they produce; see the RHS
note in §5.

---

## Appendix B — not yet in the language

Deferred, in rough order of likely arrival: non-flat (constructible-angle) folds ·
`rotate` · squash/sink/petal maneuvers · `unfold` ·
the 3D standing end state for `flatten` (the 3D isometry rework, ADR 0015 —
retired `standing` keyword's successor form, unnamed until it lands) ·
multi-vertex flatten (fish/bird base in one action) · boundary-vertex
flatten (squash/petal preparation) · sector-block interleaving in
`flatten`'s stacking enumeration (a sector tucked between another sector's
layers) · multi-emergent-ray flatten (more than one crease forced at a single
vertex) and the `onto <line>` exact-landing (petal) form of the odd-ray-count
solve ·
the generative solution-space selector `#{…}` (and `.{…}`/`--{…}`) and the
`stays <flap>` sugar over it (its own language-wide design pass — [issue
#46](https://github.com/tophcodes/beloch/issues/46)) · a `paper triangle`
shape (a nicer rabbit-ear demo than the
inscribed-triangle workaround) · `rabbitear` sugar `def` (intent-style,
`toward`, inferring M/V) ·
regions · parts/imports · nested `def`s and namespace chaining
(deeper cross-instance access, spelling TBD now the brackets are selectors) ·
re-export cascades · string labels in source (i18n stays
external) · `pub`/`priv` interfaces · looping primitives · module/file-level
namespacing · a dedicated render/animation engine · YR diagrams. These are not
part of the language until a slice lands and this spec is extended.

**Landed:** faces (v0.1); axiom 3 — perpendicular (v0.2); axiom 4 — projection (v0.4-dev); axiom 5 — angle
bisector (v0.3-dev); the `map … onto …` verb and the `@` fold modifier
(v0.6-dev); and *(v0.7-dev)* the **action model** — `@` fold execution, the
folded-state runtime, derived mountain/valley, the dual `creasePattern` +
`foldedForm` FOLD output, `flip`, and inline anonymous read operands
(`.a * .b` join / `--x * --y` meet — spelled `--(.a .b)` / `.(--a --b)` before
the v0.20-dev cutover). See
[ADR 0011](../decision/0011-action-model.md). Mountain/valley is *derived* from
fold actions, not a separate annotation pass. *(v0.8-dev)* axiom 6 — fold a
point onto a line with the crease through a fixed point (`map .p onto --d through
.p'`, optional `toward` for disambiguation). *(v0.9-dev)* axiom 7 — the cubic
Beloch fold (`map .p onto --d and .q onto --e`, optional `toward`); irrational
crease coordinates compared exactly (§6). *(v0.16-dev)*
`=` replaces `:` as the binding separator; read-operator RHS;
`def`/`apply`/instances with closed-scope bodies; `export` with shadow/rename
validation (cross-instance access; the earlier bracket member access was
removed in the v0.20-dev notation cutover, `BELOCH-NAMES.md`);
the uniform rebinding rule (`BELOCH-NAMES.md`). *(v0.17-dev)*
crease-segment selection — the `&` filter, projecting a crease name (a
bundle of segments) to one segment by incidence (ADR 0014). *(v0.18-dev)* fold
scope — flap-typed `moving` (point/line/`#[...]` anchor operands, ADR 0016),
`up to` for some-layers simple folds, and `@fold` along an existing material
crease. *(v0.20-dev)* `@collapse` — single-vertex flat collapse: n ≥ 4
material creases sharing one interior vertex, checked by Kawasaki, Maekawa,
and layer-order validity, with `over` for stacking ties; `standing` parses
but is not yet implemented (`BELOCH-WRITES.md`); the **notation cutover** — reads become
operators (`*` meet/join, `&` filter, `\` drop, `[]` union, the `.[] --[] #[]`
selectors), the one write was the keyword `through`, and bracket member access
retires in favor of `export` (§4.10, design doc). *(v0.21-dev)* the
**mark/fold notation cutover** — `map`/`through`/`perp` constructions become pure
reads (joining the v0.20-dev operators); the writes are the keyword verbs
`mark` (crease flat, FOLD `F`) and `fold` (crease and fold, FOLD `M`/`V`);
`@collapse` is renamed `collapse`; `@` is retired entirely from the grammar;
`U` is no longer emitted (§7).
*(v0.23-dev)* **`flatten` generalizes `collapse`, one solver pipeline** —
`collapse` is renamed `flatten`; the item list drops `and` for parenthesized
juxtaposition (`flatten (--a & .p) (--b & .q) …`); `flatten` is bindable
(`BELOCH-WRITES.md`); and, given an odd set of rays sharing a vertex, `flatten` solves for
the one emergent crease flat-foldability forces (the composed reflection of
an odd ray set is itself a reflection; its axis is the new crease),
materializes it, and folds the completed set — the swivel rabbit-ear move no
Huzita axiom constructs directly. A same-day follow-up replaced the initial
validate/derive mode split with **one pipeline**: bare elements are
solver-assigned (not defaulted to valley), `mountain`/`valley` and `over`
are hard constraints that filter the solution space, and `{toward .p}` —
now a bracketed item, not a trailing keyword, and never mandatory — selects
among survivors by a three-stage rule (position class, min-mountain canon,
rank dipole) when more than one remains. A further same-cycle follow-up
replaced `sort_ccw`'s arbitrary east origin with the **stayer** — the
material that does not move, geometric-anchored instead of guessed: fixed
by convention (the leading two elements' <180° arc) or named explicitly
with `(staying <flap>)`, which retires the reserved `standing` slot
entirely — and the fan labeling is anchored on it before layer solving
runs, rather than derived from the solved stack afterward.
*(v0.26-dev)* **layer placement**: `fold … over/under <flap>` inserts the
moved flap between layers, and the **`reverse`** verb folds inside and
outside reverse folds as two placed half-folds with derived letters (`BELOCH-WRITES.md`,
`BELOCH-WRITES.md`).

---

## References

Machine-readable entries: [`../bibliography/references.bib`](../bibliography/references.bib).
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

<a id="ref-bpr2006"></a>
**[bpr2006]** Saugata Basu, Richard Pollack, Marie-Françoise Roy. *Algorithms in
Real Algebraic Geometry.* 2nd ed. Springer, 2006.
[doi.org/10.1007/3-540-33099-2](https://doi.org/10.1007/3-540-33099-2) ·
[local PDF](../refs/bpr2006.pdf).
Separation/Cauchy bounds (§10.1–10.2); sign-at-roots certification in a real
closed field (§10.4); Rational Univariate Representation (§12.4); doubly-exponential
blowup of naive multivariate arithmetic (§12).

<a id="ref-foldformat"></a>
**[foldformat]** Erik D. Demaine, Jason S. Ku, Robert J. Lang. *FOLD File Format
Specification* (v1.2).
[github.com/edemaine/fold](https://github.com/edemaine/fold) ·
[local copy](../refs/foldformat.md).
Relevant sections: "Edge information: `edges_...`" (edge assignments) and
"Custom Properties" (the `namespace:key` convention used by `beloch:*`).
