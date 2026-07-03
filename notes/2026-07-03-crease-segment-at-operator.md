# 2026-07-03 — the crease bundle and the `at` operator

Design record for how a program refers to a crease and to its individual
*segments*. Converged in discussion; **not yet implemented** — this is the spec
fragment a later slice builds against. Companion:
`2026-07-03-crease-layer-selection.md` (creating creases: bind vs `pinch`).

## The question that started it

Do we need separate sigils for creases vs. crease-segments? **No** — and chasing
that answer produced a fuller model: a crease name does not denote a line, it
denotes a **bundle**.

## `--l` is a crease bundle

`--d = through .a .b` runs `subdivide`, which tags **every crossed face's** new
edge with one shared `crease_id` (`eval.ml:349`, `fold_state` seeds one edge per
face actually cut). So `--d = Material(cid, l_orig)` names a crease *identity*
that materially is a **set of segments** — one per layer the line crossed, plus
any later planar splits. `--d` was always a bundle; the data model already carries
it (shared `crease_id`).

### Two sources of segment multiplicity

1. **Crossing** (planar) — a segment is later cut *in the plane* by another
   crease → contiguous sub-segments on one layer.
2. **Stacking** (parallel) — a crease drawn across N layers is N segments from
   birth, one per layer, coincident in table-space but material on different
   layers. Not contiguous — parallel copies.

Each segment is the axis **clipped to its face polygon**, so bundle segments
generally have **different lengths** (and may occupy disjoint intervals of
`l_orig`, with gaps): a `--d` is never "the line from a to b", it is "these
chords". Length is a per-segment property, orthogonal to collinearity — a possible
future selector (`at longest` …), but that is deferred set-value territory.

### Collinear only in the folded form

The bundle's segments are collinear **only in the folded configuration at
creation** (they share `l_orig`, a table-space line). Folds are reflections; each
layer reached its place by a different composition of them. So under **unfold**
each segment maps to a differently placed and oriented preimage: in the **crease
pattern** the bundle is a scatter of straight segments pointing every which way
(exactly how one "fold through the stack" becomes many CP creases). There is no
global line for `--d` — `l_orig` is folded-form-relative and goes **stale** once
(un)folding scatters the bundle.

## The singleton-target rule

**Using a bundle as the target of an operation requires it to have cardinality
one.** A length-1 bundle arises three ways:

- **unsegmented** — a fresh/flat crease still a single trivial segment;
- **`pinch`** — single by construction (companion note);
- **`at`-disambiguation** — narrowing a longer bundle down to one segment.

`at` is best read as **bundle → length-1 bundle**: it does not leave the type, it
shrinks the set to a singleton. Consuming a bundle of length >1 directly is an
**error**, with a hint to disambiguate — the same shape as #28's `bent→error`
(and `at` is the grown-up form of that note's `#(...)` escape hatch).

Corollary for **bare `--d` used as a line** (axis to reflect/fold across): the
collapse to `l_orig` is valid **iff the bundle is currently collinear** (fresh,
single-layer, unscattered). Once unfold/refold has scattered it, the collapse is
refused → you must select a segment with `at`, and *that* segment supplies its own
current supporting line. `at` itself is incidence-based, so it works in **any**
form — folded or CP — unlike the collinearity-dependent collapse.

## The operator: `at`

```
--l at .p               ; segment .p lies on
--l at --a              ; segment --a meets
--l at #(.a .b .c)      ; segment lying in that flap  (region form — tentative)
--l at --a and --b      ; two selectors, joined by `and`
--l at .p and --a       ; mixed — meaningful when .p is a vertex (2 candidates)
```

`at` **replaces** the old `--( --d #(...) )` restrict wrapper (`LRestrict`),
freeing `--( … )` to mean *only* `LThrough` (line through two points) — the shared
`--(` open-token previously branched on point-vs-crease content, i.e. two opposite
ops (build a line vs. clip a line) under one wrapper. Gone.

### Selection rule (incidence)

`--l at S1 [and S2]` = **the unique segment of `--l` incident to every selector
Si.** Incidence per kind:

- **point** `.p` on `--l` — matches the segment(s) it lies on. Interior to a
  sub-segment → matches **one** (standalone, complete). On a subdivision **vertex**
  (a crease crossing `--l`) → matches the **two** neighbours sharing that vertex,
  so it needs a second selector. The cases never overlap, so the universal
  cardinality rule covers both. A vertex point is **equivalent to the crease
  through it** as a selector (same locus `--a ∩ --l`) — no need to name that crease.
- **line** `--a` / `--(.a .b)` — matches the segment whose span contains
  `--a ∩ --l`. Whether `--a` *ends at* or *crosses* `--l` is immaterial (two lines
  meet in ≤1 point); only whether that point lands on the segment.
- **region** `#(…)` — the segment lying in that flap. Tentative (below).

Cardinality: **0 → error** ("no such segment"), **>1 → error** ("ambiguous, add a
selector"). Contiguity is automatic — you pick one of the pieces `--l` is already
subdivided into.

**Two selectors always suffice, never more** — a segment has exactly two
endpoints. Cap = 2. The common case needs one; the second only disambiguates a
shared vertex.

**Crossing subtlety.** A crossing line selector must not itself materially
subdivide `--l` (else the target is split and is no longer one segment). So a
crossing selector is a line meeting `--l` geometrically without acting as a
material fold of it (another layer, or a pure reference line).

**Two selectors join with `and`** (already axiom 7's junctor). Nested context —
`map .p onto (--l at --a and --b) and .q onto --e` — needs the inner `and` bound
to `at`, outer to `map`: resolve by parenthesising the `at` expression or by
binding it to a temp crease first (`--seg = --l at --a and --b`, then use
`--seg`).

### Result

`at` yields a **length-1 bundle** — usable anywhere an operation target is. It
carries its own current supporting line (geometry, for reflection) and its
material identity (`crease_id`, for folding). Remains a `line_operand`.

## Why `at`, not infix `@`

`@` is the **fold marker** (§4.6): leading `@` performs the fold, its absence
leaves paper flat (§7). Beyond parse position, `@` is a **searchable semantic
marker** — a reader/tool greps `@` for "where does this fold?"; an infix `@` for
restriction dilutes that scan. A keyword keeps the fold-signal greppable. Hence
`at` (also the word that arose naturally describing the feature).

## `at` vs. `toward` — separate on purpose

| | `toward .x` | `at .p` |
|---|---|---|
| relation | **proximity** — `.x` off the result | **incidence** — `.p` on the result |
| domain | discrete **axiom solution set** (which line to construct) | **segments** of an existing bundle |
| phase | construction-time | reference-time |

Confirmed in the spec: `toward .x` picks "the landing nearer `.x`"
(SPECIFICATION.md §4, l. 233, 273). Unifying would blur "is the point on the
thing, or indicating a side?" — the exact distinction to keep. Mnemonic:
**`toward` disambiguates construction; `at` disambiguates reference.**

## Region form is tentative

`at #(…)` is kept but flagged *possibly unnecessary*: a flap is a cycle of
boundary edges, so `at #(…)` ≈ `at` two of those edges. Whether it earns its place
is deferred until the language shows whether naming whole flaps pays off. Do not
entrench.

## Open grammar items (for the implementing slice)

- **Precedence.** `at` binds tighter than axiom keywords:
  `perp --l at --a through .b` = `perp (--l at --a) through .b`.
- **`and` collision** with axiom 7 — see above; likely an LR conflict to settle,
  resolved via parens or a temp binding.
- **Result type.** A length-1 bundle, usable as any `line_operand`; carries line +
  `crease_id`.

## Debugging bundle ambiguity (tooling, not language)

The singleton-target rule makes ">1 ambiguous" a routine outcome, so
disambiguation must not be blind — the tooling has to show what is in a bundle.
This is an **evaluator/tooling** affordance, never `.bel` surface syntax
([[beloch-language-vs-implementation]]).

- **Error enumeration.** When `at` (or a bare-bundle target) finds >1, the error
  lists the candidate segments with distinguishing attributes: `crease_id`,
  layer/face, folded-form **and** CP endpoints (they diverge under scatter),
  length, position on `l_orig`, provenance step/axiom. Turns "add a selector" from
  a dead-end into a menu.
- **Selector suggestion by reachability.** Scan existing **named constructions**
  (points, lines) for incidence against each segment — cheap: `O(n·(P+L))` exact
  predicates, all small, interactive (speed is a non-issue). For each ambiguous
  segment, suggest the incident named selectors ("use one of these"). A named
  interior point → a one-selector fix; only crossing lines → a pair.
- **Unreachable segments.** Flag segments touched by *no* existing construction:
  they cannot be named with what exists, so you must first construct a new
  reference point/line onto them. Especially valuable in the unfold-and-continue
  workflow, where many scattered segments accumulate.
- **Surfaces (one computed basis, two views).** A **textual** list suffices for
  the error/CLI — no terminal origami rendering needed. The rich UX is the
  **editor-synced renderer** (the VS Code live view): highlight the bundle's
  segments, click to insert the `at …` selector. That synced view *is* the REPL,
  so a terminal renderer is unnecessary.

## Deferred: the bundle as a first-class value

Selecting a **subset** (>1 but not all) would make the bundle a manipulable
*value* — an array of segments, its own datatype, and the point at which the
sigil question genuinely reopens. Deliberately **not now**: single-segment work
goes through `at`/`pinch`, bulk work through a whole-bundle operation (bind — see
companion note). Revisit only if subsets prove common.

## Data model already backs this

`fold_state` edges carry `crease_id` + endpoints (`ea`/`eb`), subdivided at every
crossing. The material identity that makes a segment unique across coincident
layers (distinct `crease_id`s even at identical table-space geometry) is already
present; `at` is a query over the existing subdivision, not new state.
