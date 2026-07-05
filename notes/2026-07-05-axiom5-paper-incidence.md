# 2026-07-05 — axiom 5: filter bisectors by paper incidence before erroring

`map --l1 onto --l2` on intersecting lines always raises
"bisector is ambiguous; add `toward .p`" (`eval.ml:304`). The kite base shows
that this is too eager — often only **one** of the two bisectors is a fold you
can physically make.

## Motivating example

```
paper square

--diag = map .b onto .d
@map --(.d .a) onto --diag        ; error: bisector is ambiguous; add `toward .p`
```

Corners: `a=(0,0)`, `b=(1,0)`, `c=(1,1)`, `d=(0,1)`. `--diag` is the
perpendicular bisector of `b–d`, i.e. the line `y=x` through `a` and `c`. The
left edge `--(.d .a)` is `x=0`. The two lines meet at the **corner `a`**, and
the two bisectors through it are:

- the **67.5° line** — the kite crease; crosses the paper interior;
- the **−22.5° line** (perpendicular to it) — touches the paper only at the
  corner point `a`. Its crease segment has zero length; folding along it moves
  nothing. It is not a performable fold.

Exactly one candidate lands on the paper. Requiring `toward` here makes the
user disambiguate between a fold and a non-fold.

## Proposed rule

When axiom 5 yields two bisectors and `toward` is omitted:

1. Clip each candidate line against the region the statement operates on
   (the clipping machinery exists: `Geom.clip_convex_halfplane`, used
   throughout `fold_state.ml`).
2. Discard candidates whose intersection is **not a segment of positive
   length** (empty, or a single point — corner/edge touch).
3. Then:
   - **1 candidate left** → take it, no `toward` needed;
   - **2 left** → the existing ambiguity error (genuinely ambiguous — e.g.
     diagonal onto diagonal: both midlines cross the paper);
   - **0 left** → new error, "no fold lands on the paper".

`toward` keeps its current meaning; the filter only runs when it is omitted.

## Why this fits the existing doctrine

- **ADR 0016** — "metric (`toward .x`) only where incidence cannot
  discriminate". Paper incidence *does* discriminate here; demanding `toward`
  anyway contradicts the ADR's own selection ladder.
- **ADR 0014** — a crease is a bundle of segments. A line with no
  positive-length segment on the paper is an empty bundle — not a crease at
  all. The filter is the same test applied one step earlier, and it is
  consistent for both binds (`--x = map …`) and folds (`@map …`).
- **Justin's operation table** counts ⑤ `(D → D')` as "1, 2" solutions on the
  **abstract plane** — no paper boundary in sight [justin1986, §8.1]. The
  table doesn't contradict paper-validity filtering; Beloch folds a real
  sheet, and §8.1 explicitly frames the elementary operations as "faire un
  pli puis déplier" — a pli that creases nothing isn't one.
- Lang's ReferenceFinder reportedly filters axiom solutions by validity on
  the unit square — **source not in `refs/`**; drop in a citekey before
  leaning on this claim.

## Open questions

- **Which region to clip against after folds?** The flat sheet is the easy
  case. On a folded state, the candidate should presumably be clipped against
  the same region the statement operates on — which ties into the fold-scope
  design (`2026-07-05-fold-scope.md`, ADR 0016). The rule should be phrased
  once, against that region, not ad hoc per axiom.
- **Generalise to axioms 6/7.** `MapThrough` / `beloch_creases` have the same
  shape (finite candidate set, `toward` selector). The same incidence filter
  applies verbatim and would remove `toward` from more programs. Separate
  slice.
- **`toward` selecting an off-paper candidate** — keep permitting it, or
  error? Leaning error (it names a non-fold), but undecided.

## Spec impact

`spec/SPECIFICATION.md` §5 (axiom 5 solutions/`toward`, ~lines 186–192) and
the error catalogue (~line 686) need the filter step and the new zero-candidate
error.
