# Notation by state-change — the keyword/operator law, selectors & meet (design)

## Status

Proposed (2026-07-08). **Supersedes** `2026-07-07-bundle-algebra-selection-design.md`:
it adopts that doc's `&` filter, `\` diff, `[…]` union and `#[…]` flap bracket,
but **reverses** its `--(…) → --[…]` rename and its "keep `.()`" decision, and it
resolves that doc's open Q1 (filter symbol) as **`&`**. The reversal is driven by
a governing law that document did not state; this document states it and derives
the whole surface from it.

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
| segment filter | read | `--l & .p`  (n-ary chain: `--l & .p & --d`) |
| negated filter / opposite ray | read | `--l \ .a` |
| bundle union (same-typed) | read | `[--x --y]` |
| flap selection | read | `#[.a .b]` (context-typed granularity) |
| point from two lines (meet) | read | `--x * --y` |
| line from two points | **write** (score) | the axiom keyword — **no operator, no bracket** |

Reads are now *all* symbols (`* & \ #[] []`); writes are *all* keyword verbs. The
law is legible in the glyphs.

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

### Meet — `*` (replaces `.(…)` and the `cross` keyword)

`--x * --y` is the point where two lines cross — a pure read (naming an existing
crossing scores nothing). It is the **only** spelling: the `.(--x --y)` bracket
**and** the `cross` keyword both retire.

```
.o = --ba * --bb
.tip = --r * --e         ; --e a named crease, not an inline construction
```

Operands must be lines that *exist* — a scored/named crease or a paper edge —
because inline line-construction is gone (below). `.a * .b` (two points) is a type
error: meet is lines→point.

### Line from two points — the axiom keyword only

There is **no `--[…]`** and no inline `--(…)`. A line through two points is
Huzita axiom 1; it scores the sheet; by the law it is the keyword (`through`,
pending rename), never a lookup bracket:

```
--e = through .a .b       ; scores; bind to name it
```

This is the reversal of the superseded doc, which added `--[.a .b]`.

## The asymmetry, stated

Meet is a read-operator (`*`); line-from-points is a write-keyword. The two dual
constructions of projective geometry get **deliberately unequal** notation,
because they are physically unequal: the crossing point is already there to be
read; the joining line has to be creased into being. The notation is honest about
which acts on the paper.

## Consequences

- **Inline unscored line-construction is gone.** Every line operand is a
  scored/named crease or a paper edge. `.tip = .(--r --(.a .b))` becomes: score
  the crease (`--e = through .a .b`), then `.tip = --r * --e`. This restores the
  read-a-program-as-folds model — a reader never has to guess whether a nested
  `--(…)` scores (it did in statement position, `eval.ml:1049`) or not (operand
  position, `eval.ml:285`); that positional overload no longer exists.
- **Filter/diff results bind** as bundles (`--seg = --l & .p`), a multi-match
  binding a multi-element bundle. Motivating case: pre-selecting a crease to
  reference in a later render op. Coercion to one line fires only at singleton
  slots.
- **No construct-vs-select marker** on brackets — the sigil (`.`/`#`/`--`) and the
  operator already carry found-vs-made.

## Migration (pre-1.0 churn, acceptable)

Mechanical, per the selector map:

| from | to | files |
|---|---|---|
| `--l at <sel>` | `--l & <sel>` | 14 |
| `--l at (S1 and S2)` | `--l & S1 & S2` | 0 real (comments/tests only) |
| `#(…)` | `#[…]` | 6 |
| `.(--x --y)` | `--x * --y` | 9 |
| `cross --x --y` | `--x * --y` | (keyword sites) |
| `--(.a .b)` operand | name the crease, then `*` / reference | subset of 20 |
| `--(.a .b)` statement | `through .a .b` (renamed) | subset of 20 |

Lexer/parser deltas: **remove** `AT_KW`, `LINE_OPEN` (`--(`), `POINT_OPEN`
(`.(`), `CROSS`, and the `at (… and …)` production; **add** tokens `&`, `\`, `*`,
`[`, `]`, and redefine `FLAP_OPEN` as `#[`. AST: `LAt` → an n-ary filter node
(`Keep`/`Drop` of selector); `Cross`/`PCross` reached via `*`; `LThrough` inline
form dropped (the bound-statement axiom path stays). Tree-sitter grammar is
regenerated regardless (it lives only in the docs-site worktree and is already
stale).

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
