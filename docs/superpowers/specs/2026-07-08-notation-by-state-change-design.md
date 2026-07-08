# Notation by state-change — the keyword/operator law, selectors & meet (design)

## Status

Proposed (2026-07-08). **Supersedes** `2026-07-07-bundle-algebra-selection-design.md`:
it adopts that doc's `&` filter, `\` diff, `[…]` union and `#[…]` flap bracket,
reverses its "keep `.()`" decision, and resolves its open Q1 (filter symbol) as
**`&`**. The reversal is driven by a governing law that document did not state;
this document states it and derives the whole surface from it.

**Revised 2026-07-08 (join).** An earlier draft of this doc killed `--[…]` and
made *every* line through two points the `through` keyword. The corpus refuted
that: ~72 `--(.a .b)` operand uses are pure **reads** — references to lines that
already exist (mostly paper edges). So `--[.a .b]` returns, but as the bundle
algebra always meant it (a **selector** over existing lines), *not* the
constructor the superseded doc proposed. `through` remains the write.

The selectors then unify into **one rule over three sigils** — `.[l+]` (point),
`--[c+]` (line), `#[c+]` (flap) = the geometry incident to all constraints — with
`*` as **polymorphic binary sugar** (`--x * --y` → meet point, `.a * .b` → join
line). See *The selector family* and *The asymmetry*. Instance member access
(`--[$inst m]`/`.[$inst m]`) is removed to free both brackets.

## The law

> **Does the operation mutate paper state — score a crease, fold, and thereby
> re-segment existing references (ADR 0014)? → it is a keyword verb, sequenced in
> program order. Does it only read the current state? → it is a pure read, and
> may be an operator (or a keyword). Writes have no such freedom; reads do.**

The re-segmentation clause is *why* the split is forced: a scoring op splits
existing creases at the new crossing, invalidating earlier segment references, so
it must be a visible, ordered statement. A pure read is a function of the current
state — order-free, safe as notation.

This is the `2026-07-06-fold-history-as-diff` note turned into syntax:
**keywords = commits** (mutations to the versioned sheet), **reads = checkout
queries**. The physical asymmetry it encodes: *finding* where two creases cross is
free; *making* a crease costs a fold. The notation should look different for the
two, and under this law it does.

## Read/write partition

| concept | act | form |
|---|---|---|
| axioms (`through`→rename, `perp`, `map`, `bisect`, …) | **write** (score) | keyword verb |
| `@fold`, `pinch` | **write** (fold/score) | keyword verb |
| select geometry incident to all constraints | read | `.[l+]` (point) · `--[c+]` (line/segments) · `#[c+]` (flap) |
| binary meet/join sugar | read | `--x * --y` → point · `.a * .b` → line |
| filter / exclude a **named** base bundle | read | `--l & c` · `--l \ c` |
| union same-typed bundles | read | `[--x --y]` |
| a **new** line through two points | **write** (score) | `through .a .b` |

Reads are symbols/brackets (`.[] --[] #[] * & \ []`); the one write is a keyword.
The law is legible in the glyphs.

**Join and through are different operations, not two spellings of one.**
`--[.a .b]` *selects* a line that already exists (a crease, or a paper edge). `through .a .b` *scores a new crease* — a write. The old inline
`--(.a .b)` operand conflated them: it produced a geometric line with no backing
crease (a "sight-line"). **Sight-lines are abolished** — every line you name is
either a real crease/edge (select with `--[]`/`*`) or one you deliberately score
(`through`). See *Sight-lines* below.

## The selector family — one rule, three sigils

> **`SIGIL[c₁ c₂ … cₙ]` = the SIGIL-typed geometry incident to *all* the
> constraints.** The bracket supplies the universe (all points / all
> creases+edges / all flaps); the constraints conjoin.

| form | selects | constraints |
|---|---|---|
| `.[l+]` | the **point** on all the listed lines (n-ary meet; concurrent → their common point) | lines |
| `--[c+]` | the crease/edge **segments** incident to all c's (a bundle → coerce at slot) | points and/or lines |
| `#[c+]` | the **flap** incident to all c's (singular) | points (and/or lines) |

Incidence is type-directed: a line *through* a point / *crossing* a line; a point
*on* a line; a flap *containing* a point. So `--[.a --d]` = the line through a
that crosses d; `.[--x --y]` = where x and y cross; `#[.a .b]` = the flap holding
a and b. A point-constraint on a point selector is degenerate (`.[.a .b]` is
meaningless — the point sigil takes lines).

Errors if nothing (or, where a singular result is demanded, more than one) is
incident to all constraints — `--[]`/`.[]` never conjure geometry that isn't
there (no sight-lines).

**`*` is the binary sugar for the two-argument case, polymorphic on operand
type:**

```
--x * --y     ; two lines  → their meet point   ≡ .[--x --y]
.a * .b       ; two points → their join line     ≡ --[.a .b]
```

Both are reads (the operator names existing geometry; it scores nothing). `*`
covers the overwhelmingly-common binary meet/join; the brackets cover n-ary and
mixed-constraint selection. `#[…]` has no `*` sugar (a flap isn't a dual pair).

`&` / `\` then *restrict* a **named** base bundle that isn't a bracket
(`--l & c` / `--l \ c`); inside a bracket `&` would be redundant (`--[a b]` ≡
`--[a] & b`), and `\` (exclusion) is the one thing the positive-conjunction
bracket can't express, so it stays an operator. `[ … ]` unions same-typed bundles.

## Surface syntax

### Filter — `&` (replaces `at`)

`bundle & constraint` keeps the elements of `bundle` incident to `constraint`.
A constraint is a point, a line, or a region (`#[…]`). Chaining conjoins:

```
--l & .p            ; segments of --l through p
--l & .p & --d      ; through p AND crossing d   (was: --l at (.p and --d))
--l & #[.m]         ; segments lying in flap .m  (was: --l at #(.m))
```

`&` produces a **sub-bundle** (0..n). Singleton coercion is a **slot** concern
(ADR 0016): a slot that wants exactly one line demands cardinality 1 and errors
otherwise (`--l & … matched k segments; add a constraint`). Filter no longer
conflates "pick" with "must be one" — today's `at` does both at its call sites
(`eval.ml:293/328/427`); this splits them.

**`&[…]` conjunction sugar is deferred.** `[.p --d]` cannot be a union (union is
same-typed; this is heterogeneous), so `&[…]` would be a distinct operator that
gives `[]` a second, filter-only meaning. The chain covers every realistic case
(rarely >2 incidences pin a segment); add the sugar later only if it bites.

### Negated filter — `\`

`bundle \ constraint` keeps elements **not** incident to `constraint`. The natural
"other ray": with `--ba` split at the vertex, `--ba \ .a` is the segment *away*
from `a` without naming its far endpoint. Chains and mixes with `&`:

```
--ba \ .a           ; the o→rm ray
--l & .p \ .a        ; through p but not through a
```

### Union — `[ … ]`

`[a b …]` is the union of same-typed bundles, a value usable anywhere a bundle is:

```
[--x --y]           ; both creases' segments as one bundle
[--x --y] & .p       ; …then filtered to those through p
```

Heterogeneous lists are a type error (`cannot union a crease with a point`).

### Flap selection — `#[ … ]` (replaces `#(…)`)

`#[.a .b]` selects the flap/region determined by the listed points.
**Granularity stays context-typed**, exactly as `#(…)` is today: FACE precision
(`face_of_points`, ADR 0014) inside a filter or a collapse sector; coplanar
cluster (ADR 0017) in `moving`/scope slots. No `face[]`/`flap[]` split in this
slice. (The discomfort with the face-vs-cluster distinction itself is logged as a
separate ADR-0017 concern — see *Parked*.)

### Meet & join — `.[]` / `--[]` and the `*` sugar (replace `.(…)`, `cross`, `--(…)`)

Per the family rule above, `.[l+]` is the point on all listed lines (meet) and
`--[c+]` is the crease/edge segments incident to all constraints (join). `*` is
the binary sugar, polymorphic on operand type:

```
.o   = --ba * --bb        ; two lines  → meet point   ≡ .[--ba --bb]
--e  = .a * .b            ; two points → join line     ≡ --[.a .b]
.tip = --r * --[.a .b]    ; meet of --r with the a–b line
```

Both directions are reads — the operator names existing geometry (a crossing, a
crease/edge) and scores nothing. Join operands must resolve to a **real** line (a
crease or paper edge); if no crease/edge passes through the points it **errors**
— it never conjures a sight-line. `.(--x --y)`, `cross`, and the `--(…)` operand
all retire into this.

**Paper edges are selectable lines.** The four boundary edges resolve through
their corner points, and the prelude also names them for convenience:

```
--ab  --bc  --cd  --da        ; prelude: the four paper edges
```

so `--[.a .b]`, `.a * .b`, and `--ab` all denote the bottom edge; prefer `--ab`.

### Constructing a new line — the axiom keyword (`through`)

`through .a .b` (Huzita axiom 1) **scores a new crease** — a write, a keyword.
Use it when the line you need is *not* already there. This is the only way to add
a line; there is no operator for it.

```
--e = through .a .b       ; scores a fresh crease; bind to name it
```

## The asymmetry, stated

Read/write classifies **operators**, not geometry. A meet point and a join line
are just a point and a line — facts, neither read nor write. The *operators* that
name them are the reads: the `.[] --[] #[]` selectors and their `*` sugar — pure
selections over geometry that already exists, neither touching the paper.
`through` (points→**new** line) is the odd operator out: a **write**, and the only
one, because scoring a crease is the only act here that changes the sheet. Meet
and join look identical (`*`, or a bracket) precisely because both only *read*;
`through` looks different (a keyword) precisely because it *writes*. The notation
is honest about which touches the paper.

## Consequences

- **Sight-lines are abolished.** The old `--(.a .b)` *operand* produced a
  geometric line with no backing crease/edge; it neither scored (as an operand,
  `eval.ml:285`) nor existed physically. Every line you name is now either real
  (`--[.a .b]` selects an existing crease/edge, or a prelude edge name) or
  deliberately scored (`through`). A reader never has to guess whether a nested
  `--(…)` scores (statement position did, `eval.ml:1049`; operand position did
  not) — the positional overload is gone, and so is the physically-impossible
  "fold onto an uncreased line."
- **Instance member access is removed** (`--[$inst m]`, `.[$inst m]`, the
  `PMember`/`LMember` AST). It collided with the freed `--[`/`.[` brackets and
  only ever returned one member; cross-instance access goes through `export`
  instead. Frees `--[` for join and `.[` for future point selection.
- **Corpus rework, not just migration.** Examples that referenced a sight-line
  (a diagonal used as a fold target, a corner-to-apex line) must now **construct
  that line first** with `through` — a real crease that adds geometry and moves
  the golden. Affected: the `iteration/*` set (corner-to-apex bisector
  constructions) and a few `syntax/*` (diagonal fold targets:
  `inline-midpoint`, `bisect-b`, `bisect-straddle`). This is honest — you cannot
  physically fold onto an uncreased line — but it is per-example design work, not
  a sed.
- **Filter/diff results bind** as bundles (`--seg = --l & .p`), a multi-match
  binding a multi-element bundle. Motivating case: pre-selecting a crease to
  reference in a later render op. Coercion to one line fires only at singleton
  slots.
- **No construct-vs-select marker** on brackets — the sigil (`.`/`#`/`--`) and the
  operator already carry found-vs-made.
- **`()` is freed for pure grouping.** Retiring `.(`, `--(`, `#(` removes the
  maximal-munch sigil-paren openers (`POINT_OPEN`/`LINE_OPEN`/`FLAP_OPEN`), so `(`
  can no longer be shadowed by a preceding sigil — `(--a * --b)` can never munch
  into `.(…)`. This is what makes the precedence grouping above (`(--l & .p) * --s`)
  unambiguously writable; the churn doesn't just free the parens, it enables the
  precedence story.

## Migration (pre-1.0 churn, acceptable)

The **read-selector** rows are mechanical; the **sight-line** rows are per-example
rework (they move goldens).

| from | to | kind | files |
|---|---|---|---|
| `--l at <sel>` | `--l & <sel>` | mechanical | 18 |
| `--l at (S1 and S2)` | `--l & S1 & S2` | mechanical | 0 real (comments/tests) |
| `#(…)` | `#[…]` | mechanical | 6 |
| `.(--x --y)` | `--x * --y` | mechanical | 9 |
| `cross --x --y` | `--x * --y` | mechanical | 9 |
| `--(.a .b)` operand, **edge** | `--[.a .b]` or prelude `--ab`/… | mechanical | ~71 uses |
| `--(.a .b)` operand, **sight-line** | `through .a .b` first, then reference it | **rework** (moves golden) | ~16 uses |
| `--(.a .b)` statement bind | `through .a .b` | mechanical | 1 (`iteration/001`) |

Counts from the corpus survey (2026-07-08): of ~72 `--(` operand uses, ~71 are
paper edges (safe → `--[]`/prelude), ~16 are sight-lines needing construction (8
diagonals-as-targets, 8 corner-to-apex).

Lexer/parser deltas: **remove** `AT_KW`, `LINE_OPEN` (`--(`), `POINT_OPEN`
(`.(`), `CROSS`, `LINE_MEMBER_OPEN`/`POINT_MEMBER_OPEN` (instance access), and the
`at (… and …)` production; **add** tokens `&`, `\`, `*`, `[`, `#[`; repurpose the
freed `--[` and `.[` as the **line** and **point** selectors (`--[c+]`, `.[l+]`)
now that instance access is gone. AST: `LAt` → an n-ary filter node; a **single
`Select`-style node per sigil** (point/line/flap incident-to-all); `LThrough`
and `Cross`/`PCross` dropped in favour of it; `PMember`/`LMember` removed. `*` is
**polymorphic binary sugar**: `line * line` → the point node (meet), `point *
point` → the line node (join) — one `STAR` production over both operand types,
disambiguated by the operand sigil (watch for an LR conflict; the operands'
leading `--`/`.` tokens should separate the two). New prelude binds
`--ab`/`--bc`/`--cd`/`--da`. Tree-sitter grammar regenerated regardless.

**Status:** the additive read operators (`* & \ #[] []` + bundle binding) are
**shipped** (Tasks 1–5 of the plan). The join selector `--[.a .b]`, prelude edges,
instance-access removal, sight-line rework, and old-syntax removal are **not yet
built** — they are the next slice, deliberately staged because the sight-line
rework changes example outputs.

## Parked (not this slice)

- **`through` (and other axiom) naming pass** — `cross` is already gone; revisit
  `through`. Separate change, pure keyword rename.
- **Face-vs-flap-cluster granularity** — the deeper unease with the ADR-0017
  distinction; its own issue, not spelling.
- **`&[…]` conjunction sugar** — deferred until the chain proves painful.
- **Precedence** — `&`/`\` bind tighter than `*` (a filtered crease resolves to
  one line before meet consumes it: `(--l & .p) * --s`). Pinned at
  implementation.
- **Two future primitives sorted by the law**, captured in
  `notes/2026-07-08-partial-creases-and-rational-landmarks.md`: *partial creases*
  (a write — keyword — that reopens the #26 face-boundary invariant `pinch`
  avoided) and *rational landmarks* (`3/4 along --l`, a read — operator — exact via
  the kernel, just underived). Each their own slice; both validate the read/write
  split.

## References

- ADR 0011 (action model — the keyword/verb boundary this formalises), 0014
  (crease = bundle of segments — the re-segmentation the law turns on), 0016
  (typed operands: bundles are values, singletons are slot results), 0017 (face
  vs flap granularity — the `#[]` context-typing).
- `notes/2026-07-06-fold-history-as-diff.md`, `…-fold-as-operation-sequence.md`
  (keywords = commits, reads = queries).
- `docs/superpowers/specs/2026-07-07-bundle-algebra-selection-design.md`
  (superseded).
- `docs/superpowers/specs/2026-07-07-flatten-primitive-design.md` (the downstream
  consumer whose hinge/return selectors adopt `&`/`\`).
- Selector implementation today: `lib/lexer.ml`, `lib/parser.mly`, `lib/ast.ml`,
  `lib/eval.ml` (`at_matches` :351, singleton coercion :293/:328/:427, `LThrough`
  operand :276, subdivide-on-bind :1049).
</content>
</invoke>
