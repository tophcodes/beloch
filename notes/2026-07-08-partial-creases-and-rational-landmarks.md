# 2026-07-08 — two deferred primitives: partial creases & rational landmarks

Captured out of the notation-by-state-change brainstorm
(`docs/superpowers/specs/2026-07-08-notation-by-state-change-design.md`). Neither
is in that slice; both want their own design. Noting here before they evaporate,
because each one validates the state-change law by landing cleanly on one side of
it.

## 1. Partial creases — a *write*, and it fights an invariant

**Want:** describe a full line, but crease only *part* of its extent — a crease
that starts and stops without spanning a whole face.

**Under the law:** it scores paper → keyword verb. No notation question.

**The catch:** this is exactly the "non-splitting reference edge" that the `pinch`
design *rejected* (`notes/2026-07-03-crease-layer-selection.md`, *Resolved* §3): an
edge that is not a face boundary breaks the every-edge-is-a-face-boundary
invariant (#26), and `pinch` chose full-chord subdivision precisely to keep that
invariant intact. So partial creases **reopen** that rejected option and must pay
its cost: a crease segment whose endpoints are interior to a face is a new
topological kind — a dangling edge — and the whole mesh/emit path has to tolerate
it.

**Placement in the crease-granularity spectrum** (all in the #8 crease-segment
family):

- bare bind (`through`) → **whole bundle**, every face the axis crosses.
- `pinch` → **one full-chord segment** of one face.
- *partial crease* → **less than a chord**: a dangling sub-segment. ← this note.

Open, when it gets designed: how a dangling edge is represented (does it split the
face at all? probably not — it's a score line the face-graph ignores), how it
interacts with folding through it, and whether M/V and layer order even apply to a
crease that doesn't reach a boundary. Likely a decision to relax #26 deliberately,
scoped to non-folding score marks.

## 2. Rational landmarks — a *read*, exact but underived

**Want:** `map .p onto .[3/4 along --l]` — a point at a rational parameter along a
line, written as a literal instead of derived by an explicit fold sequence.

**Under the law:** it locates a point, scores nothing → read → operator/notation.
Sits with `*`, `&`, `\` on the read side.

**Not a precision compromise.** 3/4 is constructible, so the real-algebraic kernel
(ADR 0008 / 0012) yields the *exact* point. What you skip is *spelling out* the
construction (halve, halve, mark) — not the exactness. "Artistic / doesn't need to
be exact" means *the designer didn't care to derive it*, and the result is exact
anyway. This keeps it honest with the exact core: no floats sneak in; a rational
literal is just a constructible number named directly.

Design surface, when it gets its slice:

- **Rational literals** in the grammar (`3/4`) — new token class, constrained to
  rationals (all constructible; irrational literals would not be, so exclude them).
- **A parametric read** — `<rational> along <line>`. "Along" needs a finite extent
  (the crease's chord in the paper, presumably), since a line is infinite.
- **Point notation** — the example uses `.[…]`. The bundle-algebra doc forbade
  `.[…]` as "points are never a set", but this is a *single* parametric point, not
  a set — so `.[…]` for "the point this expression determines" may be fine, or it
  may want its own spelling. Resolve when designed.
- Possible generalisation: absolute rational coordinates (`.[3/4, 1/2]`) as well as
  parametric-along. Start with `along`; only add coordinates if a use appears.

## Why both are worth the law

The law predicted their shape before we designed them: the crease is a write
(keyword, and it collides with a topology invariant precisely because writes
mutate shared state), the landmark is a read (operator, order-free, exactness
inherited from the kernel). Two unrelated feature requests, each pre-sorted by the
same question — *does it mutate paper state?* That is some evidence the law is
carving at a real joint, not just tidying selectors.
