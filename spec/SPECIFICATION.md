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

Current version: **v0.27-dev** (paper-incidence filter for axioms 6 and 7:
a candidate crease that cuts no face is dropped before the ambiguity check,
the way axiom 5 already does it (§4.5); a single survivor is taken silently
even when `toward` is written, `toward` selects among the survivors only, and
an empty survivor list is its own error, distinct from *out of reach*);
**v0.26-dev** (layer placement and the reverse fold:
`fold … over/under <flap>` splices the moved block into the stack beside a
named flap; `reverse` runs an inside or outside reverse fold as two placed
half-folds over one line; both derive their crease letters from the finished
stack; see
[`docs/superpowers/specs/2026-09-10-reverse-fold-and-layer-placement-design.md`](../docs/superpowers/specs/2026-09-10-reverse-fold-and-layer-placement-design.md));
**v0.25-dev** (free point on a line — 1-DOF reference point
along a line's material bundle; `.p = free on --l from .x at <rational>`, `at`
optional (default `t = 1/2`); `free` is provenance, not a kernel relaxation —
the result is an ordinary exact point; `beloch:free` FOLD emission, a
forward-compat hook for a future renderer slider; see
[`docs/superpowers/specs/2026-07-22-free-point-on-line-design.md`](../docs/superpowers/specs/2026-07-22-free-point-on-line-design.md));
**v0.24-dev** (default fold scope — no `moving`/`up to` folds
the **outside-contiguous prefix** of the layer order down to and including the
anchor flap, not every layer on the anchor's side; a point on a crease shared
by several flaps seeds the whole contiguous run; `moving` now names the
**deepest** flap of that prefix; a bare axiom-5 line-onto-line fold with no
`moving` and no implied point still falls back to the all-layers set;
`up to` is unchanged as the interim way to fold past the anchor flap; see
[`notes/2026-07-20-default-fold-scope.md`](../notes/2026-07-20-default-fold-scope.md));
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
item list drops `and` for parenthesised juxtaposition (`flatten (--a & .p)
(--b & .q) …`); `flatten` is bindable, so an emergent crease — otherwise
unconstructible — gets a name, and its tip point becomes selectable. See
[`docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md`](../docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md),
[`docs/superpowers/specs/2026-07-16-flatten-derive-v2-design.md`](../docs/superpowers/specs/2026-07-16-flatten-derive-v2-design.md),
and
[`docs/superpowers/specs/2026-07-17-flatten-staying-design.md`](../docs/superpowers/specs/2026-07-17-flatten-staying-design.md));
**v0.22-dev** (**partial marks — the pinch** — `mark
<motion> between .a .b` / `at .p` clip a mark's extent; an extent that ends
mid-face is a non-subdividing *record* — splits no rays, can dangle mid-face —
instead of subdividing everything it crosses, discriminated by
boundary-incidence rather than which form was written; `mark … valley|mountain`
sets a crease-pattern-frame M/V *intent* on records the same way it does on
subdividing marks; `#[...]` picks the flap a record lands on; `mark --l =
<motion> [extent] [dir] [#[...]]` combines bind-and-write; records emit into a
`beloch:marks` FOLD custom field and `render-svg` draws them as a dashed
reference line or short tick, distinct from live `F`/`M`/`V` edges; see
[`docs/superpowers/specs/2026-07-10-mark-fold-slice2-design.md`](../docs/superpowers/specs/2026-07-10-mark-fold-slice2-design.md));
**v0.21-dev** (**mark/fold notation** — `map`/`through`/`perp`
motions are pure reads: bindable line values, touching nothing; the writes are
the keyword verbs **`mark`** (crease and leave flat, FOLD `F`) and **`fold`**
(crease and fold, FOLD `M`/`V`), alongside `collapse` and `flip`; `@` is
retired entirely from the grammar — this completes the read/write law begun
in the v0.20-dev cutover (through was its one write; now it too is a read);
see
[`docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`](../docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md));
**v0.20-dev** (`@collapse` — single-vertex collapse: n ≥ 4
material creases sharing one interior vertex fold straight to the flat end
state in one step — rabbit ear, waterbomb — checked by Kawasaki/Maekawa/local
validity, `over` disambiguates the layer order, `standing` is reserved
syntax the evaluator does not yet implement; **notation cutover** — reads are
operators (meet `*`, filter `&`, drop `\`, union `[]`, the incident-to-all
selectors `.[] --[] #[]`), the one write was the keyword `through`; see
[`docs/superpowers/specs/2026-07-08-notation-by-state-change-design.md`](../docs/superpowers/specs/2026-07-08-notation-by-state-change-design.md));
**v0.19-dev** (material crossings live in paper space, on the marks; no table-space point values; axiom 5 `toward` is a fold direction, not a sector, with a paper-incidence filter for the omitted case and a derived `moving`); **v0.18-dev** (fold scope — flap-typed `moving`, `up to` for some-layers simple folds, `@fold` along material creases); **v0.17-dev** (crease-segment selection — the `&` filter: a crease name is a bundle, projected to one segment by incidence); **v0.16-dev** (`def`/`apply`/instances, qualified access, `export`; `=` binding separator); **v0.9-dev** (axiom 7 — cubic Beloch fold, two points each onto a line); **v0.8-dev** (axiom 6 — fold a point onto a line, crease through a fixed point); **v0.4-dev** (axiom 4 — project a point onto a line); **v0.3-dev** (axiom 5 — angle bisector); **v0.2** (axiom 3 — perpendicular through a point); **v0.1** (faces); **v0.0** (minimal core).

---

## 1. Overview *(since v0.0)*

Beloch is a declarative language for origami. A `.bel` program is **evaluated**
(not compiled to an executable) into a data artifact describing a paper state,
emitted as FOLD. See [ADR 0007](../decisions/0007-evaluator-not-compiler.md).

The language is built on the Huzita-Justin fold axioms
[[justin1986]](#ref-justin1986), using them as primitive operations. *(since
v0.7-dev)* It is an **action model**: a program is an imperative sequence of
marking/folding actions on a stateful sheet (§4.6). The axioms (`map`,
`through`, `perp`) locate *where* a crease could go — a pure read; `mark` and
`fold` actually act on the paper (§4.10). A program evaluates to a folded
state, emitted as a dual-frame FOLD file — the flat **crease pattern** and the
**folded form** (§7). The flat crease pattern (a program with no `fold`
actions) is the special case.
See [ADR 0011](../decisions/0011-action-model.md).

### A note on axiom numbering

Beloch uses the **classic Huzita-Justin numbering** [[justin1986]](#ref-justin1986)
§8.1 — the numbering used by most origami-*math* references. It is chosen
deliberately: Justin ordered the seven axioms **by algebraic power**, so the
axiom number is also the rung on the number-kernel ladder (ℚ → √ → ∛; see §3).
Two rival schemes exist and **do not** line up with ours; the table below is the
authoritative cross-map so they are never re-conflated.

| Beloch / Justin | The fold | Degree | Sols | Huzita-Hatori (Wikipedia) | Hull §1.5 |
|:---:|---|:---:|:---:|:---:|:---:|
| **①** | line through two points | 1 | 1 | 1 | O1 |
| **②** | one point onto another (⟂ bisector) | 1 | 1 | 2 | O3 |
| **③** | perpendicular through a point | 1 | 1,2 | 4 | O5 |
| **④** | project a point onto a line (∥ another) | 1 | 0,1 | 7 | O8 |
| **⑤** | one line onto another (angle bisector) | 2 | 1,2 | 3 | O4 |
| **⑥** | point onto line, crease through a point | 2 | 0,1,2 | 5 | O6 |
| **⑦** | two points each onto a line (cubic Beloch fold) | 3 | 0,1,2,3 | 6 | O7 |
| — | *locate line ∩ line (not a fold)* | — | — | — | O2 |

Three traps this table defuses:

- **The Wikipedia clash.** Huzita-Hatori numbers the **cubic fold as axiom 6**;
  Beloch numbers it **7**. Anyone cross-referencing Wikipedia will trip here.
  When this spec says "axiom 7" it means the cubic Beloch fold — Wikipedia's O6.
- **Hull's shift.** Hull inserts a non-fold ("locate the intersection of two
  lines") as his **O2** and reorders 3/4/5, so his numbering matches *neither*
  other scheme. When this spec writes "axiom 2" it means point-onto-point =
  Hull's **O3**, and the angle bisector is **axiom 5** (Hull's O4), *not* axiom 3.
- **Degree, not position, drives the kernel.** Axioms ①–④ are degree 1 and stay
  in ℚ; **⑤** (bisector) is the first to require square roots (leaves ℚ); **⑦** is
  the first to require cube roots. Justin's own §8.1: ①–④ give dyadic rationals,
  ①–⑤ the field K₁, ①–⑥ = ruler-and-compass (K₂), ①–⑦ the larger K₃.

This discrepancy set is also recorded in [antipatterns.md](../antipatterns.md).

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
  construction (§4.3), or *(since v0.25-dev)* a **free point on a line**
  (§4.3a) — a 1-DOF reference point whose position is not load-bearing, but
  whose value is an ordinary exact point like any other (§6).
- **Crease / line** — `--name`. The geometric value of a fold: an (infinite)
  line. On output it appears as the edges of the folded state's faces (§7);
  `mark`/`fold` (§4.6) act on the paper with it.

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

### 4.3 Meet — where two lines cross: `*` and `.[…]` *(since v0.0)*

```
--c1 * --c2        ; the meet point   ≡  .[--c1 --c2]
```

The point where the two creases' **material marks** cross on the sheet. Meet is
a **read** (§4.10): the operator names existing geometry — a crossing — and
scores nothing. `*` is the binary sugar; the n-ary form is the bracket `.[l+]`,
the point incident to *all* the listed lines (concurrent lines → their common
point), so `--x * --y` ≡ `.[--x --y]`. This is a point *construction*, not a
fold axiom, in the classic numbering; it is Hull's basic operation O2
[[hull2020]](#ref-hull2020) §1.5 (O2). A pure value binding (`--l = <motion>`,
§4.10) has no mark to cross — meet needs **material** operands, so a line used
only to locate a crossing still has to be `mark`ed (a non-subdividing
`between`/`at` record, §4.6, is enough; it need not subdivide anything).

*(since v0.19-dev)* The crossing is computed in **paper space**: a crease is a
scar in the material, and two scars cross (or don't) independently of how the
sheet happens to be folded. There are no table-space point values in the
language — paper is opaque, so a "crossing" seen only because layers overlap on
the table is not a crossing at all: no layer shows both marks. (This replaces
the v0.7-dev rule that resolved a table-space intersection to the topmost
covering layer, `Q2-B`.) Consequences:

- Each operand must carry a **single material line**. A crease bent on the
  table by later folds still qualifies bare — its scar is one straight line in
  the paper. A crease scored through several layers marks **different lines on
  different layers** (mirror images) and must be projected to one segment with
  `&` (§4.8).
- The crossing must lie **on the marks**: for each crease operand, on one of
  its segments (endpoints count). Two supporting lines meeting beyond the
  marks' extent is an error — there is nothing to see there on the sheet.
- A paper-edge operand (a prelude edge `--ab`, or a `--[.a .b]` selection) is a
  boundary line; for it the crossing must merely lie on the paper. The same
  holds for a reference-only boundary crease (one that cut no face).
- The meet is therefore **fold-state-independent**: folding never moves a mark
  within the sheet. Only name resolution (the `&` filter) reads the folded
  state.

**Errors:**

- the two lines are **parallel** (no intersection);
- a crease operand marks **different lines on different layers** (select a
  segment with `&`);
- the marks **do not reach** the crossing (supporting lines meet beyond a
  crease's segments);
- the intersection is **off the paper** (paper-edge / boundary-reference
  operands; exact point-in-polygon test; the boundary counts as on the paper).

### 4.3a Free point on a line — `free on … from … at …` *(since v0.25-dev)*

```
.p = free on --l from .x
.p = free on --l from .x at 2/5
```

A **free point** is a reference point placed at a rational parameter `t` along
`--l`'s material — "put a point roughly here on this line" without an explicit
construction. `free` records *provenance* (how the point was placed, and that
its exact position is not load-bearing), not a relaxation of the kernel: the
result is an ordinary **exact** point, usable anywhere a point operand is
accepted — `through .p`, `map … onto … at .p`, `mark … at .p`, perpendicular
axioms, and so on (§6, all geometry is exact).

**Domain.** The point lies on `--l`'s material in the current paper, taken as
a single bundle: its two **furthest-out points** are the parameter endpoints,
bridging any gaps between chords. For a plain constructed (unmarked) line, the
bundle is simply where `--l` crosses the paper square. `t ∈ [0, 1]`; the seed
point is `P0 + t·(P1 − P0)`, exact for rational `t`.

**Orientation.** `from .x` is required: `.x` must be exactly one of the
bundle's two furthest-out points, and fixes that end as `t = 0` — the opposite
point is `t = 1`. The match is by exact incidence, not nearest-point. (In this
version the bundle spans *all* of `--l`'s material as one furthest-out pair;
genuinely disjoint re-entrant material is bridged, not separately selectable.)

**Seed value.** `at <rational>` is optional; the default is `t = 1/2`, the
bundle's midpoint. `<rational>` is a rational literal (`2/5`, `3`, …).

```
paper square
--diag = through .a .c
.m = free on --diag from .a         ; midpoint, (1/2, 1/2)
.q = free on --diag from .a at 1/4  ; (1/4, 1/4)
```

**Errors:**

- `--l` has no material on the paper — "the line has no material on the
  paper";
- `.x` is not one of the bundle's furthest-out points — "the anchor is not an
  endpoint of the line's material";
- `t` outside `[0, 1]` — "t is out of range (must be between 0 and 1)".

**Output.** Every free point emits a `beloch:free` custom property (§7) — a
forward-compatibility hook for a future renderer slider over `[P0, P1]`; no
renderer consumes it in this version.

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
map --l1 onto --l2
map --l1 onto --l2 toward .p
```

The fold placing line `--l1` onto line `--l2`: the **angle bisector**
[[justin1986]](#ref-justin1986) §8.1 (operation ⑤), [[hull2020]](#ref-hull2020)
§1.5 (O4 in Hull's numbering; see §1). Two intersecting lines have **two**
bisectors, perpendicular to each other. Two **parallel** lines have a single
**midline**, and `toward` is ignored (unchanged: a midline needs no selector).

**Intersecting, `toward` omitted — paper-incidence filter.** *(since
v0.19-dev)* A bisector is not a fold if it never touches the sheet — it is a
construction line on the abstract plane with nothing to crease. Beloch clips
each candidate to the paper and keeps only the candidates that cut through
some face's interior — a line grazing an edge or corner creases nothing (ADR
0014: a crease is a bundle of segments; a candidate with an empty bundle
creases nothing):

- **one candidate survives** — taken silently, no `toward` needed;
- **two survive** — genuinely ambiguous (e.g. diagonal onto diagonal: both
  midlines cross the interior) — `toward` is required;
- **none survive** — no fold exists.

[[justin1986]](#ref-justin1986) §8.1 frames the elementary operations as
*faire un pli puis déplier* — "make a fold, then unfold": a pli that creases
nothing is not one. The kite base is the motivating case: folding an edge onto
the long diagonal has one candidate bisector crossing the paper's interior and
one meeting it only at a corner point (zero-length incidence):

```
mark --ac = through .a .c
fold map --da onto --ac   ; one candidate has zero paper incidence — the other is taken silently
```

(worked through in `examples/bases/kite.bel`)

**Intersecting, `toward X` given — direction, not sector.** *(since
v0.19-dev)* `--l1` divides the sheet into two sides; `X` names the **target
side**. Beloch picks the candidate bisector `b` such that reflecting the
**swinging material** of `--l1` — its ADR-0014 segments, clipped to the paper
— across `b` lands it on `X`'s side of `--l1`. This needs to know *which*
material swings, so `toward` couples to fold scope (§4.6), not to bisector
geometry alone. `X` may be any point off `--l1`, including a point on `--l2`
(now legal). `X` **on `--l1`** is an error: `toward` names where the fold
*goes*, not where it comes from.

The kite again, this time with `toward` naming a corner that neither the old
sector reading nor a nearest-bisector reading would pick correctly — the
rejected candidate is both in that corner's angular sector *and* the
angularly closer of the two:

```
fold map --da onto --ac toward .b
```

**The straddle case.** If the crossing point lies in the **interior** of
`--l1`'s material (not at an endpoint — e.g. diagonal onto diagonal, crossing
at the sheet's center), the two candidates swing *different* halves of
`--l1`, and both send their half to `X`'s side — `toward X` alone cannot
break the tie. `moving` (§4.6) can, since it names which half swings:

```
mark --ac = through .a .c
mark --bd = through .b .d
fold map --ac onto --bd toward .b moving .c
```

(`examples/syntax/bisect-straddle.bel`) Without `moving` — or with a `moving`
point that sits in both candidates' halves — the straddle is a hard error.
This is not a regression: sector semantics (the corners lie exactly on the
bisectors here) and nearest-bisector semantics (the corners are equidistant)
both fail on this same configuration too.

**`moving` on axiom-5 folds is now optional.** *(since v0.19-dev)* `fold map
--l1 onto --l2` derives its anchor from `--l1`'s own swinging material — the side
of the (chosen) axis that material sits on — the same way a map fold on
points implies the anchor from the moved point (§4.6). `moving` still
overrides it, and is still required to break a straddle or to scope an
`up to` range.

**Errors:**

- the two lines are the **same line** ("lines are identical");
- intersecting, `toward` omitted, both surviving candidates land on the paper
  — ambiguous ("map --l1 onto --l2 is ambiguous: both bisectors land on the
  paper; add `toward .p` to pick the direction");
- intersecting, `toward` omitted, no candidate lands on the paper ("map --l1
  onto --l2: neither bisector lands on the paper — no fold to make");
- `toward .p` names a point **on `--l1`** ("`toward .p` lies on --l1; `toward`
  names where the fold goes — pick a point off --l1");
- `toward` given, no candidate moves the swinging material that way ("no fold
  of --l1 onto --l2 moves its material toward .p"; with an explicit
  `moving .c` anchor, "no fold of --l1 onto --l2 moves .c toward .p");
- the straddle case, both candidates viable ("map --l1 onto --l2 toward .p is
  ambiguous: --l1 straddles the crossing, so both bisectors move material
  toward .p"), extended with a fix-it clause — "select the swinging segment
  of --l1 with `&`" for a bind, "add `moving` to pick the swinging flap" for
  a fold, or, when an explicit `moving` anchor still sits in both flaps,
  "anchor with a point in only one flap";
- a fold whose `--l1` has no material on the paper at all ("--l1 has no
  material on the paper to fold"), or (no `toward`, no explicit `moving`)
  whose material straddles the axis ("--l1 straddles the fold line; add
  `moving` to pick the swinging flap").

This is the first axiom whose result leaves ℚ — the bisector of two rational
lines is generally irrational (slope `√2−1` for `y=0` and `y=x`). Results are
therefore reals beyond ℚ, but equality, parallelism, and on-paper tests stay
**exact** (§6).

*(since v0.6-dev: verb is `map … onto …`; was `bisect …`.)*
*(since v0.19-dev: `toward` is a direction, not a sector; paper-incidence
filter for the omitted case; `moving` is derived, not required.)*

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
only. Cube roots do not arise here; they first appear at axiom 7 (§4.5c). See
"A note on axiom numbering" in §1.

`through` is the same verb as in axiom 3 (`perp --l through .p`): the crease
passes through the named point. `toward` here is **metric** — it picks the
landing nearest `.x` — and *(since v0.19-dev)* that is unaffected by axiom 5's
`toward`, which now names a target direction rather than a proximity (§4.5);
whether axioms 6/7 get the same direction reading is a separate, unstarted
pass.

**Paper-incidence filter.** *(since v0.27-dev)* A candidate crease that never
touches the sheet, or touches it at a single point, creases nothing and is no
fold. Beloch clips each candidate to the paper and keeps only the candidates
that cut through some face's interior, the filter axiom 5 applies to its
bisectors (§4.5). The filter runs **before** the ambiguity check:

- **one candidate survives**: taken silently. A `toward` written anyway is
  redundant and is ignored, never an error;
- **two survive**: genuinely ambiguous, and `toward` is required. It picks the
  landing nearest `.x` among the survivors;
- **none survive**: no fold exists. This is distinct from *out of reach*, where
  the circle misses `--d` and there is no candidate to begin with.

The bird base's kite crease is the motivating case: `map .sr onto --mid through
.c` on the preliminary base has two solutions, and the outward one is a line
meeting the folded base only at `.c`, so the filter takes the inward one on its
own (`examples/bases/bird-base.bel`).

Errors: the lines/points being out of reach (`dist(p',D) > |p'p|`) raises *out of
reach*; two surviving solutions without `toward` raises an ambiguity error
naming the selector ("two folds place .p onto --d through .p', both landing on
the paper; add 'toward .x'"); no surviving solution raises "map .p onto --d
through .p': no crease lands on the paper — no fold to make"; `.p` and `.p'`
being the same point raises *no fold exists*. When `.p` already lies on `--d`,
the identity landing is dropped and the mirror landing gives the crease.

### 4.5c Axiom 7 — cubic Beloch fold (two points, two lines) *(since v0.9-dev)*

Justin operation ⑦: simultaneously fold point `.p` onto line `--d` **and** point
`.q` onto line `--e`, with a single straight crease.

```
map .p onto --d and .q onto --e              # 1 or 3 solutions; error if ambiguous
map .p onto --d and .q onto --e toward .x    # pick the solution whose first folded
                                             # point lands nearest .x (exact)
```

**Geometry.** Each constraint (fold `.p` onto `--d`) traces a parabola with focus
`.p` and directrix `--d`; the crease must be a common tangent to both parabolas.
Common tangents satisfy a cubic — the *landing-parameter* polynomial in the
foot-on-`--d` parameter — with up to three real solutions, hence up to three
creases [[justin1986]](#ref-justin1986) §2, [[hull2020]](#ref-hull2020) §2.3–2.4.
This is the operation that **doubles the cube and trisects angles**
[[hull2020]](#ref-hull2020) §2.3 — it is strictly more powerful than
ruler-and-compass. The crease is in general irrational (a real cube root); its
coordinates must still be compared exactly (§6).

**Paper-incidence filter.** *(since v0.27-dev)* A common tangent that cuts no
face of the sheet creases nothing and is no fold, so Beloch drops it before
counting solutions, exactly as it does for the bisectors of axiom 5 (§4.5) and
the two creases of axiom 6 (§4.5b). Everything below counts **survivors** of
that filter rather than raw roots of the cubic.

**Solutions and `toward`.** When more than one solution survives the filter,
`toward` is required; with a single survivor it is ignored, and writing it
anyway is allowed. `toward .x` picks the surviving solution whose first folded
point (the image of `.p` on `--d`) lands nearest `.x`, measured by exact
squared distance. This is the same metric proximity selector as axiom 6, and
*(since v0.19-dev)* it is unaffected by axiom 5's `toward`, which now names a
direction rather than a proximity (§4.5); a direction reading for axioms 6/7
remains a separate, unstarted pass.

**Errors:**

- `.q` **already lies on `--e`** — the second constraint is vacuous; the fold
  reduces to axiom 6 or axiom 4 depending on the remaining constraint. Beloch
  raises an error naming the appropriate axiom.
- `--d` and `--e` are **parallel** — the cubic degenerates and the system is
  ill-defined; Beloch raises an error.
- Two or more **surviving** solutions and **`toward` omitted** — ambiguous;
  Beloch raises an ambiguity error naming the selector ("N folds place .p onto
  --d and .q onto --e, all landing on the paper; add 'toward .x'").
- **No surviving solution**: the cubic has real roots, and every one of them
  misses the paper ("map .p onto --d and .q onto --e: no crease lands on the
  paper — no fold to make"). Distinct from *out of reach*, where there is no
  common tangent at all.

**Provenance.** Each crease edge carries `"axiom": "axiom7"` in `beloch:edges`.

**Number theory.** The landing-parameter cubic generically has no rational root,
so its real roots are irrational — they live in `ℚ(α)` for an algebraic `α` of
degree 3. All coordinates of one axiom-7 crease lie in that same `ℚ(α)`. See §6.

### 4.6 Marking and folding: `mark` / `fold` *(since v0.7-dev; `mark`/`fold` verbs since v0.21-dev; partial marks since v0.22-dev)*

A motion (`map`/`through`/`perp`, §4.1–§4.5c) is a pure read: it computes a
line and touches nothing. `--l = map .a onto .b` binds a value; on its own it
scores nothing. Acting on the paper needs one of two disposition keywords
(§4.10):

- **`mark`** — crease the line and leave the sheet **flat**: subdivides the
  layers it crosses into flaps, but moves nothing. Emits FOLD `F` — present,
  not folded (§7) — carrying an M/V *intent* in the crease-pattern frame.
- **`fold`** — crease the line **and fold it**: subdivides and moves layers.
  Emits FOLD `M`/`V` in both frames.

```
mark map .a onto .b                   ; crease, stays flat (valley intent)
mark --d = through .a .c              ; named crease, stays flat
fold map .a onto .c moving .a         ; fold the flap containing .a, valley
fold map .a onto .c moving .a mountain ; ... as a mountain
fold perp --l through .p moving .q    ; line-construction folds need `moving`
```

`@` is retired: there is no fold marker distinct from the verb itself.

**`mark`'s extent — full, `between`, `at`** *(since v0.22-dev)*. A `mark`
statement optionally clips the motion's line before creasing:

```
mark <motion>                    ; full chord (default)
mark <motion> between .a .b      ; clip to the segment [.a, .b]
mark <motion> at .p              ; a single reference point on the line
```

`between`/`at` points must already lie **on the mark's line** — off-line is an
error (`.p is not on the mark's line`). The discriminator for what happens next
is **boundary-incidence, not which form was written**: an extent that runs
**boundary-to-boundary** across the flap it lands on — the default full chord,
or a `between` whose two points both sit on that flap's boundary — **subdivides**
exactly like before, emitting a standard `F` edge. An extent that **ends
mid-face** — an `at .p` with `.p` interior to a face, or a `between` with one or
both ends interior — does **not** subdivide: the boundary-reaching part (if any)
still creases and splits its faces, but the dangling stub from the last boundary
crossing to the interior endpoint becomes a **non-subdividing record** — a
pinch or reference crease that **splits no rays** and can dangle mid-face
without touching the flap graph at all. A record mark still rides folds with
its flap like any other material; it just never counts as a flap boundary.

An extent that would have to **cross an already-folded (`M`/`V`) crease** to
reach its endpoint is an error — it would leave its flap: "the mark's extent
from `.a` to `.b` crosses a folded crease (it leaves its flap)". A `between`
whose **both** endpoints dangle mid-face in *different* faces of the same flap —
spanning an internal (`F`) crease with neither end anchored to a boundary — is
also an error this slice: "the mark's extent from `.a` to `.b` spans an internal
crease with both ends mid-face; anchor an endpoint to a boundary or use two
marks." Anchor one end to a boundary, or split it into two marks, instead.

**Direction on a record mark.** `mark … valley|mountain` (default valley) still
applies to a record mark exactly as to a subdividing one: the mark is always
`F` in the folded-form frame (nothing has moved), and its M/V **intent** colours
the crease-pattern frame only — the same creasePattern/foldedForm split used
for subdividing marks (§7).

**Layer selection — `#[...]`.** `mark <motion> [extent] #[...]` chooses which
flap the mark is written onto, same resolution as `&`'s `#[...]` (§4.8):
the unique flap containing every listed point. Omitted, it defaults to the
**carrying flap** — the flap holding the extent's own geometry (the material
the points/line were built from); if that geometry sits on a boundary shared by
several stacked flaps, it is ambiguous and errors, naming the flap count and
pointing at `#[...]`.

**Combined bind-and-write.** `mark --l = <motion> [extent] [dir] [#[...]]`
binds the crease name and marks in one statement — equivalent to the
two-statement `--l = <motion>` *(pure value, §4.10)* followed by `mark --l
[extent] [dir] [#[...]]`.

```
mark --p = map .a onto .c between .a .m         ; segment record, anchored at .a
mark --p = map .a onto .c at .m mountain        ; single reference point
mark --q between .a .b #[.c]                    ; named crease, explicit flap
```

**FOLD emission.** A subdividing mark (full chord, or a boundary-to-boundary
`between`) emits exactly as any other `mark` — a standard `F` edge in
`edges_assignment` (§7). A record mark instead emits into the custom
`beloch:marks` field (§7) — never a fake display-length edge in the standard
arrays — and `render-svg`'s crease-pattern view draws it distinctly from live
creases (a dashed reference line or a short tick), so it is never mistaken for
an `F`/`M`/`V` edge.

**Known limits.** Exact-incidence only: a mark endpoint snaps onto an existing
vertex on exact rational equality, never by tolerance — no fuzzy/"close
enough" snapping this slice. The "spans an internal crease, both ends
mid-face" case above is a real gap, not a design choice: anchoring one end to a
boundary (or writing two marks) always works around it. And a partial mark
does **not** let a scaffold skip creasing entirely — the meet operator (`*` /
`.[…]`, §4.3) requires a **material** (marked) operand on each side; a pure
value-bound line (`--l = <motion>`, no `mark`) has no mark to cross (`--l is
not a physical crease, so it has no material mark to cross`, §4.3). So a line
used only to *locate* a meet point still must be `mark`ed — `between`/`at`
only controls whether that mark subdivides its flap, not whether it exists.
Lines that only feed a `fold … onto --l` (never a `*`) can stay pure values,
since folding a line onto another needs no material crossing.

*(since v0.18-dev)* Every `fold` has four ingredients:

| Ingredient | What | Source |
| --- | --- | --- |
| axis | the fold line | a motion, or an existing material crease (`fold --d` with no motion, below) |
| anchor | the deepest flap of the moving prefix | implied on map folds, or `moving` |
| scope | which flaps move | default: outside-contiguous prefix down to the anchor; or `up to` |
| direction | valley/mountain | `mountain` keyword; default valley |

**Anchor.** `moving` takes a **flap operand** (ADR 0016) — a point, a line, or
`#[...]`, the same three forms `&` (§4.8) resolves by incidence:

- a **point** — the flap carrying it. No flap contains it → error (`.p is not
  on the paper`); the point sits on a crease shared by several flaps → error
  naming the count and pointing at `#[...]` (`.p lies on a crease shared by 2
  flaps; name the flap with #[...]`).
- a **line** — the flap hinged on it. Usually ambiguous, since a hinge has two
  sides (`--d touches 2 flaps; add a point, e.g. #[.p]`); resolves only when
  exactly one flap touches it.
- **`#[...]`** — explicit incidence constraints: the unique flap containing
  every listed point (`moving #[.b .c]`), same resolution rule as `&`'s
  `#[...]` selector.

**Map folds** (`fold map .a onto .c`) imply the anchor from the moved point
when `moving` is omitted — here, `.a`'s flap; `moving <flap>` overrides it
(e.g. `moving .c` folds the other side instead). *(since v0.19-dev)* `fold
map --l1 onto --l2` (axiom 5) similarly derives its anchor — from `--l1`'s own
swinging material, not a moved point (§4.5); `moving` still overrides it, and
is still required when that material straddles the axis, or to scope an
`up to` range. **Line-construction folds** (`fold through`, `fold perp`) and
**folding along existing material** (below) have no natural anchor at all, so
`moving` is **required** — the existing "this fold needs `moving .p` to choose the side"
error. A line- or `#[...]`-flap anchor that
straddles the fold axis, or a `moving` point exactly on the axis, is also an
error (no side to pick); a point anchor disambiguates the side by itself, even
when its flap straddles the axis.

**Scope.**

- **No `up to`** (default): *(since v0.24-dev)* the moving set is the
  **outside-contiguous prefix** of the layer order over the crease region —
  top for valley, bottom for mountain — down to **and including** the
  flap(s) carrying the anchor operand. The anchor operand is `moving` when
  present, or the implied source point on a map fold (`fold map .b onto .o`
  → `.b`). It is *not* every layer on the anchor's side: deeper layers below
  the anchor flap stay. The seed is resolved in **paper space**: the flap(s)
  whose paper polygon contains the anchor point. A point on a shared paper
  **edge** (as in the ear fold, where the tip sits on the crease between two
  flaps) therefore seeds **all** those flaps — the whole contiguous run, so the
  tip you would physically grab is a valid anchor. But a point interior to a
  single paper face (a plain corner atop a folded stack) seeds only that one
  flap; if the layers beneath it must move too, the fold tears (the
  hinge-closure check below fires) and the fold needs an explicit `up to`. On a
  single-layer region (e.g. a first fold on flat paper) the prefix is that one
  flap — identical to the pre-v0.24-dev behaviour. The one gap: a bare axiom-5
  line-onto-line fold with no `moving` and no implied point (the direction comes
  from `side_override` alone, so there is nothing to anchor a prefix to) still
  falls back to every layer on the side — and that fallback set is now gated by
  the same hinge-closure tear check.
- **`up to <flap>`**: the contiguous range of flaps from the anchor through the
  target flap, **inclusive**, walked in the stack order **over the crease
  region** (depth may vary along a crease, so the walk compares only the
  overlapping pieces):
  ```
  fold map .d onto .a
  fold map .c onto .d up to .c   ; up to the anchor itself: exactly one flap moves
  ```
  A line target (`up to --d`) resolves even though `moving --d` alone usually
  wouldn't: the anchor fixes the walk direction, so the first flap hinged on a
  segment of `--d` reached from the anchor ends the range (ADR 0016, slot
  context counts toward uniqueness). A target not reachable by the walk, or
  not on the anchor's side, is an error.

**Validity — outer-contiguous prefix.** A `fold` statement is a **simple
fold** [demaine2007, §14.1]: a rigid 180° rotation of the moving layers under
the crease segment, collision-free throughout the motion. The static shadow of
that constraint: the moving set must be a **contiguous prefix of the layer
order in the crease region**, counted from the outside — top for valley,
bottom for mountain. A **buried anchor** — a stationary flap covering it in the
crease region — is an error regardless of how the end state looks (its material
would pierce the covering layer mid-rotation): "a simple fold cannot move a
buried flap: face *N* covers the anchor in the crease region — include the
covering flap (anchor the fold there) or fold less." The default scope is
itself an outer-contiguous prefix by construction (it grows outward from the
anchor flap), so it satisfies the prefix rule; a genuine tear (the anchor
flap hinged to a stationary layer off the axis) is caught by the same
hinge-closure check the `up to` path uses. Motion outside the crease region
is not checked — full motion validation is out of scope until an animatable
(3D) viewer needs it.

**Folded state.** The paper is a set of flat **faces** — each a convex polygon
in paper coordinates plus a rigid isometry placing it on the table — carrying a
**partial** stacking order: any two faces that overlap on the table are ordered
above/below, while faces lying apart carry no relation (a sparse per-face poset,
not a single bottom→top stack). A flat fold (±180°) keeps everything in the table
plane, so the only "depth" is this per-overlap order. A simple fold reflects every
layer in the moving set across the crease line (an exact reflection — no
`sqrt`) and restacks: the moved layers, reversed, go on top (valley) or
underneath (mountain). The default scope is the outside-contiguous prefix
down to the anchor flap (see **Scope** above), not every layer on the
anchor's side; `up to` widens it explicitly when a fold needs to reach
deeper.

**Derived mountain/valley.** Each crease's assignment is
`valley XOR (the cutting face is back-up)`, fixed when the fold runs. Because
stacked layers alternate front/back, one fold through a stack yields the correct
**alternating** M/V across layers (the accordion). Earlier creases keep their
assignment (material facts). This XOR rule is exact for a **simple fold** — one
crease, one pre-fold parity check — and is *equivalent to* the more general
rule below in that case.

For a **multi-crease move** (`flatten`, §4.9 — several creases folding
together at one vertex), the folded-form letter of each resulting crease is
the **derived global-frame M/V** of the finished folded state: the
mountain/valley assignment determined by the isometric folding map and its
layer ordering together [hullzakharevich2023, §2.1] — which face is
orientation-preserved and whether the two faces across the crease are above
or below each other — the same notion the single-crease XOR is checking, just
read off the finished state instead of computed per-ray during the fold. (An
earlier implementation instead adjusted the per-ray XOR by a fan-index parity
term to approximate this; that adjustment was a bug, not a spec rule, and is
not carried into the 3D rewrite.) The derived letter is anchored to the
crease pattern, not to which side of the paper is facing up: `flip` (§4.7)
negates orientation and layer order together, so the derived M/V is
unchanged — mountain stays mountain when the model is turned over.

**Folding along existing material** — `fold` with no motion *(since
v0.18-dev)*:

```
fold <crease-operand> [moving <flap>] [up to <flap>] [mountain]
```

Folds along a crease already on the paper (a bundle, §4.8) instead of
re-stating the motion that produced it (§4.1–§4.5c). `moving` is **always
required** — a material crease implies no side. Material resolution is per
flap, as for any crease reference (§4.8): a crease **bent** under the moving
set is an error ("the crease is bent under the moving flaps; select a
straight segment with `&` or move fewer flaps") — select a straight segment
with `--d & ...` instead. `fold` (with no motion) composes with `up to` to
crease every layer while folding only some — the motivating case, *crease
all, fold some*:

```
mark --d = map .b onto .a     ; mark: subdivides ALL layers, stays flat
fold --d moving .b up to .c   ; fold only flaps .b through .c along it
```

Non-moving layers keep their flat crease mark (`"F"` in FOLD output, §7, since
v0.21-dev — was `"U"` before); moving ones fold (their mark upgrades to
`"M"`/`"V"`).

See [ADR 0016](../decisions/0016-typed-operands-bundle-values-singleton-slots.md)
(typed operands: bundle values vs. singleton slots — the resolution rules
behind `moving`, `up to`, and `#[...]`) and
[ADR 0014](../decisions/0014-crease-is-a-bundle-of-segments.md) (a crease is a
bundle of segments — why folding along existing material checks for a bent
crease and why `&` selection exists).

**Placing the moved flap with `over` / `under`** *(since v0.26-dev)*.

```
fold <motion|crease> [ moving <flap> ] ( over | under ) <flap>
```

A placed fold reflects the anchor flap's material beyond the axis, as any
fold does, and inserts the moved block into the stack immediately above
(`over`) or below (`under`) the target flap instead of on the outside. The
crease it scores, the material it subdivides and the derived letters are
unchanged. The moving set is the anchor flap's faces on the moving side,
closed under coplanar clusters, with no outer-prefix rule: a tuck passes
through a pocket that opens for it, so the rigid-rotation argument behind
the prefix rule does not apply; the layer invariants of the end state
decide. `moving` is optional here as in any fold: a map motion implies it
from the moved point, and the fold errors when neither is available. The
target resolves by incidence to a flap that must be stationary and must
overlap the footprint the block lands on; of its overlapping faces
the lowest-ranked anchors `under`, the highest-ranked `over`. The fold's
direction is a consequence of the placement, never stated: `mountain` beside
`over`/`under` is a parse error (`a placed fold derives its direction; drop
mountain`), and so is `up to` (`a placed fold moves the anchor flap only; up
to is not supported here`).

Errors: `the placement target moves with the fold; name a stationary flap`;
`` <T>'s flap does not cover where the moved material lands ``; `` placing
the moved material under <T> would pierce layer <n> `` (`over` likewise).

```
fold map .a onto .d                     ; two layers
fold through .m .n moving .b under .p   ; the top layer's corner, tucked between
```

Design: [`docs/superpowers/specs/2026-09-10-reverse-fold-and-layer-placement-design.md`](../docs/superpowers/specs/2026-09-10-reverse-fold-and-layer-placement-design.md).

### 4.6a `reverse` — inside and outside reverse folds *(since v0.26-dev)*

```
reverse <motion|crease> [ moving <flap> ] [ outside ]
reverse CREASE_NAME "=" <motion> [ moving <flap> ] [ outside ]
```

Take a flap folded along a crease, the *spine*, and a line across it meeting
the spine at O; the *tip* is the material beyond that line. An inside
reverse fold pushes the tip in between the flap's layers, an outside reverse
fold wraps it around them; in both the spine beyond O ends up folded the
other way. `reverse` is a disposition verb like `fold`: it takes a motion
(computed in the table frame) or an existing material crease, is bindable,
and implies `moving` from a map motion's moved point.

The end state is defined in the table frame: the tip is cut into two halves
at the spine, both halves are reflected across the line in one operation,
and each half is placed relative to its own hinge layer: inside, each half
lands next to its own body in the gap between the two bodies; outside, the
half hinged to the lower body goes under everything and the other on top.
The tip is the connected material beyond the line that carries the anchor;
the spine is whichever folded hinge of the tip splits it into two halves
whose hinge layers occupy separate rank ranges and whose placement passes
the layer invariants. Exactly one such hinge must exist.

Nothing is stated about mountain and valley. Each half flips over and keeps
its rank position relative to the other, so at the spine beyond O the backs
of the paper face each other where the fronts did: the derived letter
reverses. The new crease reads, on both halves, the letter the spine had
before the fold for an inside reverse and the opposite letter for an outside
reverse. A reverse fold is not two placed folds
in sequence: after one half moves, the spine joins a reflected face to an
unreflected one along no common segment, so the two halves move together.

Errors: `reverse needs a tip folded along one spine; the moving material
does not split into two halves`; `the tip can be reversed at <n> spines;
fold less so that one remains`; `the two halves are hinged to interleaved
layers; that is not a reverse fold`; `reversing the tip would pierce layer
<n>`.

```
fold --bd = map .a onto .c              ; triangle
reverse --h = map .b onto .c            ; tip b between the layers
reverse --v = map .d onto .c            ; tip d likewise: the preliminary base
```

[`examples/bases/preliminary-reverse.bel`](../examples/bases/preliminary-reverse.bel)
folds the preliminary base this way, the Eos route [ida2020, §7.4.3]; it
agrees pointwise with the `flatten` construction in
[`examples/bases/preliminary.bel`](../examples/bases/preliminary.bel).

### 4.7 `flip` — turn the sheet over *(since v0.7-dev)*

```
flip
```

Turns the whole sheet over: every face's orientation inverts and the stacking
order reverses — every above/below relation negates, so a face previously at the
bottom of its overlap column becomes reachable on top. Because
orientation inverts, a *subsequent* valley command is derived as a **mountain**
relative to the original front — i.e. "mountain = turn over, then valley." `flip`
takes no axis: with named points, where the sheet lands is irrelevant, so the
reflection uses an internal canonical axis (the footprint's vertical centerline).
A direction argument may be added later when the animation renderer needs it.

### 4.8 Filtering a crease bundle: `&` (and `\`, `[]`) *(since v0.17-dev)*

A crease name is a **bundle**: one crease realised as a set of segments — one per
layer the crease line crossed, further split by later creases. The segments are
collinear only in the folded moment of creation; once (un)folding scatters them
they point every which way in the crease pattern. So a crease name is not a single
line.

`--l & <constraint>` **filters** the bundle to the segments incident to the
constraint. At a singleton slot (one that wants exactly one line, ADR 0016) it
projects to the **one** segment and yields that segment's current supporting line
(usable anywhere a line operand is; as a fold axis that is its table-space line,
in a meet (`*`) its material paper-space mark — §4.3). Constraints, by incidence:

- `--l & .p` — the segment the point `.p` lies on.
- `--l & --a` — the segment whose span contains `--a`'s crossing of `--l`.
- `--l & #[.a .b …]` — the segment lying on that flap.

Filtering is **incidence**: `&` keeps the segments the constraint is *on*. This is
distinct from `toward` (§4), whose meaning now varies by axiom: axioms 6/7
still use it for **proximity** (the construction landing nearest a point,
§4.5b, §4.5c); axiom 5 uses it for **direction** (§4.5) — the target side of a
fold, not a nearness measure. `&` binds tighter than the axiom keywords: `perp --l & --a through .b`
reads as `perp (--l & --a) through .b`.

Chaining conjoins: when one point sits on a crease crossing (two adjacent
segments share it), pin the unique segment incident to *both* constraints by
chaining — `--l & .p & --a`. Two related read operators complete the family:
`\` is the **negated** filter (`--l \ .p` keeps the segments *not* through `.p`
— e.g. the ray away from a split vertex), and `[a b …]` is the **union** of
same-typed bundles (`[--x --y] & .p`). At a singleton slot the result must be a
**single** segment: no match is an error ("no segment of `--l` matches …"); more
than one is an error asking for a further constraint.

`&` supersedes the earlier `--( --l #(…) )` restrict form (and the `at` operator
it replaced). `&` *selects* a segment from an existing bundle; *creating* a single
reference segment is the partial mark `mark … at .p` (§4.6) — an extent ending
mid-face lays a non-subdividing record, no separate primitive.

### 4.9 `flatten` — single-vertex flatten *(since v0.20-dev as `collapse`; renamed v0.23-dev; one-pipeline model v0.23-dev; stayer convention v0.23-dev)*

Every other fold in the language performs one simple fold at a time. Some flat
end states are not reachable that way: three angle bisectors of a triangle
meet at the incenter O, and — with the altitude from O added — the vertex is
flat-foldable (**Rabbit-Ear Theorem**, [[hull2020]](#ref-hull2020) Thm 8.5),
but no *sequence* of single simple folds reaches that end state; flat-foldable
and simple-foldable are different classes [demaine2007, §14.1.1]. `flatten`
jumps straight from the precreased flat sheet to the flat end state of several
creases folded at once, all meeting at one point — shipped as `collapse`
(v0.20-dev), renamed `flatten` and generalized (v0.23-dev,
[design](../docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md)),
then reworked into **one solver pipeline** (v0.23-dev,
[design](../docs/superpowers/specs/2026-07-16-flatten-derive-v2-design.md)).

**One pipeline, no modes.** An earlier revision split `flatten` into a
*validate* mode (every ray given, only checked) and a *derive* mode (an odd
ray given, the missing one solved for, a trailing `toward` mandatory to pick
a side). That split is gone: every `flatten` statement now runs the same
solve. `()` items state the topology — the rays sharing the vertex — and any
material facts already known (`mountain`/`valley`, `over`); these are **hard
constraints** that *filter* the solution space, never pick a winner
(`staying` — naming the stayer explicitly, State construction below —
shares the item form and is another such constraint; a redundant one is a
lint candidate, never an error). The solver fills in the rest — the M/V of every unmarked ray, the one
emergent ray when the given count is odd (still not constructible by any
Huzita axiom; it exists only because flat-foldability forces it), and the
stacking — subject to Maekawa and Kawasaki, which act as the solve's oracle
rather than separate checks you invoke. If more than one geometrically-valid
outcome survives, `{toward <point>}` picks among them; omit it when the
geometry is already unique — a disambiguator present but not needed is
redundant, never an error (redundancy is lint-territory, not
error-territory). See The pipeline, below, for the mechanics.

**Scope: one vertex per statement.** Deciding flat-foldability for a sheet
with many interacting vertices is NP-hard
([[hull2020]](#ref-hull2020) §6.6, Thm 6.17 — Bern–Hayes); the single-vertex
case is exactly decidable and already covers rabbit ear, waterbomb/preliminary
bases, and — later, at boundary vertices — squash-type moves. Multi-vertex
flatten (e.g. bird base in one step) is deferred (Appendix B).

**Syntax:**

```
flatten_stmt  := [ CREASE_NAME "=" ] "flatten" flatten_item+
flatten_item  := "(" flatten_elem ")"
               | "(" over_flap "over" over_flap ")"
               | "(" "staying" flap_operand ")"
               | "{" "toward" point_operand "}"
flatten_elem  := line_operand [ "mountain" | "valley" ]
over_flap     := point_operand | "#[" point_operand+ "]"
```

`()` and `{}` are semantically distinct, not stylistic: a parenthesised item
states a constraint on the vertex — a ray, an M/V pin, an `over` order, or
the `staying` flap (State construction, below) — and *filters* the solution
space; `{toward .p}` *selects* from whatever survives. `{toward .p}` is
itself an item — it may appear in any position among the parenthesised
ones — and at most once; a second occurrence is a parse error (`` only one
{toward} per flatten ``).

Every parenthesised item is wrapped unconditionally, even a bare element,
because with `and` dropped an unparenthesised item's first token would
collide with the first token of the *next* statement (a bind `--l =
…`/`.p = …`) at one token of lookahead. The `{…}` item needs no such
protection — `{` cannot start the next statement — so it is set off by its
own delimiter instead. **Element order is semantic**: the first two
elements' folded rays fix the stayer by convention (State construction,
below), so which element is written first and which second changes the
fold. Every other item — a third-or-later element, `over`, `staying`,
`{toward}` — carries no positional meaning and may appear in any order,
interleaved freely with the leading pair:

```
flatten (--ba & .a) (--bb & .b valley) (--e mountain) (.p over .q) (staying .r) {toward .s}
```

(`and` survives only as axiom-6's fixed binary joiner, `map … and … onto
…` — an accepted asymmetry, since that `and` binds a fixed pair of operands,
not an open item list.)

- `flatten_elem`'s `line_operand` must resolve to a material crease — the
  same operand forms `fold` (with no motion) accepts (`--name`, `--name &
  <constraint>`, §4.8); a paper edge or a non-material selected line is
  syntactically a `line_operand` too but errors at resolution (below).
- A **bare element is unconstrained** — the solver assigns its M/V. This is
  the one deliberate break from `collapse`'s old default (bare meant valley;
  see the design doc's Migration note). `valley` joins `mountain` as an
  explicit marker, symmetric now that bare implies neither.
- `over_flap` deliberately excludes bare crease names: that is what makes the
  first token inside an item's parens classify it unambiguously — a
  crease-name start is an element, a point/`#[...]` start followed by `over`
  is a stacking pair, `staying` is keyword-first. `staying`'s own operand is
  the full `flap_operand` (point, line, or `#[...]`, as `moving` takes,
  §4.6); a bare point `.a` is short for `#[.a]`.
- A duplicate `staying` clause in one `flatten` statement is a **parse
  error** at the second occurrence (`only one staying clause per flatten`) —
  at most one per statement.
- `flatten` is **bindable**: `--r = flatten …` names the result (§ Binding,
  below) exactly like `mark`/`fold`; the name is optional either way.

**Resolution.** Each element resolves to **every** material crease segment
at the shared vertex its operand matches — a through-running crease
subdivided at O by an earlier fold carries two, and (unlike `fold`'s own
single-segment resolution, §4.6, §4.8) both become candidate combinations
rather than an ambiguity error. `&`/`\` (§4.8) still narrow an operand to
one segment when written, but writing them is no longer required to resolve
a multi-segment crease: the **stayer filter** (State construction, below)
prunes the combinations that contradict the stayer on its own. A
combination survives resolution with zero matches only as an error: a bare
crease name with no material segment errors *"--<name> has no
material segment"*; a filtered or unioned operand that matches nothing
errors *"no segment of `<expr>` matches"*. An operand that does not resolve
to an existing material crease at all (a joined selector like `.a * .b`, or a
cross-crease union with no single crease to fold along) errors: *"collapse
folds along existing creases; `<operand>` is not a material crease"* (the
shipped message text predates the rename — an internal string, not a
user-facing keyword; every error text quoted in this section is reproduced
verbatim from the evaluator, several still say "collapse" for the same
reason). `&` stays *required* only where distinct surviving combinations
still contradict each other after every filter — the error then names the
element and suggests it: `` <name> is ambiguous at the vertex; select a
segment with `&` ``.

**Checks, roughly in evaluation order (see the note below on checks 12–14):**

| # | check | shipped error text |
|---|---|---|
| 1 | element is not a material crease | `collapse folds along existing creases; <operand> is not a material crease` |
| 2 | bare element resolves to zero material segments | `--<name> has no material segment` |
| 3 | filtered/unioned element matches no segment | `` no segment of <expr> matches `` |
| 4 | segments don't all share one strictly-interior common endpoint O | `no common interior vertex` |
| 5 | (`staying` given) the flap's material doesn't touch the vertex fan | `the staying flap does not touch the vertex` |
| 6 | a layer under the flatten region doesn't carry the attempted combination's crease on the same line (all-layers rule, below) | `collapse through unaligned layers` |
| 7 | the ray count is even and below 4 | `` count (hint: use `fold` for n = 2) `` |
| 8 | (odd ray count) no geometric completion closes the vertex at all, on either side | `vertex not flat-foldable toward that side` |
| 9 | a segment's far endpoint is not on the paper boundary (would leave a degree-1 vertex mid-sheet) | `crease ends inside the sheet` |
| 10 | two elements resolve to the same ray — the same direction from O | `duplicate ray in collapse` |
| 11 | Kawasaki fails — the reflection composition around O does not close (exact) [[hull2020]](#ref-hull2020) ch. 5 | `vertex not flat-foldable (angles)` |
| 12 | the leading two elements' folded rays are collinear and no `staying` is given — the convention has no side to anchor | `` collinear leading creases don't pick a stayer; add (staying <flap>) `` |
| 13 | no realization keeps the stayer still — every candidate × Maekawa pattern died before a stacking closed | `no realization keeps the staying flap still` |
| 14 | two different segment combinations (Resolution, above) both survive with valid realizations | `` <name> is ambiguous at the vertex; select a segment with `&` `` |

Checks 7–11 run against a **candidate ray set** — the given rays, plus one
emergent candidate when the count is odd (The pipeline, below) — and never
depend on M/V: the count floor, Kawasaki closure, duplicate rays, and the
boundary check are all properties of which lines and directions are given,
not of which are marked mountain or valley. A candidate that fails any of
these fails for **every** Maekawa pattern tried against it — there is no
per-pattern variant of checks 7–11. Check 12 belongs to the same
M/V-independent family — the leading pair's collinearity is a fact about the
given rays alone, not about mountain/valley — but the evaluator probes it
once per attempted Maekawa pattern rather than once per candidate (The
pipeline, below): a difference in *where* the code checks it, not in what it
tests. Check 13 is not a single up-front gate: it is the fallback the
evaluator reports once every candidate and every Maekawa pattern has been
tried and none produced a live realization (\|S\| = 0, below). Check 14 runs
once every segment combination has been attempted in full, before
`{toward}` selection is ever reached — a genuine contradiction between
combinations, distinct from the geometric/M/V selection stages below it in
this section.

**State construction.** Faces are the sectors around O. Sector *i*'s isometry
is the composition of reflections across the rays bounding sectors `0..i`, in
CCW order from a fixed sector 0 — exact, the standard single-vertex fan
construction. There is **no `moving` clause on `flatten`**: instead, sector 0
is always the **stayer** — the ray labeling is rotated so the stayer sector
takes position 0 *before* the composition runs (The pipeline, below), giving
`T_0 = identity`, front face up, *by construction*. An orientation-reversing
anchor is therefore impossible: every face's front/back reads off the stated
flatten directly, never its mirror.

**Definition.** The stayer is the material that does not move: identity
isometry, front face up, exactly where it lay before the flatten. Without
`(staying …)`, its region is the <180° arc at the vertex between the
*folded rays* of the first two elements (Syntax, above — this is why element
order is semantic). With `(staying X)`, `X`'s material is the stayer instead
and element order carries no stayer meaning (a `staying` that merely
restates what the convention would already pick is accepted silently — a
lint candidate, never an error: redundancy is not an error, contradiction
is). Its final **stack position** is a *consequence* of the solved M/V
pattern, never part of the definition — a rabbit ear stacks everything on
top of its stayer, but a mountain at the stayer's edge folds the neighbor
*underneath* it instead.

`effective_valley` reads a crease's M/V parity off a single face
**representative** in the stayer-side sector adjacent to that ray. A sector
can be **mixed-orientation** — at the fish's second-ear vertex the stayer
sector holds both the stationary base strip (face-up) and the first ear's
already-folded stack (face-down) riding on top of it — so taking the first
face in the sector by array index can surface the wrong orientation and
flip a hinge constraint, starving the true stacking chain. The
representative is instead chosen per ray: the face in the stayer-side
sector whose table polygon has an edge running from O out along that ray's
own segment — the layer the crease's M/V letter is actually about — with
ties (a through-folded multi-layer crease, not in today's corpus) broken
toward the lowest stacking rank.

The kernel enumerates every stacking consistent with the per-ray hinge
directions and a layer-collision check (no two layers occupy the same
space), applies any `over` clauses, then keeps only the stackings
distinguishable by their overlapping-face order. Exactly one → this
candidate contributes a single realization; several → each contributes one,
pooled with every other candidate's — and every admissible stayer sector's
(The pipeline, below) — into the set `flatten`'s own pipeline decides among
— the kernel itself never errors ambiguous here.

**v1 enumeration limitation.** Valid stackings only ever move whole
*sector-blocks* relative to each other — a sector cannot be tucked *between*
two layers belonging to another sector's block. This covers rabbit ear and
the waterbomb base; forms that need one sector interleaved inside another's
stack are a follow-up (Appendix B).

**Clauses.**

- **`<flap> over <flap>`** (repeatable): flap operands are a point or
  `#[...]` (a point denotes its sector). Orders the two sectors in the final
  stacking. Redundant `over` — already true in every surviving stacking — is
  a silent no-op, not an error (a future lint hint, same category as other
  implied-clause lints); `over` that rules out every surviving stacking
  errors `` contradictory `over` ``.
- **`(staying <flap>)`**: names the stayer explicitly, overriding the
  leading-element convention (State construction, above); once given,
  element order carries no stayer meaning at all. The flap must touch the
  vertex fan — a flap whose material never reaches O errors `` the staying
  flap does not touch the vertex ``. At most one per statement; a second is a
  parse error (`only one staying clause per flatten`). A collinear leading
  pair (opposite rays of one line — both candidate arcs read as exactly
  180°) leaves the convention with no side to pick, so `staying` is then
  required, not optional: `` collinear leading creases don't pick a stayer;
  add (staying <flap>) ``.

**The pipeline.** Kawasaki's Theorem [hull2020, §5.3, Thm 5.17] says a single
interior vertex with consecutive sector angles `α₀ … α₂ₙ₋₁` is flat-foldable
iff the alternating angle sum is zero — exactly the condition
`Collapse.closure_ok` already checks as a reflection-composition identity (no
angle type needed). The odd-count case turns that check around: given an
**odd** number `k` of rays sharing a vertex O, the product of their `k`
reflections has `det = −1` and so is *itself* a reflection; its axis is a
line through O, and inserting it as one more ray makes the full `k + 1`-ray
composition close.

**Admissible stayer sectors.** Every candidate ray set is tried against each
fan sector that lies inside the stayer region (State construction, above):
normally exactly one, unless the emergent ray itself falls inside the
leading pair's arc and splits it in two — then both halves are admissible,
and each is a genuinely different physical fold (a mirror world), not a
duplicate to dedup away. A collinear leading pair (both candidate arcs
exactly 180°) admits no sector at all without `staying` — check 12. The
evaluator rotates the ray labeling so the sector under test becomes sector 0
before the fan construction runs, which is what anchors `T_0 = identity` on
the stayer (State construction, above).

1. **Count rays.** Odd → `Flatten.candidates` generates every geometric
   completion that could close the vertex: it tries every angular gap
   between the sorted given rays as the insertion point, keeps the
   candidates whose axis genuinely falls in its own gap, and tags each
   `LineNew` (a genuinely new line) or `OppositeRay` (the far side of an
   already-given line — degenerate in direction, not in position: it is
   still a real, non-constructible crease). None found → check 8, above.
   Even → no candidate; the given rays are the whole ray set.
2. **Enumerate.** Each **segment combination** (Resolution, above — one
   chosen segment per element, when a crease carries more than one at O) is
   tried independently. Two guards run before pattern search: check 6 drops
   a combination outright if flattening it would fold through an unaligned
   layer; and, *only when the statement has more than one combination to
   choose from*, another element's given ray landing strictly inside the
   stayer arc kills that combination too — stayed material cannot carry a
   folding crease. This gate is what makes bare through-crease operands
   resolve without `&` (Resolution, above): at the fish vertex, the
   combination that folds `--ray`'s far segment has that ray inside the
   leading pair's arc and dies here, leaving only the near segment. A
   single-combination statement has no alternative to fall back on, so a
   mis-ordered leading pair there is *not* caught this way — it runs the
   full pipeline and dies later as an ordinary `` collapse folds a flap off
   the paper (no seating keeps it in the sheet) ``, the same failure any
   other infeasible fold produces (see
   [`flatten-order-load-bearing.bel`](../tests/cases/collapse/flatten-order-load-bearing.bel)).
   For each surviving combination, at each admissible stayer sector
   (above), enumerate every Maekawa-consistent completion of the *unpinned*
   slots (\|M − V\| = 2 over the rays; a pinned `mountain`/`valley` fixes
   its own slot — a pattern that can't satisfy Maekawa at all is never
   tried) and try each through the collapse oracle: Kawasaki closure
   (checks 7–11, already candidate-level and shared across every pattern),
   the stayer sector's admissibility (checks 12–13), then, per pattern, Maekawa
   itself, self-intersection, and `over`. A failing pattern contributes one
   of `` Maekawa violated by the stated assignment `` / `` assignment
   forces self-intersection `` / `` collapse folds a flap off the paper (no
   seating keeps it in the sheet) `` / `` contradictory `over` `` to a
   failure pool; a succeeding one becomes a **realization**, deduped
   against the others by observable stacking signature (two attempts that
   place and stack every face identically count once). If literally nothing
   survives across every combination and every admissible sector, that is
   check 13, `` no realization keeps the staying flap still ``.
3. **Segment-choice ambiguity** (check 14). If **more than one** segment
   combination independently produced a non-empty realization pool, the
   statement stops here: `` <name> is ambiguous at the vertex; select a
   segment with `&` ``, naming the element that had the multiple segments.
   Only a single winning combination's pool ever reaches selection below —
   `{toward}` never resolves a segment-choice contradiction, only a fold
   direction.
4. **Decide by \|S\|** (S = every surviving realization of the winning
   combination, pooled across candidates and, per candidate, across every
   admissible stayer sector):

   - **Tier rule** (applied before counting): a `LineNew` realization always
     outranks an `OppositeRay` one — S is the `LineNew` pool if it is
     non-empty, the `OppositeRay` pool otherwise. A lone `LineNew` survivor
     decides even if several `OppositeRay` realizations also close.
   - \|S\| = 0 → infeasible, checked in priority order:
     `` collapse folds a flap off the paper (no seating keeps it in the
     sheet) `` if any candidate failed that way; else whichever of
     `` collapse through unaligned layers ``, `` collinear leading creases
     don't pick a stayer; add (staying <flap>) ``, or `` no realization
     keeps the staying flap still `` appears first in the failure pool
     (checks 6, 12, 13); else, odd count, `` the derived crease does not
     close the vertex ``; else (even count) the pool's own dominant
     failure — the first that isn't `` assignment forces self-intersection
     ``, falling back to that, or to `` Maekawa violated by the stated
     assignment `` if no pattern was even tried.
   - \|S\| = 1 → fold it. A `{toward}` present is redundant, never an error.
   - \|S\| > 1 → **selection**, below.

**Selecting among survivors (\|S\| > 1).** Exactly three stages, in order,
each narrowing the deciding set further; `{toward .p}` is read at whichever
stage first needs it, and is required once any stage does:

1. **Position** (class choice): a realization's placement in the folded
   state depends only on which ray *lines* were used, never on M/V, so
   realizations group into *position classes* by their moved-material
   centroid. `{toward .p}` picks the class maximizing
   `(centroid(moved faces) − O) · (p − O)`. Two distinct classes tying on
   that dot product means `p` is collinear with a crease through O —
   genuinely can't pick a side:
   `` `toward` does not pick a side — the point is collinear with a crease through the vertex; aim it off the creases ``.
2. **Min-mountain canon** (within the winning class): keep only the
   realizations with the fewest derived mountains among the **user-given**
   creases (a freshly-materialized emergent crease is never a given crease,
   so it never counts; a collinear-reuse `OppositeRay` emergent does, since
   it *is* a given crease's own line). This stage is `{toward}`-independent
   and, alone, is sometimes already unique — including with `{toward}`
   entirely absent (see step 3 below).
3. **Rank dipole**: if several realizations still remain, maximize the exact
   `S(R) = Σ_faces area · (rank − (n_faces−1)/2) · ((table_centroid − O) · (p − O))` —
   "the material lying toward `p` ends up on top." Mirror realizations score
   ±equal, so any off-axis `p` decides. Guarded first by a symmetry check: if
   the given rays' direction set is invariant under reflection across the
   O–`p` line (or `p = O`), the two sides are genuinely indistinguishable and
   this errors the same way stage 1's tie does.

If `{toward}` is absent, only stage 2's canon runs (stages 1 and 3 both need
a point); a surviving singleton folds, otherwise:
`` flatten is ambiguous: <N> realizations; add {toward .p} to pick the fold direction ``,
`N` being the post-canon count. (`Collapse`'s own single-result contract,
`` ambiguous stacking (<k> orders) ``, is the kernel-internal building block
`collapse_all` wraps for a single distinct-signature dedup — unreachable from
`flatten`, which always calls `collapse_all`, never `collapse`, directly; it
survives only as an internal string, exercised by the `Collapse` module's own
tests.)

```
--ear = flatten (--ba \ .a) (--bb \ .b) (--v \ .m) {toward .d}
```

Here `--ba \ .a`/`--bb \ .b`/`--v \ .m` are the rays *away* from `.a`/`.b`/`.m`
— three given rays (odd), so the pipeline's step 1 adds the emergent fourth.
`\` and `&` are the shipped filter/drop selectors (§4.8); no new operator is
needed for the odd case, only the requirement that the ray count be odd. See
[`examples/bases/swivel-rabbit.bel`](../examples/bases/swivel-rabbit.bel) for
a full worked case where the emergent crease is genuinely non-constructible
(the hinges sit at an arbitrary height, not a bisector angle), and
[`tests/cases/collapse/flatten-opposite-ray-toward-b.bel`](../tests/cases/collapse/flatten-opposite-ray-toward-b.bel)
(with its `-toward-d` sibling) for a vertex where `{toward}` genuinely picks
between two *different* end states — same face count and table positions,
mirrored stacking.

The generative solution-space selector `#{…}` (and `.{…}`/`--{…}`) and the
`stays <flap>` sugar that would desugar to it are **deferred** — their own
language-wide design pass, tracked as
[issue #46](https://github.com/tophcodes/beloch/issues/46); v1 ships only the
constructed-space ray-naming shown above. Multi-emergent-ray flatten (more
than one crease forced at once) and the `onto <line>` exact-landing (petal)
form are deferred alongside it (Appendix B).

**Binding & the tip.** `flatten` **creates** creases, so — like `fold`,
`mark`, and the axiom folds — it is bindable. With an even given count, the
bound name resolves to the bundle of given rays the statement acted on. With
an odd count, the name resolves to the **emergent** crease instead — the
only construction that names it — so a further meet against it finds the
point where the emergent crease reaches the paper boundary:

```
--ear = flatten (--ba \ .a) (--bb \ .b) (--v \ .m) {toward .d}
.tip  = .[--ear --ab]        ; the emergent crease's tip on the base edge
```

**Material and layers.** `flatten` is an **all-layers** move, like the
default `fold`: the whole stack under the flatten region folds as
one unit. Every element's crease must be material, on the same line, in
every layer the flatten region passes through; a layer where it is bent or
absent errors `collapse through unaligned layers` (check 6, above).
Single-layer paper trivially satisfies this.

**Output.** *(since v0.20-dev)* The `edges_assignment` (§7) a `flatten`
produces is **global-frame** M/V: because a sector's isometry can be
orientation-reversing, the kernel's parity rule inverts the stated
mountain/valley on face-down sectors, so the M/V letters in the FOLD output
can differ, ray by ray, from what was written in source — see the caveat
comments in the shipped examples.

**Examples.**
[`examples/bases/swivel-rabbit.bel`](../examples/bases/swivel-rabbit.bel)
(n = 3 given + 1 emergent) is the worked case above — its golden FOLD output
is the regression anchor for the whole selection pipeline: a bare-M/V
solve whose material-centroid metric must still land on the same right-hand
swivel every time.
`tests/test_collapse.ml`'s `test_over_resolves_ambiguity` (n = 8, center
vertex — both diagonals and both midlines, all M/V pinned; unit-level
against the shared `Collapse` kernel, not a `.bel` case) shows the
even-count case: several stackings of the one Maekawa pattern survive
Kawasaki, and `over` — not `{toward}` — narrows them to one, since `over`
operates inside the collapse oracle itself (step 2 of the pipeline), before
`flatten`'s own selection ever sees more than one candidate.
[`tests/cases/collapse/flatten-fish-pinned-unique.bel`](../tests/cases/collapse/flatten-fish-pinned-unique.bel)
shows the odd-count case pinned tightly enough that no `{toward}` is needed
at all: two of the fish-base vertex's three given rays are pinned explicitly,
narrowing the Maekawa search until exactly one realization survives before
selection is ever reached.

See [ADR 0016](../decisions/0016-typed-operands-bundle-values-singleton-slots.md)
(flap operands),
[ADR 0014](../decisions/0014-crease-is-a-bundle-of-segments.md) (crease
bundles, rays split at a crossing — the same machinery `fold` and `&`
build on, and what the emergent crease's bundle joins), and ADR 0012/0013
(the exact real-algebraic kernel the derive math needed no polynomial from,
per the design doc above — reserved for the deferred multi-emergent case).

### 4.10 The read/write law — motions read, `mark`/`fold`/`flatten` write *(since v0.20-dev; completed v0.21-dev; `collapse` renamed `flatten` v0.23-dev)*

One law governs the surface syntax: **an operation that mutates paper state —
scores a crease, folds, and thereby re-segments existing references (ADR 0014)
— is a keyword verb, sequenced in program order; an operation that only reads
the current state, or only describes a geometric line without touching the
paper, is a pure read, and is an operator, bracket, or motion.** Keywords are
commits to the versioned sheet; reads are checkout queries against it, or (for
motions) descriptions not yet committed. The physical asymmetry the law
encodes: *finding* where two creases cross is free, *describing* a line is
free, *making* a crease costs a fold, so the notation looks different for the
two.

The **reads** are:

- the symbols/brackets — meet `*` and `.[l+]`, join `--[c+]`, flap `#[c+]`,
  filter `&`, drop `\`, union `[…]` — which **select existing geometry** and
  error on no-match: meet `*`/`.[]` names an existing crossing, and the join
  `--[.a .b]` (or its `.a * .b` sugar) resolves to a **real** crease or paper
  edge through the two points, never conjuring a "sight-line."
- the **motions** — `map … onto …`, `through … …`, `perp … through …`
  (§4.1–§4.5c) — which compute a line without touching the paper. `--l = map
  .a onto .b` binds a value; on its own it scores nothing. *(since v0.21-dev)*
  `through` (Huzita axiom 1) joins this side too: it used to be the sole
  write, but it is no reflection, only a description — "the line through two
  points" is exactly as inert as any other motion until a disposition verb
  acts on it.

The **writes** are the disposition keyword verbs (§4.6, §4.9):

- **`mark`** — crease a motion (or an inline line) flat: subdivides the
  sheet, emits FOLD `F`.
- **`fold`** — crease a motion (or an existing material crease) and fold it:
  subdivides *and* moves layers, emits FOLD `M`/`V`.
- **`flatten`** — fold several existing material creases sharing one vertex
  straight to the flat end state, optionally deriving the one crease
  flat-foldability forces when the given ray set is odd (§4.9).

`@` is retired entirely: it is no longer a marker anywhere in the grammar —
the verb itself (`mark`/`fold`/`flatten`) carries the write. Full derivation:
[`docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`](../docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md),
completing the design begun in
[`docs/superpowers/specs/2026-07-08-notation-by-state-change-design.md`](../docs/superpowers/specs/2026-07-08-notation-by-state-change-design.md).

Point-locating landmark constructions (a bisector foot, a reference apex) are
currently scored as full `mark … = through …` creases — an interim that adds
real geometry and moves the golden. The short-reference alternative is the
partial mark `mark … at .p` (§4.6), whose mid-face extent lays a non-subdividing
record instead of a full crease.

---

## 5. Naming and program structure *(since v0.0)*

A program is `paper square` followed by statements, executed top to bottom. A
name must be defined before it is used.

- **Crease statement** — a motion binds a line value, named or anonymous,
  scoring nothing; `mark`/`fold` (§4.6) act on the paper:
  ```
  --d1 = through .a .c             ; geometry only — scores nothing
  mark --d2 = through .b .d        ; named crease, stays flat
  mark map .a onto .c              ; anonymous crease, stays flat
  fold map .a onto .c moving .a    ; fold (valley)
  ```
- **Point statement** — binds a derived point:
  ```
  .center = --d1 * --d2            ; meet of two creases
  ```
- **Flip statement** *(since v0.7-dev)* — turns the sheet over (§4.7):
  ```
  flip
  ```

Derived points and named creases are usable in any later statement. `;` begins a
line comment.

*(since v0.16-dev)* The binding separator is `=` (was `:` before v0.16-dev; see
`antipatterns.md`). Non-temp bindings are single-assignment: rebinding a
non-temp name in the same scope is an error, **except** temp names (§5a.6).
There is no `:=`.

**Reads and motions as RHS** *(since v0.16-dev; motions since v0.21-dev)*: the
read operators (§4.3, §4.8) and the motions (§4.1–§4.5c: `map`/`through`/
`perp`) are all values, usable directly as a binding's right-hand side — none
of them touch the paper:

```
.s  = --rs * --cd          ; meet — a read (names an existing crossing)
--e = through .p1 .p2      ; a motion — a line value; needs `mark --e` or
                           ; `fold --e` to actually score it
```

**Identifiers** *(since v0.16-dev)* are `[a-zA-Z0-9_]+` — underscore, never
`-`; kebab-case is reserved so it doesn't foreclose future numeric/arithmetic
syntax (`repeat n`, ratios) or create whitespace ambiguity next to the `--`
sigil.

> Concrete syntax (keywords, sigils) is stable as of v0.0 but may still be
> revised before v1.0.

---

## 5a. Defs, instances *(since v0.16-dev)*

Three constructs extend program structure beyond flat top-to-bottom bindings.
They share **one evaluation path**: `def` never runs (it only records a
deferred body); `apply` is the *only* execution form — it folds immediately
and yields a retained instance; `export` only reads from an instance, never
re-runs anything.

### 5a.1 Temp names: `_`

A name whose identifier starts with `_` (`._mb`, `--_helper`) is a **temp**:
it may be rebound in the same scope (each rebinding is legal, and the `_`
marker makes it visible at every use site), and it is invisible from outside
its scope — not reachable via qualified access (§5a.4), not copied by
`export` (naming a temp in an export list is an error), and never named in
FOLD output (§7). A fold bound to a temp crease still physically happens; it
just appears unnamed in FOLD. This rule is uniform across scopes: root scope
and `def` bodies both follow it.

### 5a.2 `def`

```
def petal(.p .q --base) {
  fold map .p onto .q moving .p
  --pq = through .p .q
  .tip = --pq * --base
}
```

- Bare identifier, no sigil — a def name is never an operand, so it needs no
  kind sigil. Def names live in their own namespace; defining the same name
  twice is an error.
- Top level only.
- Parameters are sigil-typed (`.name` point, `--name` crease); the parameter
  list only changes arity, never the evaluation model. Zero parameters is
  written `def name() { … }` — the parentheses are always present.
- **Closed scope.** A body sees exactly its parameters and defs defined
  textually earlier — nothing else. In particular the corners `.a`–`.d` are
  **not** visible (their referents are state-dependent after earlier folds);
  a body that needs a corner takes it as a parameter. Because a body only
  sees earlier defs, recursion is structurally impossible.
- Allowed body statements: bindings, fold/construction actions, `flip`,
  `apply`, `export`. Not allowed inside a body: `def`.
- The body never runs at `def` time — only `apply` runs it (§5a.3).

### 5a.3 `apply` and instances

```
$p1 = apply petal(.k1 .k2 --[.k1 .k3])   ; folds now; instance retained
apply petal(.k2 .k4 --[.k2 .k1])          ; folds now; namespace discarded
```

- `$name` is the **instance** sigil — its only use. `apply` is the only RHS
  a `$`-binding accepts; instances cannot be aliased or constructed any
  other way.
- Arguments are ordinary point/crease operands (named or inline forms),
  matched to parameters by position; sigils must agree.
- A named-crease argument passes the **crease itself** — its material identity,
  not a snapshot of its line — so the body can meet it (`*`) or fold along it as
  the sheet evolves. Selected lines (`--[…]` joins, `&` projections) pass
  as fixed lines *(since v0.19-dev)*.
- `apply` always executes the body immediately, against the current folded
  state — a bare `apply name(args)` (no `$name =`) still folds; it just
  discards the resulting namespace instead of retaining it.
- The result is an **instance**: a namespace holding every non-temp binding
  the body created.

### 5a.4 Cross-instance access

Cross-instance access is through `export` (§5a.5) only. The bracket
member-access operators `.[$inst m]` / `--[$inst m]` are **removed** — the
`--[…]` and `.[…]` brackets are now the join and meet selectors (§4.3, §4.8),
which cannot also mean "read a member." To use an instance's members, `export`
them into the current scope (renaming with `as` where names would collide) and
then reference the landed names:

```
export { .tip as .tip1 } $p1
export { .tip as .tip2 } $p2
fold map .tip1 onto .tip2
```

`export` only reads from the instance — it never re-runs the body — so it is
still a pure read of already-folded geometry; naming a **temp** member in an
export list is an error (temps are never reachable through an instance).

### 5a.5 `export`

```
export { .tip --pq } $t              ; selective
export { .tip as .left_tip } $t      ; rename on landing
export { .s! } $t                    ; intentional shadow
export $t                            ; all non-temp members
```

- `export` copies members of an instance into the current scope; it never
  executes anything.
- Names in the export list carry their sigils; `as` needs a sigiled landing
  name.
- `export $t` (export-all) lands every non-temp member of `$t` and
  validates **each landed name individually**, exactly like selective
  export — two export-alls from two applies of the same `def` will collide
  on every member name unless disambiguated with selective `as`.
- `!` marks an intentional shadow and is validated both ways: binding an
  existing name **without** `!` is an error ("name exists, use `!` to
  shadow"); using `!` when the name does **not** already exist is an error
  ("nothing to shadow, remove `!`"). Shadow validation applies only to
  non-temp landing names: exporting onto a temp target (`export { .m as ._t }
  $i`) rebinds it freely and needs no `!`, since temps are single-scope and
  rebindable (§5a.1, §5a.6). Temps remain barred as export *sources*.

### 5a.6 Rebinding rules

One invariant, uniform across root scope, `def` bodies, and `export`
landings: **a name without a `_` prefix is bound at most once per scope.**

| Situation | Result |
|---|---|
| non-temp name bound twice in the same scope (root or `def` body) | error |
| rebinding a corner `.a`–`.d` at root | error |
| `def` name reused | error |
| `export` lands an existing name without `!` | error |
| `export` lands `!` onto a name that doesn't exist | error |
| `._x = …` (temp) bound more than once | OK — temps are rebindable (§5a.1) |
| `export` lands onto a temp target (`… as ._x`), with or without `!` | OK — temps rebind freely; no shadow check |

---

## 6. Exactness *(since v0.0)*

All coordinates and line coefficients are **real numbers**; a line is
`a·x + b·y = c`.

**Geometric decisions MUST be exact.** A conforming implementation MUST decide
every geometric predicate — equality of points and lines, parallelism,
incidence, orientation, point-in-polygon — as if computed over the exact reals.
No epsilon, no tolerance, no sampling. These decisions are **observable**: they
fix vertex identity, layer membership, and on-paper tests, and therefore the
emitted crease pattern and folded form (§7). Two implementations that agree on a
program's predicates emit the same FOLD graph.

The requirement is on the **decisions, not the number representation**. Exact
arithmetic over the algebraic reals is one sufficient strategy; an
exact-geometric-computation approach in the style of CGAL — interval arithmetic
with an exact fallback only when an interval is inconclusive — is equally
conforming. The spec constrains *what must be decided correctly*, never *how*.

**Algebraic degree** *(informational).* The constructions bound how irrational a
coordinate can become, which tells an implementation what field its decisions
must cover:

- Axioms 1–4 over rational inputs stay **rational** — no roots arise.
- Axiom 5 (angle bisector) introduces **square roots**: degree-≤2 extensions of
  the base field [[hull2020]](#ref-hull2020) §3.2.
- Axiom 7 (the cubic Beloch fold) introduces **cube roots**; axioms 1–6 stay in
  the quadratic tower.

**Serialization is the only inexact step.** `vertices_coords` in the FOLD output
(§7) is rendered to JSON decimal; non-terminating reals are rounded *in the
output only*. No internal decision is ever taken on a truncated value.

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
  for paper-boundary edges, **derived `"M"`/`"V"`** for folded creases (§4.6),
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
  `null` for creases bound to a `_`-temp (§5a.1) and for creases produced by a
  naked (unbound) `apply`. Additive: stock FOLD consumers ignore the field;
  `render/render-svg` uses `"name"` to colour/label creases.
- `beloch:marks` — custom property *(since v0.22-dev)* carrying the
  **non-subdividing record marks** (§4.6) that a `between`/`at` extent ending
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

## 8. Errors *(since v0.0)*

Every error is a compile error with a source span; the first matching error wins
and the process exits non-zero:

- parse error;
- axiom 1 or 2 whose two points are at the **same place** (coincident — which can
  also happen *after* folds bring two material points together);
- meet (`*` / `.[]`) on parallel creases (no intersection);
- meet (`*` / `.[]`) on a crease that marks **different lines on different layers**
  (project to one segment with `&`);
- meet (`*` / `.[]`) whose marks **do not reach** the crossing, or whose intersection is
  **off the paper**;
- `map --l1 onto --l2` (axiom 5): with `toward` omitted, both surviving
  bisectors land on the paper (ambiguous) or neither does (no fold to make); a
  `toward` point lying on `--l1`; with `toward` given, no candidate moves the
  swinging material that way, or the straddle case, where both do (§4.5);
- a `fold` on a line-construction motion (`fold through`, `fold perp`) with no
  `moving`, or a `moving` point lying on the fold axis (no side); an axiom-5
  fold (`fold map --l1 onto --l2`) whose `up to` range has no explicit `moving`
  to anchor it (`moving` is otherwise derived, §4.5);
- a `mark`'s `between`/`at` extent point not lying on the mark's line; an
  extent that would cross an already-folded (`M`/`V`) crease to reach its
  endpoint; a `between` extent dangling mid-face at **both** ends in different
  faces of the same flap (§4.6);
- reference to an undefined point or crease name.

---

## Appendix A — grammar (informal) *(since v0.0)*

The Menhir grammar is authoritative once written; this sketch is a guide.

```
program       := "paper" "square" stmt*
stmt          := crease_stmt | point_stmt | flip_stmt | flatten_stmt
              | def_stmt | instance_stmt | apply_stmt | export_stmt          ; since v0.16-dev
crease_stmt   := CREASE_NAME "=" axiom                            ; a read — binds a line value, scores nothing
               | "mark" markable                                  ; crease flat (anonymous motion, or an existing line, since v0.21-dev)
               | "mark" CREASE_NAME "=" axiom                      ; crease flat, named (since v0.21-dev)
               | "fold" markable fold_spec                        ; crease and fold (a motion, or existing material — since v0.21-dev)
               | "fold" CREASE_NAME "=" axiom fold_spec            ; crease and fold, named (since v0.21-dev)
               | "reverse" markable reverse_spec                  ; reverse fold (since v0.26-dev)
               | "reverse" CREASE_NAME "=" axiom reverse_spec
reverse_spec  := [ "moving" flap_operand ] [ "outside" ]
markable      := axiom | line_operand                             ; since v0.21-dev
point_stmt    := POINT_NAME "=" point_operand
               | POINT_NAME "=" "free" "on" line_operand "from" point_operand [ "at" RATIONAL ]  ; free point, since v0.25-dev
flip_stmt     := "flip"
axiom         := "through" point_operand point_operand          ; axiom 1 — a read (motion, since v0.21-dev)
               | "map" point_operand "onto" point_operand       ; axiom 2
               | "perp" line_operand "through" point_operand     ; axiom 3
               | "map" point_operand "onto" line_operand "perp" line_operand  ; axiom 4
               | "map" line_operand "onto" line_operand [ "toward" point_operand ]  ; axiom 5
               | "map" point_operand "onto" line_operand "through" point_operand
                     [ "toward" point_operand ]                                  ; axiom 6
               | "map" point_operand "onto" line_operand
                     "and" point_operand "onto" line_operand
                     [ "toward" point_operand ]                                  ; axiom 7
fold_spec     := [ "moving" flap_operand ] [ "up" "to" flap_operand ] [ "mountain" ]  ; since v0.18-dev
               | [ "moving" flap_operand ] ( "over" | "under" ) flap_operand         ; placed fold, since v0.26-dev
flap_operand  := point_operand | line_operand | "#[" point_operand+ "]"              ; since v0.18-dev
point_operand := POINT_NAME                                      ; named
               | line_operand "*" line_operand                   ; meet (binary): the point where two lines cross — a read
               | ".[" line_operand+ "]"                          ; meet (n-ary): the point on all listed lines
line_operand  := CREASE_NAME                                     ; named crease, or a prelude edge (--ab --bc --cd --da)
               | point_operand "*" point_operand                 ; join (binary): the existing crease/edge through two points — a read
               | "--[" constraint+ "]"                           ; join / line selector: crease/edge segments incident to all constraints
               | line_operand "&" constraint                     ; filter to incident segments (since v0.17-dev)
               | line_operand "\" constraint                     ; drop incident segments
               | "[" line_operand+ "]"                           ; union of same-typed bundles
constraint    := point_operand | line_operand | "#[" point_operand+ "]"
POINT_NAME    := "." ident
CREASE_NAME   := "--" ident
INSTANCE_NAME := "$" ident

; since v0.20-dev — §4.9; `@` dropped v0.21-dev; renamed `collapse`→`flatten`,
; paren-juxtaposition items, bindable v0.23-dev; one-pipeline model,
; `{toward}` item (was a trailing keyword), `valley` marker v0.23-dev;
; stayer convention, `staying` replaces reserved `standing` v0.23-dev
flatten_stmt  := [ CREASE_NAME "=" ] "flatten" flatten_item+
flatten_item  := "(" flatten_elem ")"
               | "(" over_flap "over" over_flap ")"
               | "(" "staying" flap_operand ")"
               | "{" "toward" point_operand "}"
flatten_elem  := line_operand [ "mountain" | "valley" ]
over_flap     := point_operand | "#[" point_operand+ "]"

; since v0.16-dev — §5a
def_stmt      := "def" ident "(" param* ")" "{" body_stmt* "}"
param         := POINT_NAME | CREASE_NAME
body_stmt     := stmt minus ( def_stmt )
instance_stmt := INSTANCE_NAME "=" "apply" ident "(" operand* ")"
apply_stmt    := "apply" ident "(" operand* ")"
export_stmt   := "export" ( "{" export_entry+ "}" )? INSTANCE_NAME
export_entry  := ( POINT_NAME | CREASE_NAME ) "!"? ( "as" ( POINT_NAME | CREASE_NAME ) )?
```

A motion (`through`/`map`/`perp`) is a pure read: it computes a line but
touches nothing (§4.10). `mark` creases it flat; `fold` creases and folds it
— `moving` anchors the fold, `up to` scopes it, `mountain` sets its
direction (§4.6). Either verb, given a `line_operand` instead of a motion,
acts on an existing material crease instead of computing a new line. `flip`
turns the whole sheet over (§4.7). *(since v0.7-dev)* Any operand may be an
**inline read** (§4.10): `--x * --y` (or `.[--x --y]`) is the point where two
lines meet; `.a * .b` (or `--[.a .b]`) is the existing crease/edge through two
points; `--l & c` / `--l \ c` filter a bundle; `[…]` unions bundles. These
select existing geometry — they never score a crease — and nest freely; the
polymorphic `*` reads as a meet when its operands are lines and a join when
they are points. *(since v0.21-dev)* `@` is retired entirely: writing to the
paper always goes through `mark`, `fold`, or `flatten`. These read forms —
and motions — are also valid directly as a binding's right-hand side — see
the RHS note in §5.

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
[ADR 0011](../decisions/0011-action-model.md). Mountain/valley is *derived* from
fold actions, not a separate annotation pass. *(v0.8-dev)* axiom 6 — fold a
point onto a line with the crease through a fixed point (`map .p onto --d through
.p'`, optional `toward` for disambiguation). *(v0.9-dev)* axiom 7 — the cubic
Beloch fold (`map .p onto --d and .q onto --e`, optional `toward`); irrational
crease coordinates compared exactly (§6). *(v0.16-dev)*
`=` replaces `:` as the binding separator; read-operator RHS;
`def`/`apply`/instances with closed-scope bodies; `export` with shadow/rename
validation (cross-instance access; the earlier bracket member access was
removed in the v0.20-dev notation cutover, §5a.4);
the uniform rebinding rule (see §5, §5a). *(v0.17-dev)*
crease-segment selection — the `&` filter, projecting a crease name (a
bundle of segments) to one segment by incidence (ADR 0014). *(v0.18-dev)* fold
scope — flap-typed `moving` (point/line/`#[...]` anchor operands, ADR 0016),
`up to` for some-layers simple folds, and `@fold` along an existing material
crease. *(v0.20-dev)* `@collapse` — single-vertex flat collapse: n ≥ 4
material creases sharing one interior vertex, checked by Kawasaki, Maekawa,
and layer-order validity, with `over` for stacking ties; `standing` parses
but is not yet implemented (§4.9); the **notation cutover** — reads become
operators (`*` meet/join, `&` filter, `\` drop, `[]` union, the `.[] --[] #[]`
selectors), the one write was the keyword `through`, and bracket member access
retires in favour of `export` (§4.10, design doc). *(v0.21-dev)* the
**mark/fold notation cutover** — `map`/`through`/`perp` motions become pure
reads (joining the v0.20-dev operators); the writes are the keyword verbs
`mark` (crease flat, FOLD `F`) and `fold` (crease and fold, FOLD `M`/`V`);
`@collapse` is renamed `collapse`; `@` is retired entirely from the grammar;
`U` is no longer emitted (§7). See
[`docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md`](../docs/superpowers/specs/2026-07-09-mark-fold-crease-notation-design.md).
*(v0.23-dev)* **`flatten` generalizes `collapse`, one solver pipeline** —
`collapse` is renamed `flatten`; the item list drops `and` for parenthesised
juxtaposition (`flatten (--a & .p) (--b & .q) …`); `flatten` is bindable
(§4.9); and, given an odd set of rays sharing a vertex, `flatten` solves for
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
runs, rather than derived from the solved stack afterward. See
[`docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md`](../docs/superpowers/specs/2026-07-15-flatten-generalizes-collapse-design.md),
[`docs/superpowers/specs/2026-07-16-flatten-derive-v2-design.md`](../docs/superpowers/specs/2026-07-16-flatten-derive-v2-design.md),
and
[`docs/superpowers/specs/2026-07-17-flatten-staying-design.md`](../docs/superpowers/specs/2026-07-17-flatten-staying-design.md).
*(v0.26-dev)* **layer placement**: `fold … over/under <flap>` inserts the
moved flap between layers, and the **`reverse`** verb folds inside and
outside reverse folds as two placed half-folds with derived letters (§4.6,
§4.6a).

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
