# Beloch — Defs, Instances & Steps (Design)

- **Date:** 2026-07-02
- **Status:** Draft — rewrite of the previously approved spec, per findings in #29; #24 folded in.
- **Replaces:** the fused `step`/`export`/`inline` design (see `antipatterns.md`).

## 1. Motivation

Beloch programs grow into flat lists of bindings. Two problems:

1. **Namespace pollution** — every intermediate point/line lives in root scope; names collide and context is lost.
2. **No instruction grouping** — the planned instruction-JSON output (ADR 0002) needs step boundaries; without them every action is a separate diagram step.

The previous design fused these into one `step` construct and gave `$name`
three incompatible meanings (display label / stored macro / retained
namespace). Post-hoc `export` either failed or re-ran the body — physically
double-folding the paper. This rewrite separates the axes and keeps a single
evaluation model.

## 2. Model overview

Four constructs, one evaluation path:

| Construct | Runs? | Purpose |
|---|---|---|
| `def name(params) { body }` | never | define a reusable folding sequence (closed scope) |
| `apply name(args)` | always, immediately | the **only** execution form; folds physically, yields an instance |
| `export { names } $inst` | never | copy names out of an instance into the current scope |
| `step ident` | — | diagram panel marker; display metadata only |

- A `def` body is **deferred**: nothing runs at definition time.
- `apply` runs the body against the current paper state and returns a
  **retained instance** — a namespace value holding every non-temp binding
  the body created. Binding it (`$p1 = apply …`) keeps it addressable;
  a naked `apply …` folds and discards the namespace.
- `export` only *reads* from an instance. It can never re-run anything.
- Scoping (`def`/`apply`/`export`) and diagram grouping (`step`) are
  orthogonal. Scopes nest; panels segment the linear action stream — they
  are different shapes, which is why they are different constructs.

## 3. Bindings

### 3.1 `=` replaces `:`

```beloch
; before                     ; after
--rs: through .rs1 .rs2      --rs = through .rs1 .rs2
.s: cross --rs --(.d .c)     .s   = cross --rs --(.d .c)
```

No `:=`: non-temp constructions are immutable (§9).

### 3.2 Shorthand expressions as RHS

The inline forms `.(--a --b)` (intersection point) and `--(.p .q)` (line
through points) are valid as the RHS of any binding:

```beloch
.s  = .(--rs --(.d .c))    ; sugar for: cross --rs --(.d .c)
--e = --(.p1 .p2)          ; sugar for: through .p1 .p2
```

### 3.3 Identifiers

Identifiers are `[a-zA-Z0-9_]+` — underscore, **never** `-`. Kebab-case
would foreclose numeric/arithmetic syntax (`repeat n`, ratios) and make
whitespace ambiguous next to the `--` sigil.

### 3.4 Temp names: `_` prefix

A name whose identifier starts with `_` (`._mb`, `--_helper`, `$_t`) is a
**temp**:

- **Rebindable.** `._x = …` twice in the same scope is legal; the marker is
  visible at every use site, so the rebinding is never silent.
- **Invisible from outside.** Temps are excluded from instances: not
  reachable via qualified access, not copied by `export` (naming one in an
  export list is an error), never named in FOLD output. A fold bound to a
  temp crease still physically happens — it appears in FOLD unnamed.

Everything about temps is per-name and uniform across scopes (root and def
bodies alike).

## 4. `def`

```beloch
def petal(.p .q --base) {
  @map .p onto .q moving .p
  .tip = cross --(.p .q) --base
}
```

- Def names are **bare identifiers** — no sigil. Sigils mark operand
  kinds, and a def is never an operand; it only ever appears after `def`
  and `apply`. `$` is reserved for instances (§5): one symbol, one
  meaning. Def names live in their own namespace (like panel ids, but
  disjoint from them); duplicate definition is an error (§9).
- Top level only.
- Parameters are typed by sigil: `.name` point, `--name` line. The
  parameter list changes **arity only** — it never changes the evaluation
  or visibility model. Zero parameters is written `def thirds() { … }`;
  the parentheses are always present.
- **Closed scope.** The body sees exactly: its parameters, and defs
  defined textually earlier. Nothing else — no root bindings, and no paper
  prelude. The corners `.a`–`.d` are *not* visible: after earlier folds
  their referents are state-dependent, so a body that needs them must take
  them as parameters. This is what makes a def genuinely
  context-independent.
- Because a body only sees *earlier* defs, recursion is structurally
  impossible.
- Body statements: bindings, fold/construction actions, `flip`, `apply`,
  `export`. Not allowed inside a body: `def`, `step` panel markers.

## 5. `apply` and instances

```beloch
$p1 = apply petal(.k1 .k2 --(.k1 .k3))   ; folds now; instance retained
apply petal(.k2 .k4 --(.k2 .k1))          ; folds now; namespace discarded
```

- Arguments are ordinary operands (named or inline forms), matched to
  parameters by position; sigils must agree.
- `apply` executes the body against the current folded state. Every
  non-temp binding the body creates becomes a member of the resulting
  instance.
- `$inst = apply …` is the only RHS form for `$` bindings — instances
  cannot be aliased or constructed any other way.

## 6. Qualified access

Instance members are read with the bracket forms, parallel to the inline
construction forms but visibly distinct (round = construct, square = look
up):

```beloch
@map .[$p1 tip] onto .[$p2 tip]
--d = through .[$p1 tip] .[$p2 tip]
.x  = cross --[$p1 pq] --[$p2 pq]
```

- `.[$inst member]` is a point operand; `--[$inst member]` is a line
  operand. The outer sigil declares the kind; the member name is bare.
- Valid anywhere an operand of that kind is valid.
- Unknown member, kind mismatch, or temp member → error.

## 7. `export`

`export` copies members of an instance into the current scope. It reads;
it never executes.

```beloch
export { .tip --pq } $t              ; selective
export { .tip as .left_tip } $t      ; rename on landing
export { .s! } $t                    ; intentional shadow (see §9)
export $t                            ; all non-temp members
```

- Names in the export list carry their sigils (they name kinds of things
  to pull; `as` needs a sigiled landing name).
- `export $t` (export-all) lands every non-temp member and validates
  **each landed name individually** — exactly like selective export. Two
  export-alls from two applies of the same def collide on every name;
  the fix is selective export with `as`, or qualified access.
- `!` shadowing is validated both ways:

| Name exists in current scope | `!` | Result |
|---|---|---|
| no | no | OK — new binding |
| yes | yes | OK — intentional shadow |
| yes | no | Error — "name exists, use `!` to shadow" |
| no | yes | Error — "nothing to shadow, remove `!`" |

There is no `inline`: it differed from export-all only in *display*, and
display is now the `step` axis.

## 8. `step` — diagram panels

```beloch
step thirds
._mb = .(--vm --(.a .b))
--pq = through ._pq1 ._pq2

step beloch_fold
@map .c onto --(.a .b) and .s onto --pq
```

- `step ident` is a heading: it opens a panel that runs until the next
  `step` or end of file. Actions before the first `step` are flat
  (ungrouped), as today.
- The identifier **binds nothing** — zero namespace footprint. It is a
  stable anchor for the instruction JSON, FOLD metadata, and external
  i18n label files; source never carries display strings.
- Duplicate panel identifiers are an error (anchors must be stable).
- Top level only. Folds produced by an `apply` land in the panel that is
  open at the apply site.

## 9. Rebinding rules (uniform, per #24)

One invariant, no narrow paths: **a name without `_` is bound at most once
per scope.**

| Situation | Result |
|---|---|
| `--x = …` twice in same scope (root or body) | error |
| rebinding a corner `.a`–`.d` at root | error |
| `def x` twice | error |
| `step x` panel id twice | error |
| export lands existing name without `!` | error |
| export lands with `!` onto nothing | error |
| `._x = …` twice (temp) | OK — marked mutable |

Corners `.a`–`.d` are ordinary root-scope bindings created by
`paper square`; they follow the same rule.

## 10. Instruction-JSON / FOLD mapping

| Source construct | Instruction output |
|---|---|
| naked action before first `step` | flat entry |
| `step id` | panel boundary; panel carries `id` |
| action inside a panel | entry in that panel |
| `def` | nothing (never runs) |
| `apply` (bound or naked) | its folds, in the panel open at the apply site |
| `export` | nothing (metadata only) |

FOLD naming: a crease bound `--pq` inside `$p1 = apply …` is named
`p1.pq` — collision-free across repeated applies. Creases from a naked
`apply`, and creases bound to temps, are unnamed in FOLD.

## 11. Grammar sketch (planned productions)

New tokens: `EQ` (`=`, replaces `COLON`), `DEF`, `APPLY`, `EXPORT`, `STEP`,
`AS`, `BANG`, `LBRACE`, `RBRACE`, `LPAREN`, `POINT_MEMBER_OPEN` (`.[`),
`LINE_MEMBER_OPEN` (`--[`), `RBRACKET`, `INSTANCE` (`$id`), `IDENT` (bare id).

```
stmt          ::= CREASE EQ crease_rhs
                | axiom_stmt
                | POINT EQ point_rhs
                | FLIP
                | DEF IDENT LPAREN param* RPAREN LBRACE body_stmt* RBRACE
                | INSTANCE EQ APPLY IDENT LPAREN operand* RPAREN
                | APPLY IDENT LPAREN operand* RPAREN
                | EXPORT (LBRACE export_entry+ RBRACE)? INSTANCE
                | STEP IDENT

body_stmt     ::= stmt minus (DEF …, STEP IDENT)
point_rhs     ::= point_expr | point_operand      ; §3.2 shorthand
crease_rhs    ::= axiom_stmt | line_operand       ; §3.2 shorthand
param         ::= POINT | CREASE
export_entry  ::= (POINT | CREASE) BANG? (AS (POINT | CREASE))?
point_operand ::= … | POINT_MEMBER_OPEN INSTANCE IDENT RBRACKET
line_operand  ::= … | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET
```

## 12. Worked example — cube root, restructured

```beloch
paper square

step vertical_middle
--vm = map .a onto .b

step thirds
._mb  = .(--vm --(.a .b))
._mt  = .(--vm --(.d .c))
._pq1 = cross --(.d ._mb) --(.a .c)
._pq2 = cross --(.a ._mt) --(.d .b)
--pq  = through ._pq1 ._pq2
._rs1 = cross --(.c ._mb) --(.d .b)
._rs2 = cross --(.b ._mt) --(.a .c)
--rs  = through ._rs1 ._rs2
.s    = .(--rs --(.d .c))

step beloch_fold
@map .c onto --(.a .b) and .s onto --pq
```

Only `--pq`, `--rs`, `--vm` and `.s` land in root scope; all scaffolding is
temp. No def needed — nothing repeats. Where repetition exists, defs carry
their inputs explicitly:

```beloch
paper square

def petal(.p .q --base) {
  @map .p onto .q moving .p
  .tip = cross --(.p .q) --base
}

step petal_folds
$left  = apply petal(.a .c --(.b .d))
$right = apply petal(.b .d --(.a .c))

step join
@map .[$left tip] onto .[$right tip]
```

## 13. Out of scope / deferred (→ `ideas.md`)

- Nested `def`s and namespace chaining (`.[$b1 $d tip]`).
- Re-export cascades (meaningless without nested scopes).
- String labels anywhere in source (i18n lives outside).
- `pub`/`priv` author-side interfaces; looping primitives (already parked).
- Module/file-level namespacing.

## 14. Verification

Per #29: every example in this spec must be run through the parser before
approval. Status: **done** — parse-only prototype in `scratch/specparse/`
(lexer + Menhir grammar per §11, builds without conflicts); all 10 example
programs (`scratch/specparse/examples/*.bel`, covering every code block in
this spec) parse.
