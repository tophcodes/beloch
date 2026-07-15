# `flatten` — generalizes `collapse` with an emergent-crease solver (design)

## Status

Proposed (2026-07-15). Supersedes the surface syntax of
`2026-07-07-flatten-primitive-design.md` (which predates the `@`-retirement,
the `&` incidence filter, and the shipping of `collapse` as a keyword). That
document's *contract* — derive the crease forced by flat-foldability — stands;
this document restates it in the current notation and against the shipped
`collapse` kernel, and fixes the scope for v1.

## Context — why this change

`collapse` shipped (v0.20/0.21-dev, `spec/SPECIFICATION.md` §4.9,
`lib/collapse.ml`) as a **validator**: you name all `2n` material crease rays
sharing one interior vertex, and it checks the flat end state exists (Kawasaki +
Maekawa), assigns per-sector isometries, and enumerates valid layer orders. It
cannot *derive* a missing crease.

But some flat folds require a crease **no Huzita axiom constructs** from the
sheet's named points. The canonical case is the **swivel rabbit ear**: two
hinges are placed freely (not at bisector angles), the reflex flap tucks flat to
one side, and the crease that makes it flat is *forced by flat-foldability* — a
non-bisector line that can only be **solved for**. The standard rabbit ear
(`examples/bases/rabbit-ear.bel`) escapes this only because its creases sit at
the incenter's angle bisectors, all constructible; the moment the hinges move,
`collapse` can no longer express the maneuver.

`flatten` closes this gap and, in doing so, **subsumes `collapse`**: collapse is
exactly `flatten` with every ray already given and nothing to derive. One
write-verb replaces two primitives.

## Decision

Rename `collapse` → **`flatten`** (one keyword) and give it two operating modes,
distinguished by the operand set, not by a mode keyword:

1. **Validate mode** — all `2n` rays given (today's `collapse`, verbatim
   semantics and grammar). Flat-foldability is *checked*.
2. **Derive mode** — the two hinge **rays** are named (via the shipped `&`/`\`
   selector algebra on their crease lines), and a mandatory `toward <point>`
   names the landing side. `flatten` **solves for the minimal emergent
   crease(s)** that fold the moving flap flat to that side, then folds.

Two things must be disambiguated, and they factor cleanly:

- *Topological* — which sector is the identity anchor (hence which flap moves).
  Fixed by the **ray selection**: the two named rays bound a convex (<180°)
  sector, which by rule is the anchor; its reflex complement folds. (A
  point-into-the-anchor `stays` sugar is possible but generative — deferred to
  the solution-space `#{…}` pass; see *Constructed space vs solution space*.)
- *Metric* — among the moving flap's flat landings (swivel-left / symmetric /
  swivel-right), which side. Fixed by **`toward <point>`**.

Naming the rays (not overloading `toward`) is what keeps these separable and
removes any ray-counting heuristic — the solver derives whatever minimal crease
set closes the moving side.

`flatten` becomes **bindable** so the emergent crease — which has no other
construction — can be named.

## The derive math (grounded)

**Kawasaki's Theorem** [hull2020, §5.3, Thm 5.17]: a single interior vertex with
consecutive sector angles `α₀ … α₂ₙ₋₁` (cone angle 2π) is flat-foldable **iff**
`α₀ − α₁ + α₂ − … − α₂ₙ₋₁ = 0`.

The shipped kernel already encodes this **exactly, without an angle type**:
`Collapse.closure_ok` (`lib/collapse.ml:106-114`) folds the reflection product
across all rays and checks it equals the identity. A product of an even number
of reflections is a rotation; it is the identity **iff** the alternating angle
sum ≡ 0 (mod 2π) — i.e. `closure_ok` *is* Kawasaki at O (as the code comment
already states). This is the lever for the derive.

**The solver.** Model the unknown emergent ray as a reflection across a line
through `O` with unknown direction `(a, b)`. Form the closure product with that
symbolic reflection inserted in ray order and require it to equal the identity.
This yields a polynomial constraint in `(a, b)` (with `a² + b² = 1`); its real
roots are the candidate emergent directions:

- Reuse **`Num.real_roots`** (`lib/num.ml:299`) and the whole
  `Poly`/`Qqbar`/`Mpoly` real-algebraic kernel (ADR 0012/0013).
- This is **exactly the axiom-7 pattern** (`lib/geom.ml:96-140`): build a
  polynomial-in-a-parameter constraint → solve real roots exactly → map each
  root to a crease line. Axiom 7 already ships this shape.
- Disambiguate the surviving candidates by **side**: keep the root whose crease
  swings the folding flap toward the `toward` point, via `Geom.side_of_line`
  (`lib/geom.ml:261`) on the swing axis (the `toward` metric primitive axioms
  5–7 use; the `ax5_pending`/`viable` code is a *pattern to imitate*, not a
  drop-in — the emergent-ray case has no bisector candidate pair).

Once the ray set is complete, the **existing collapse kernel runs unchanged** —
`sector_isometries`, `effective_valley`, `linear_extensions`, layer-order
enumeration, M/V assignment (`lib/collapse.ml:73-425`).

**v1 scope: the single-emergent-ray configurations.** Two hinges + one derived
ray is one Kawasaki equation in one unknown → generically finitely many roots,
the ray selection fixes the moving side, `toward` picks the swivel. Whether a
given hinge geometry forces **one** emergent crease (the clean swivel) or
**two** (the closure solve is then underdetermined and the *minimal-crease* rule
must pin the extra one) depends on the hinges; the ray-selection + `toward`
control surface is the same either way. v1 ships the one-crease case; the two-crease minimal-selection
case and the `onto`/petal landing are **deferred** (Scope, below). The math
spike (below) determines which case the shipped rabbit example falls in.

**Spike first.** Before the kernel and surface are fixed, a **math spike**
verifies the single-ray closure solve numerically on a concrete swivel rabbit
(free hinges): symbolic closure product → real roots → toward pick → the
resulting vertex passes `closure_ok`. This isolates the only real risk in the
change; everything else is mechanical.

## Surface syntax

All spellings are the *current* settled notation (`&` incidence, `#[…]` flap,
`toward <point>`, no `@`; see `2026-07-08-notation-by-state-change-design.md`).

**Rename + list notation.** `collapse` → `flatten` everywhere. The item list
also drops `and` for **parenthesised juxtaposition**: each item that carries an
infix operator or a modifier (`&`, `\`, `over`, `mountain`) is wrapped in
parens; bare single operands may stay unparenthesised; whitespace separates
items; `toward` remains a trailing operand. (`and` survives elsewhere only as
axiom-6's fixed binary `map … and … onto …` joiner — a small, accepted
asymmetry.)

```
flatten (--ac & .a) (--ac & .c) (--bd & .b) (--bd & .d)
  (--h & --bc)
  (--h & --da mountain)
  (--v & --cd mountain)
  (--v & --ab mountain)              ; waterbomb, n=8, validate mode
```

**Derive mode — name the hinge rays (primitive, no new grammar).** Give the two
hinge **rays** (not the whole lines) plus a mandatory `toward <point>`. Each ray
is selected from its crease line with the shipped bundle algebra: `--ba & .a`
keeps the segment through `.a`; **`--ba \ .a` drops it**, keeping the opposite
ray through O. The two named rays bound a **convex** sector (<180°); by rule
that convex sector is the **identity anchor**, and its reflex complement is the
moving flap. `toward` picks the swivel side. No new keyword — this is the shipped
`&`/`\` selector algebra:

```
--ear = flatten (--ba \ .a) (--bb \ .b) toward .c
```

Here `--ba \ .a` / `--bb \ .b` are the two rays *away* from `.a` / `.b` — they
bound the upper (apex-side) sector, so that sector stays and the base flap
swivels toward `.c`. The rays reference only **prior geometry** (`.a`, `.b`,
`--ba`, `--bb` all exist), so this is pure constructed-space selection — no
forward reference, `#[…]` semantics untouched. Mode trigger: `toward` present.
Without `toward`, two rays is just `n < 4` → validate error.

**Anchor rule.** The stayer is always the convex (<180°) sector the two named
rays bound; the reflex (>180°) side folds (07-07 forbids a reflex stayer). So
naming the rays fixes the anchor unambiguously — no separate clause needed.

### Constructed space vs solution space

`#[.m]` means **the flap of the current constructed state that contains `.m`** —
a read; it errors if no such flap exists. It must **not** be overloaded to mean
"the flap `flatten` will create around `.m`": before the solve, that flap does
not exist, and `flatten` can produce several partitions (which sector stays ×
which swivel → up to four candidate flaps). Selecting among *those* is a
**solution-space** query, categorically different from reading constructed
geometry, and reusing `#[…]` for it would break the selector's meaning.

- **`#[…]` — constructed space** (read; must exist). What the ray-naming
  primitive above uses, indirectly, via prior points.
- **`#{…}` — solution space** (generative; constrains the operation to the
  completion in which `.m` is a valid anchor flap). Reserved sigil; curly = the
  set of possibilities.

This is not special to `flatten`: `toward` / `onto` already select *metrically*
among an axiom's solution set. `#{…}` (and, by extension, `.{…}`, `--{…}`) would
be the explicit selector form of the same idea — a language-wide addition that
**deserves its own design pass**, not v1.

**`stays <flap>` — deferred with the solution-space feature.** A `stays .m`
clause is inherently generative ("pick the completion where `.m` anchors"), so
it belongs to `#{…}`, not `#[…]`, and lands with that pass — desugaring to
`#{.m}`. **v1 ships only the ray-naming primitive**: constructed-space,
`#[…]`-consistent, and needs no new keyword.

**Direction.** `toward <point>` reuses the shipped operand
(`lib/parser.mly:151`, `point_operand`); the point need only indicate the
**side**, not the exact landing. `onto <line>` (petal, exact landing) stays
reserved.

## Binding & return value

`flatten` **creates** creases, so — like `fold`, `mark`, and the axiom folds —
it is **bindable**. This matters most in derive mode: the emergent crease has no
construction, so binding is its only name.

```
--ear = flatten (--ba \ .a) (--bb \ .b) toward .c
.tip  = .[--ear, --base]     ; the derived tip on the base, now selectable
```

New machinery:

- **AST name slot.** `Ast.Collapse` carries no `string option` name (unlike
  `Fold`/`Mark`); the renamed `Ast.Flatten` node gains one, plus the `toward`
  operand.
- **Return value.** The kernel returns the **bundle of emergent creases** it
  derived (often one; in configurations where the derived centre lands on an
  already-named line, that segment is simply re-selected) and exposes the
  emergent **tip point** so downstream statements have something to select
  against. Validate mode may also bind (returns the given rays as a bundle) but
  the binding is only load-bearing in derive mode.

## Errors

Validate-mode errors are inherited verbatim from `collapse` (`lib/collapse.ml`
error strings; spec §4.9 table). Derive mode adds:

| condition | outcome |
|---|---|
| `toward` present but ray set already flat-foldable | `nothing to derive (vertex already flat-foldable)` |
| named rays bound no convex sector (collinear/opposite) | `hinge rays do not bound a stayer sector` |
| the moving flap needs >1 emergent crease (v1) | `flatten derives one crease here; this vertex needs N (deferred)` |
| no real root closes flat-foldability toward the side | `vertex not flat-foldable toward <point>` |
| derived assignment self-intersects | reuse `assignment forces self-intersection` |
| hinges share no single interior vertex | reuse `no common interior vertex` |

## Migration

`collapse` is removed as a keyword; the two shipped examples and the spec move
to `flatten`:

- Keyword: `lib/lexer.ml` (`COLLAPSE`→`FLATTEN`), `lib/parser.mly`
  (`COLLAPSE`/`collapse_*` rules), `lib/ast.ml` (`Collapse`→`Flatten`, + name
  slot + `toward`), `lib/eval.ml` (handler ~1722).
- Kernel file `lib/collapse.ml` stays named `Collapse` internally or is renamed
  `Flatten` (implementation detail; the *language* keyword is what changes).
- Spec: §4.9, §4.10 read/write law, §1311/§1348 grammar, Appendix pointers.
- Examples: `examples/bases/rabbit-ear.bel`, `examples/bases/waterbomb.bel`
  (validate mode, keyword swap). A **new derive-mode example** — a swivel rabbit
  with free hinges binding `--ear` — is added once the kernel lands.
- Tests: `tests/test_collapse.ml` (keyword + a derive-mode case).

## Scope / deferred

- **v1 ships:** rename/unify, validate mode (= old collapse), **single emergent
  ray** derive triggered by named hinge rays (`&`/`\`) + `toward`, bindable +
  tip return. No new keyword (ray-naming reuses shipped `&`/`\`).
- **Deferred:** the solution-space selector `#{…}` (+ `.{…}`/`--{…}`) and the
  `stays` sugar that desugars to it — its own language-wide design pass
  (**issue #46**);
  multi-emergent-ray derive + the minimal-crease selection rule; `onto`/petal
  exact landing; `standing` (3D unflattened flap, ADR 0015); no maneuver
  keywords (`rabbit`/`petal`/`squash` are optional stdlib `def`s over `flatten`,
  never grammar).

## Slicing

1. **Math spike** — single-ray closure solver on a concrete swivel rabbit;
   verify numerically (`closure_ok` passes on the solved vertex). Gate.
2. **Kernel** — `Flatten.derive`: symbolic closure product → `real_roots` →
   `toward` pick → hand the completed ray set to the existing collapse kernel.
   TDD against the spike's numbers.
3. **Surface + rename** — `collapse`→`flatten` keyword, `and`→parenthesised
   juxtaposition, AST name slot + `toward` operand; derive triggered by named
   hinge rays (`&`/`\`, shipped selectors) + `toward`; parser/eval wiring.
4. **Binding + return** — emergent-bundle + tip; make `--r = flatten …` resolve.
5. **Migrate** — examples, spec, tests; add the derive-mode example.

## References

- [hull2020, §5.3] — Kawasaki's Theorem (alternating angle sum), Maekawa; the
  flat-foldability condition the closure product encodes. Thm 5.17, Cor 5.19.
- [hull2020, Thm 8.5] — the rabbit-ear base (standard, bisector case).
- ADR 0011 (action model), 0012/0013 (real-algebraic kernel — exact emergent
  creases), 0014 (crease = bundle of segments — the emergent bundle), 0015
  (flat-folded states only — why `standing`/3D waits), 0016 (typed operands),
  0017 (flap granularity for `#[…]`).
- `spec/SPECIFICATION.md` §4.9 (`collapse`, being renamed), §4.10 (read/write
  law), §4.5 (`toward`).
- `lib/collapse.ml` (the shipped validator + reusable post-crease-set kernel),
  `lib/geom.ml:96-140` (axiom-7 solve pattern), `lib/num.ml:299`
  (`real_roots`).
- `docs/superpowers/specs/2026-07-07-flatten-primitive-design.md` (superseded
  spelling; contract retained).
