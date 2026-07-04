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

Current version: **v0.16-dev** (`def`/`apply`/instances, qualified access, `export`, `step` panels; `=` binding separator); **v0.9-dev** (axiom 7 — cubic Beloch fold, two points each onto a line); **v0.8-dev** (axiom 6 — fold a point onto a line, crease through a fixed point); **v0.4-dev** (axiom 4 — project a point onto a line); **v0.3-dev** (axiom 5 — angle bisector); **v0.2** (axiom 3 — perpendicular through a point); **v0.1** (faces); **v0.0** (minimal core).

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
lines is generally irrational (slope `√2−1` for `y=0` and `y=x`). Results are
therefore reals beyond ℚ, but equality, parallelism, and on-paper tests stay
**exact** (§6).

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
only. Cube roots do not arise here; they first appear at axiom 7 (§4.5c). See
"A note on axiom numbering" in §1.

`through` is the same verb as in axiom 3 (`perp --l through .p`): the crease
passes through the named point. `toward` is the same selector as axiom 5.

Errors: the lines/points being out of reach (`dist(p',D) > |p'p|`) raises *out of
reach*; two solutions without `toward` raises an ambiguity error naming the
selector; `.p` and `.p'` being the same point raises *no fold exists*. When `.p`
already lies on `--d`, the identity landing is dropped and the mirror landing
gives the crease.

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

**Solutions and `toward`.** When the cubic has three real solutions (`toward` is
required); when it has one real solution, `toward` is ignored. `toward .x` picks
the solution whose first folded point (the image of `.p` on `--d`) lands nearest
`.x`, measured by exact squared distance.

**Errors:**

- `.q` **already lies on `--e`** — the second constraint is vacuous; the fold
  reduces to axiom 6 or axiom 4 depending on the remaining constraint. Beloch
  raises an error naming the appropriate axiom.
- `--d` and `--e` are **parallel** — the cubic degenerates and the system is
  ill-defined; Beloch raises an error.
- Three solutions and **`toward` omitted** — ambiguous; Beloch raises an
  ambiguity error naming the selector.

**Provenance.** Each crease edge carries `"axiom": "axiom7"` in `beloch:edges`.

**Number theory.** The landing-parameter cubic generically has no rational root,
so its real roots are irrational — they live in `ℚ(α)` for an algebraic `α` of
degree 3. All coordinates of one axiom-7 crease lie in that same `ℚ(α)`. See §6.

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
  --d1 = through .a .c             ; named precrease
  map .a onto .c                   ; anonymous precrease
  @map .a onto .c moving .a        ; fold (valley)
  ```
- **Point statement** — binds a derived point:
  ```
  .center = cross --d1 --d2
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

**Shorthand RHS** *(since v0.16-dev)*: the inline anonymous-construction forms
(Appendix A) are also valid directly as a binding's right-hand side, as sugar
for the equivalent named construction:

```
.s  = .(--rs --(.d .c))    ; sugar for: .s = cross --rs --(.d .c)
--e = --(.p1 .p2)          ; sugar for: --e = through .p1 .p2
```

**Identifiers** *(since v0.16-dev)* are `[a-zA-Z0-9_]+` — underscore, never
`-`; kebab-case is reserved so it doesn't foreclose future numeric/arithmetic
syntax (`repeat n`, ratios) or create whitespace ambiguity next to the `--`
sigil.

> Concrete syntax (keywords, sigils) is stable as of v0.0 but may still be
> revised before v1.0.

---

## 5a. Defs, instances, steps *(since v0.16-dev)*

Four constructs extend program structure beyond flat top-to-bottom bindings.
They share **one evaluation path**: `def` never runs (it only records a
deferred body); `apply` is the *only* execution form — it folds immediately
and yields a retained instance; `export` only reads from an instance, never
re-runs anything; `step` is display metadata with no execution effect at all.
Full design rationale is in
[`docs/superpowers/specs/2026-07-02-step-macros-design.md`](../docs/superpowers/specs/2026-07-02-step-macros-design.md).

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
  @map .p onto .q moving .p
  .tip = cross --(.p .q) --base
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
  `apply`, `export`. Not allowed inside a body: `def`, `step`.
- The body never runs at `def` time — only `apply` runs it (§5a.3).

### 5a.3 `apply` and instances

```
$p1 = apply petal(.k1 .k2 --(.k1 .k3))   ; folds now; instance retained
apply petal(.k2 .k4 --(.k2 .k1))          ; folds now; namespace discarded
```

- `$name` is the **instance** sigil — its only use. `apply` is the only RHS
  a `$`-binding accepts; instances cannot be aliased or constructed any
  other way.
- Arguments are ordinary point/crease operands (named or inline forms),
  matched to parameters by position; sigils must agree.
- `apply` always executes the body immediately, against the current folded
  state — a bare `apply name(args)` (no `$name =`) still folds; it just
  discards the resulting namespace instead of retaining it.
- The result is an **instance**: a namespace holding every non-temp binding
  the body created.

### 5a.4 Qualified access

```
@map .[$p1 tip] onto .[$p2 tip]
--d = through .[$p1 tip] .[$p2 tip]
.x  = cross --[$p1 pq] --[$p2 pq]
```

- `.[$inst member]` is a point operand; `--[$inst member]` is a crease
  operand. The outer sigil declares the kind being read; the member name is
  bare. Valid anywhere an operand of that kind is valid (including inside
  inline shorthand forms).
- **Errors:** unknown member, member/sigil kind mismatch, or the member is a
  temp (temps are never reachable through an instance).

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
  on every member name unless disambiguated with selective `as` or read via
  qualified access instead.
- `!` marks an intentional shadow and is validated both ways: binding an
  existing name **without** `!` is an error ("name exists, use `!` to
  shadow"); using `!` when the name does **not** already exist is an error
  ("nothing to shadow, remove `!`"). Shadow validation applies only to
  non-temp landing names: exporting onto a temp target (`export { .m as ._t }
  $i`) rebinds it freely and needs no `!`, since temps are single-scope and
  rebindable (§5a.1, §5a.7). Temps remain barred as export *sources*.

### 5a.6 `step` — diagram panels

```
step thirds
._mb = .(--vm --(.a .b))
--pq = through ._pq1 ._pq2

step beloch_fold
@map .c onto --(.a .b) and .s onto --pq
```

- `step ident` opens a display panel that runs until the next `step` or end
  of file; actions before the first `step` are flat/ungrouped, as before
  v0.16-dev.
- The identifier binds nothing — zero namespace footprint. It is a stable
  anchor for the FOLD `"step"` provenance field (§7) and for future
  instruction-JSON / i18n label output; duplicate panel identifiers are an
  error.
- Top level only (not allowed inside a `def` body). Folds produced by an
  `apply` land in whichever panel is open at the `apply` site.

### 5a.7 Rebinding rules

One invariant, uniform across root scope, `def` bodies, and `export`
landings: **a name without a `_` prefix is bound at most once per scope.**

| Situation | Result |
|---|---|
| non-temp name bound twice in the same scope (root or `def` body) | error |
| rebinding a corner `.a`–`.d` at root | error |
| `def` name reused | error |
| `step` panel id reused | error |
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
with no `@` folds still emits at least one folded-form frame; it then
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
  and `"U"` for an unfolded precrease (a crease line with no fold yet). One
  physical fold through several layers can yield different M/V per layer (the
  accordion), since each crease edge carries its own derived assignment.
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
  naked (unbound) `apply`. *(since v0.16-dev)* Each entry also carries
  **`"step"`** — the identifier of the `step` panel (§5a.6) open when the
  crease was produced, or `null` if it precedes the first `step` in the
  program. Additive: stock FOLD consumers ignore both fields;
  `tools/fold2svg.mjs` uses `"name"` to colour/label creases.

**`file_frames` — one `foldedForm` frame per `step` panel snapshot**
*(since v0.16-dev)*: a baseline frame (`"beloch:step": null`) for the state
before the first `step` (or the final state, for a program with no `step`
panels at all), followed by one frame per `step` (§5a.6), in program order.
Each frame is **self-contained** (`frame_parent: 0`, `frame_inherit: false`)
rather than inheriting the parent's topology — an earlier step's state has
fewer faces than the final crease pattern, so it cannot share the parent's
vertex/face indexing. Each frame carries its own:

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
- `"beloch:step"` — the step identifier this frame snapshots, or `null` for the
  baseline frame. A consumer can map a crease to the frame(s) it appears in via
  `beloch:edges[].step` (§ above) against each frame's `"beloch:step"`.

The top-level frame (frame 0) is always the final, cumulative crease pattern —
it does not change with the number of `step` panels. A program with no `step`
panels emits exactly one folded-form frame (`"beloch:step": null`), matching
the pre-v0.16-dev dual-frame shape except that the frame is now self-contained
rather than `frame_inherit: true`.

The renderer/animation client is a separate consumer; `tools/fold2svg.mjs` draws
frame 0 by default and a folded form with `--folded`.

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
              | def_stmt | instance_stmt | apply_stmt | export_stmt | step_stmt   ; since v0.16-dev
crease_stmt   := CREASE_NAME "=" "--(" point_operand point_operand ")"                      ; named, inline through (no fold)
               | [ CREASE_NAME "=" ] [ "@" ] axiom [ "moving" point_operand ] [ "mountain" ] ; named or anonymous, axiom-based (fold only with @)
point_stmt    := POINT_NAME "=" point_expr
flip_stmt     := "flip"
axiom         := "through" point_operand point_operand          ; axiom 1
               | "map" point_operand "onto" point_operand       ; axiom 2
               | "perp" line_operand "through" point_operand     ; axiom 3
               | "map" point_operand "onto" line_operand "perp" line_operand  ; axiom 4
               | "map" line_operand "onto" line_operand [ "toward" point_operand ]  ; axiom 5
               | "map" point_operand "onto" line_operand "through" point_operand
                     [ "toward" point_operand ]                                  ; axiom 6
               | "map" point_operand "onto" line_operand
                     "and" point_operand "onto" line_operand
                     [ "toward" point_operand ]                                  ; axiom 7
point_expr    := "cross" line_operand line_operand              ; line intersection (binding RHS)
               | ".(" line_operand line_operand ")"              ; inline cross (binding RHS)
point_operand := POINT_NAME | ".(" line_operand line_operand ")"     ; named, or inline cross
               | ".[" INSTANCE_NAME ident "]"                        ; qualified member (since v0.16-dev)
line_operand  := CREASE_NAME | "--(" point_operand point_operand ")" ; named, or inline through
               | "--[" INSTANCE_NAME ident "]"                       ; qualified member (since v0.16-dev)
POINT_NAME    := "." ident
CREASE_NAME   := "--" ident
INSTANCE_NAME := "$" ident

; since v0.16-dev — §5a
def_stmt      := "def" ident "(" param* ")" "{" body_stmt* "}"
param         := POINT_NAME | CREASE_NAME
body_stmt     := stmt minus ( def_stmt | step_stmt )
instance_stmt := INSTANCE_NAME "=" "apply" ident "(" operand* ")"
apply_stmt    := "apply" ident "(" operand* ")"
export_stmt   := "export" ( "{" export_entry+ "}" )? INSTANCE_NAME
export_entry  := ( POINT_NAME | CREASE_NAME ) "!"? ( "as" ( POINT_NAME | CREASE_NAME ) )?
step_stmt     := "step" ident
```

A bare axiom statement is a *precrease* (computes a crease line, paper stays
flat). The `@` prefix performs the fold (§4.6); `moving`/`mountain` describe it.
`flip` turns the whole sheet over (§4.7). *(since v0.7-dev)* Any operand may be an
**inline anonymous construction** — `--(.a .b)` is the line through two points,
`.(--a --b)` the point where two creases meet; these nest freely and coexist with
the `cross`/`through` keywords (which remain for named bindings). *(since
v0.16-dev)* These inline forms are also valid directly as a binding's
right-hand side — see the shorthand RHS note in §5.

---

## Appendix B — not yet in the language

Deferred, in rough order of likely arrival: non-flat (constructible-angle) folds ·
`rotate` · fold maneuvers (reverse/squash/sink/petal, via `unfold` + layer
selection) · regions · parts/imports · nested `def`s and namespace chaining
(`.[$b1 $d tip]`) · re-export cascades · string labels in source (i18n stays
external) · `pub`/`priv` interfaces · looping primitives · module/file-level
namespacing · a dedicated render/animation engine · YR diagrams. These are not
part of the language until a slice lands and this spec is extended.

**Landed:** faces (v0.1); axiom 3 — perpendicular (v0.2); axiom 4 — projection (v0.4-dev); axiom 5 — angle
bisector (v0.3-dev); the `map … onto …` verb and the `@` fold modifier
(v0.6-dev); and *(v0.7-dev)* the **action model** — `@` fold execution, the
folded-state runtime, derived mountain/valley, the dual `creasePattern` +
`foldedForm` FOLD output, `flip`, and inline anonymous operands
(`--(.a .b)` / `.(--a --b)`). See
[ADR 0011](../decisions/0011-action-model.md). Mountain/valley is *derived* from
fold actions, not a separate annotation pass. *(v0.8-dev)* axiom 6 — fold a
point onto a line with the crease through a fixed point (`map .p onto --d through
.p'`, optional `toward` for disambiguation). *(v0.9-dev)* axiom 7 — the cubic
Beloch fold (`map .p onto --d and .q onto --e`, optional `toward`); irrational
crease coordinates compared exactly (§6). *(v0.16-dev)*
`=` replaces `:` as the binding separator; shorthand inline-construction RHS;
`def`/`apply`/instances with closed-scope bodies; qualified member access
(`.[$inst m]` / `--[$inst m]`); `export` with shadow/rename validation;
`step` diagram panels; the uniform rebinding rule (see §5, §5a).

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
