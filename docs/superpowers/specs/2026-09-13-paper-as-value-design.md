# Paper as a value (design)

## Status

Draft for review (2026-09-13, with Toph). Replaces the fixed `paper square`
preamble of §2 with a sheet value, a named prelude, and a selector algebra for
addressing a shape's parts.

The design fixes a model that reaches further than the code this slice writes.
Section *Build boundary* says exactly which part is built now, which part is
decided but deferred, and which part stays out.

## Motivation

`paper square` is a preamble with no moving parts. Three limits follow from it:

- **The prelude is hardwired.** `.a` to `.d` and `--ab`…`--da` arrive whether the
  model wants them or not, cannot be renamed, and occupy four short names the
  model may want for its own points.
- **Shapes without four canonical corners have nowhere to go.** A circle has no
  vertex to hand out. An 18-gon has eighteen, and a model that uses two of them
  should not have to carry the other sixteen.
- **A program has one sheet.** Modular origami needs several, and the language
  has no value denoting a sheet.

The third limit is the expensive one. Its endpoint is genuine interlocking:
a flap of one sheet inside a pocket of another, represented in the model. That
endpoint depends on work that has not happened (ADR 0015), so this design fixes
the syntax and the value model it will need, and builds the part that stands on
its own today.

## Decisions

### D1: A sheet is a value, written `$$name`

A sheet is a first-class value with its own sigil. `$` is taken by instances
(§5a.3), so `$$` reads as the same idea one level up.

```
$$m1 = square
$$m2 = square with { .m = center }
```

The value denotes the sheet's identity across its whole life, the way a crease
name denotes a bundle whose cardinality changes over time (ADR 0016 §2). Folding
does not produce a new sheet value; it changes the state the existing one
denotes.

**Rejected: a sheet is a module, imported from.** `import { .a .b } from square`
reads well and reuses one mechanism for shapes and for user files. It breaks on
the second instance: two sheets of the same shape are two imports of the same
module, and nothing in the import form names them apart. Instance identity is
what modular origami needs most, so identity comes first and file-level
namespacing (Appendix B) layers on top later.

### D2: The acting sheet is ambient, and `on` switches it

Operations keep the shape they have today. The sheet they act on is ambient and
appears at a block edge:

```
on $$m1 { fold map .a onto .c }
on $$m2 { fold map .a onto .c }
```

A program is in exactly one of two modes:

| mode | declaration | acting statements |
|---|---|---|
| single-sheet | `paper <shape> [with { … }]`, first statement | at root, no `on` |
| multi-sheet | one or more `$$name = <shape> …` | inside `on` only |

Mixing the modes is an error. This keeps the ambient rule to one sentence in
each mode and leaves every existing program in the first one, unchanged.

`on` does not nest. A sheet scope containing another sheet scope is an error.

**Rejected: a sheet argument on every mutating operation** (`fold $$s --bd = …`).
Legible line by line, and it rewrites every example in the repository for a
benefit that only multi-sheet programs collect.

**Rejected: the sheet inferred from the operands.** A point would carry its
sheet, and `map .a onto .c` would recover the sheet from `.a`. It preserves the
corpus as well as D2 does and needs no new statement, but the sheet then appears
in no source line at all, and a cross-sheet mistake surfaces as an operand type
error rather than at the place where the author chose the wrong block.

### D3: Prelude names live in the sheet's namespace

Names bound by a prelude belong to the sheet. Inside `on $$s { … }` they are
visible unqualified; outside, they are not. Twenty Sonobe modules all use `.a`
with no collision.

Lifting a name into the enclosing scope reuses `export` (§5a.5) with no change
to its rules, including `as` renaming and the `!` shadow marker:

```
export { .a as .tab } $$m1
export { .c as .pocket } $$m2
```

Qualified access `$$s/.a` also exists, restricted by D6. It is a new spelling
for a concept §5a.4 kept: that section removed the bracket operators because
"the `--[…]` and `.[…]` brackets are now the join and meet selectors … which
cannot also mean 'read a member'", and Appendix B parks the successor as
"deeper cross-instance access, spelling TBD now the brackets are selectors".
Instances (`$`) keep `export` as their only access path, unchanged.

Two questions §5a.5 never had to answer, because it exports from a finished
instance while this exports from a live sheet:

- §5a.5 calls export "a pure read of already-folded geometry". A sheet keeps
  folding afterwards. For a point that is harmless, since a point is a
  time-stable identity (ADR 0016 §2). For a crease it is not: a crease name
  denotes a bundle whose cardinality grows as later folds split it (ADR 0014),
  so an exported crease name in the root scope tracks material the sheet scope
  keeps re-segmenting. Slice 2 either restricts sheet export to points or
  defines what the bundle does across the scope edge.
- Temps keep §5a.1 unchanged: `$$s/._x` is barred and `export` never copies a
  temp. In multi-sheet mode the root scope carries no acting statements, so a
  root-level temp has nothing to be temporary about and the mode rejects it.

### D4: A prelude binds names to selector results

The prelude block binds a name of the author's choosing to a part of the shape,
addressed by selector syntax. Indices are arguments to a selector rather than
part of an identifier, so nothing depends on a naming convention.

```
paper square with {
  .a = vertex 1
  .c = vertex 3
  --ab = edge 1
}
```

Every shape carries a **default prelude**. For `square` it is today's four
corners and four edges, so `paper square` keeps its current meaning exactly.

`with` **extends** the default. A prelude name that collides with a default
name is an error unless marked `!`, which is the shadow rule of §5a.5 applied
at a second site:

```
paper square with { .m = center }      ; four corners stay, .m is added
paper square with { .a! = vertex 2 }   ; deliberate override of the default .a
paper square with { .a = vertex 2 }    ; error: name exists, use `!`
```

**This amends §5a.6.** Its table carries an unconditional row, "rebinding a
corner `.a`-`.d` at root | error", written when the four corners were the only
prelude there was. The amended rule: a prelude entry is the binding site for a
prelude name, and `!` governs collisions inside a `with` block; rebinding a
prelude name anywhere after the prelude stays an error with no escape. §5a.6's
invariant that a non-temp name is bound at most once per scope is untouched,
since a prelude entry is that one binding. The amendment ships in the same
change as the implementation.

**Rejected: `with` replaces the default.** Predictable, and it makes adding one
point cost the four corners, which is the common case punished for the rare one.

**Rejected: named reusable preludes (`prelude corners { … }`).** No program has
yet written the same non-default prelude twice. Parked in `notes/ideas.md` with
that as the trigger to revisit.

### D5: Selector addressing follows the shape's symmetry group

Naming a part of a fresh sheet is an arbitrary choice, and a selector scheme is
correctly built when it absorbs the choices that are arbitrary and forces the
ones that are geometry. The dividing line is the shape's symmetry group: two
choices are the same choice when a symmetry of the shape carries one onto the
other.

**Finite group, so ordinal selectors.** The regular $n$-gon has the dihedral
group $D_n$ with $2n$ elements. Rotating a square by 90° leaves it identical
while moving every corner to its neighbour's place, so *which* corner is called
`vertex 1` is absorbed. No symmetry turns an adjacent pair into an opposite
pair, so the *difference* of two indices is geometry and is forced. Ordinals
divide the two exactly at that line.

**Continuous group, so `free`.** The circle has $O(2)$, one symmetry per angle.
There is no countable set of parts to number, and a numbering would assert a
first boundary point and a next one, neither of which exists. What survives is
that the first boundary point is arbitrary, which is what §4.3a already means by
`free`: exact value, position not load-bearing. Placing it consumes the rotation
and leaves the reflection, so a second boundary point carries real geometry and
takes a parameter measured from the first.

The spelling borrows §4.3a's `free`, and it extends that form instead of
reusing it. Three differences have to be written into §4.3a before the boundary
form can be built:

- **`from` becomes optional.** §4.3a requires it: "`from .x` is required: `.x`
  must be exactly one of the bundle's two furthest-out points". A closed
  boundary has no furthest-out pair, and the first point needs no anchor
  because the symmetry absorbs it.
- **The domain is the sheet boundary.** `boundary` is no `line_operand`, so it
  is a selector keyword with its own resolution rather than a bundle.
- **`t` measures arc length.** §4.3a interpolates linearly: "the seed point is
  `P0 + t·(P1 − P0)`". A quarter circumference is a different point from a
  quarter chord, so one surface syntax would compute two functions. Either
  §4.3a's `t` gets a per-domain definition, or the boundary form takes its own
  parameter keyword.

```
$$c = circle with {
  .o = center
  .p = free on boundary                   ; arbitrary, absorbed by the symmetry
  .q = free on boundary from .p at 1/4    ; a quarter circumference along
}
```

Selectors, with the shapes they are defined for:

| selector | meaning | shapes |
|---|---|---|
| `vertex n` | the $n$-th vertex, counter-clockwise from the shape's origin vertex, 1-based | polygons |
| `edge n` | the edge from `vertex n` to `vertex n+1`, wrapping | polygons |
| `center` | the centroid | all |
| `free on boundary [from .p] [at t]` | a boundary point, position not load-bearing | shapes with a continuous boundary |

`square`'s origin vertex is $(0,0)$, so `vertex 1` is today's `.a` and `edge 1`
is today's `--ab`. An index outside $[1, n]$ is an error naming the shape's
vertex count.

`center` is a selector rather than a construction because §4.3 requires material
operands for a meet: recovering the square's centre as the diagonals' crossing
means marking both diagonals first, which scores creases the model did not ask
for.

**On exactness and reach.** A boundary point at $p/q$ of the circumference with
$\gcd(p,q) = 1$ has coordinates $\cos(2\pi p/q)$ and $\sin(2\pi p/q)$, algebraic
of degree $\varphi(q)/2$ over $\mathbb{Q}$, so the qqbar kernel (ADR 0013) holds
it exactly. The degree grows with $\varphi(q)$, which is the degree-budget
concern in `notes/ideas.md` reached through the prelude.

Reach is a separate question from exactness, and it moves. Single folds solve
cubics, so the single-fold-constructible regular $n$-gons are
$n = 2^r 3^s p_1 \cdots p_k$ with distinct Pierpont primes $p = 2^m 3^n + 1$
[lucero2018hendecagon, §1]. The smallest $n$ outside that family is 11, whose
construction needs a quintic [lucero2018hendecagon, §1]. Multifold reaches it:
Alperin and Lang show degree $n$ is solvable by $n-2$ simultaneous folds
[alperin2006, §5], and Nishimura's two-fold operation `AL4a6ab` brings an
arbitrary quintic down to two [lucero2018quintic, §1, Def. 1]. Nishimura's paper
is not in `refs/`; the claim is cited through Lucero.

The consequence for this design: **`free` placement is never gated on
constructibility.** §4.3a already records provenance rather than a construction
claim, and that reading carries to the boundary unchanged. Gating it would move
the language's boundary every time `packages/multifold` (ADR 0020) learns
something.

### D6: Two layers: folding and assembly

The fold algebra is intra-sheet and computes in paper space. §4.3 is explicit
that the language has no table-space point values, because paper is opaque and
a crossing visible only through overlapping layers is not a crossing. Two sheets
share no paper space; they share a table. A cross-sheet operand therefore has no
meaning in a fold statement, and the type rule says so:

```
on $$m1 { fold map .a onto $$m2/.c }
; error: map: $$m2/.c is not a point of $$m1
```

Cross-sheet operands are legal only in **assembly statements**, a second layer
of verbs over rigid placement and interlocking. The layer's vocabulary is
deferred (see *Build boundary*); what this design fixes is that qualified access
exists, that it is rejected everywhere in the fold algebra, and that the
rejection is a static check rather than a geometric failure at run time.

### D7: Assembly yields a body, and the body is what gets checked

Once two sheets are interlocked, per-sheet validity answers the wrong question.
Sheet A's self-intersection check passes while A passes through B, and the
layer-order, seating and flatten checks (§4.9, checks 6 to 14) are all written per
sheet.

Assembly is therefore a constructor: it consumes sheets and yields a body, and
the body is itself an `on` target. Validity inside `on $$cube` covers the whole
assembly, and the members are no longer foldable on their own.

```
$$cube = assemble { insert $$m1/tab into $$m2/pocket }

on $$cube { fold … }   ; locking fold, checked against the assembly
on $$m1   { fold … }   ; error: $$m1 is part of $$cube
```

The checked domain is visible in the source and there is no silent widening.

**Rejected: assembly seals its members.** Cheapest, and it costs the locking
fold after insertion, which is the last step of many real models.

**Rejected: assembly records constraints that later folds must preserve.**
Lighter than a full composite, and incomplete in a way that cannot be fixed
incrementally: a fold that sweeps through B without disturbing a recorded
constraint passes.

## Surface syntax

Grammar delta against Appendix A:

```
program        := single_program | multi_program
single_program := "paper" shape_expr stmt*
multi_program  := sheet_stmt+ ( sheet_stmt | on_stmt | export_stmt | def_stmt )*

sheet_stmt     := SHEET_NAME "=" shape_expr
on_stmt        := "on" SHEET_NAME "{" on_body* "}"
on_body        := stmt minus ( def_stmt | on_stmt )      ; §5a.2 keeps def top-level
shape_expr     := shape [ "with" "{" prelude_entry+ "}" ]
shape          := "square"                                ; the shape table grows
prelude_entry  := ( POINT_NAME | CREASE_NAME ) "!"? "=" selector
selector       := "vertex" NAT
                | "edge" NAT
                | "center"
                | "free" "on" "boundary" [ "from" POINT_NAME ] [ "at" RATIONAL ]

export_stmt    := "export" ( "{" export_entry+ "}" )? ( INSTANCE_NAME | SHEET_NAME )
SHEET_NAME     := "$$" ident
```

Qualified access `SHEET_NAME "/" ( POINT_NAME | CREASE_NAME )` is accepted by the
grammar and rejected by the type rule everywhere except assembly statements
(D6).

`def` needs no change, and `on` stays out of a `def` body: a body applied
inside `on` would otherwise nest one sheet scope in another, which D2 forbids.
A body inherits the ambient sheet from its `apply` site, which reproduces
today's semantics exactly, and `on $$m { apply sonobe(…) }` covers the modular
case without sheet parameters. §5a.2's rule that a body
cannot see `.a` to `.d` gains a simpler reading under D3: a body has no prelude
names because it is not the sheet's scope.

## Build boundary

**Built in this slice.** The single-sheet form and everything the prelude needs:
`paper <shape> [with { … }]`, the default prelude for `square`, the `!` shadow
rule, and the `vertex` / `edge` / `center` selectors. This addresses the
hardwired prelude on its own, without a second sheet anywhere.

One prerequisite comes first. The sheet boundary is currently keyed by prelude
name: `Ctx` holds `corners` and represents a boundary edge as
`Edge of string * string`, "a paper boundary edge, named by its two corners;
resolves live … through the current corner positions". A prelude that rebinds
`.a` therefore moves the default `--ab` with it. The boundary has to become
shape-derived, with prelude names as labels onto it, before any prelude entry
may shadow a default.

**Fixed here, built when a driver exists.** `$$` sheet values, `on`, per-sheet
namespaces, `export` from a sheet, and the two program modes. The syntax is
settled and the output is open. `file_frames` cannot carry the sheets: §7
allocates it to the temporal axis, "one `foldedForm` frame per fold … in
program order (the numeric folding sequence)", and fixes frame 0 as "always the
final, cumulative crease pattern", one planar graph that N sheets cannot share.
Multi-sheet output needs its own representation decision, and §7's
instance-qualified crease naming (`"p1.pq"` in `beloch:edges`) needs a
sheet-qualified counterpart in the same move. Until both exist, building
`$$`/`on` yields programs whose result cannot be written out.

**Out of scope.** The assembly layer (D6, D7) and its verbs; anything requiring
non-flat states, which is the 3D isometry rework of ADR 0015 and a precondition
for modular origami of any kind, since a Sonobe cube is not a flat folded state;
shapes beyond `square`. Adding `triangle` or `ngon n` should be a shape-table
entry and nothing else, which is how D5 gets checked. The circle costs more
than a table entry: §4.6 defines a face as "a convex polygon in paper
coordinates" and §7 emits "each face is one polygon", so a disc needs
arc-bounded faces in the model and arcs in the clipping kernel, which clips and
overlaps polygons only. That is its own slice, and D5's boundary selectors are
a sketch until it happens. `spec/MODEL.md`, in flight from parallel work, is
where the sheet-as-simple-polygon statement should live once it lands.

## Acceptance

- Every file under `examples/` and `packages/core/tests/cases/` evaluates to
  byte-identical FOLD output before and after the change, with no edits to any
  `.bel` source.
- `paper square with { .m = center }` binds `.m` and keeps `.a` to `.d`.
- `paper square with { .a = vertex 2 }` fails with ``name exists, use `!` ``, and
  `paper square with { .a! = vertex 2 }` succeeds and rebinds `.a` to $(1,0)$.
- `paper square with { .x! = vertex 2 }` fails with ``nothing to shadow, remove `!` ``.
- `paper square with { .e = vertex 5 }` fails naming the square's vertex count.
- `.m = center` on the square yields exactly $(1/2, 1/2)$ and scores no crease:
  the FOLD output has the same edge set as the same program without the entry.
- `paper square with { .a! = vertex 2 }` emits the same four boundary edges as
  `paper square`. This is the criterion the boundary prerequisite above exists
  for, and it fails against today's name-keyed `Ctx.Edge`.
- `eval.ml` stays under 900 lines, so ADR 0018's own check passes. It is at 881
  today, which the slice has to plan for rather than discover.

## Constraints carried from existing decisions

- **§4.3, v0.19-dev**: no table-space point values. This is what forces the
  two-layer split in D6 rather than a general cross-sheet operand.
- **ADR 0015**: flat folded states only. Modular origami needs the 3D rework
  first. Nothing in this design may assume it has landed.
- **ADR 0016**: bindable values are time-stable identities. A sheet value
  qualifies; a selector result is resolved at prelude time into an ordinary
  point or line, and no selector is stored.
- **ADR 0018**: the five-module core, `Ctx → Resolve → { Axiom, Flatten_solve }
  → Eval`, acyclic. The shape table stays in `Ctx`, which already owns
  `corners`; `Resolve` reads it, since ADR 0018 gives `Resolve` the job of
  turning "names and selectors into geometry". Putting the table in `Resolve`
  would invert that edge. The statement handler lands in `Eval` under "one
  named top-level function per statement kind", against a 19-line budget on the
  record's own check.
- **§5a.6**: rebinding rules. D4 amends the corner row and leaves the
  once-per-scope invariant intact; the amendment ships with the code.
- **§6, exactness**: the normative requirement is met, since ADR 0013's qqbar
  backend represents any algebraic degree exactly. §6's informational degree
  paragraph is written per axiom and stops at the cubic tower, so a boundary
  selector introducing degree $\varphi(q)/2$ from a declaration needs a
  paragraph there, and it falls outside ADR 0013's degree-3 `Field` fast path.
- **ADR 0019**: attribution propagates into every export without loss. A
  multi-sheet model by several designers has no per-sheet provenance slot under
  one `file_author`, and the annotation block that carries file meta today sits
  "before the first fold statement". Slice 2 has to say where a sheet's
  attribution goes.
- **ADR 0020**: multifold is a sibling library and core never depends on it.
  D5's reach discussion is context for the design and creates no dependency.
