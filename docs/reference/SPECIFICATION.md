# Beloch — Language Specification

This document is being dissolved into the reference documents beside it
([[decision/0032]]): the model, the language and the output format. A section
that has moved is gone from it. What remains, the grammar sketch of Appendix A
and the list of what the language does not have yet in Appendix B, is
authoritative for the surface syntax until it moves, never for the meaning.

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
`U` is no longer emitted (`FOLD.md`).
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
