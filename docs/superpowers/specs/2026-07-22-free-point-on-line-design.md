# Free point on a line — design

**Status:** approved design, pre-implementation
**Date:** 2026-07-22
**Scope:** language feature (spec + grammar + evaluator + FOLD emission). No renderer work.

## Problem

Today a point can only come from three sources (§3, §4.3, grammar `point_operand`):
the four corners, the meet of two lines (`*` / `.[…]`), and axiom results. Every
rational position along a line *is* origami-constructible, but only via an explicit
construction — there is no way to say "put a reference point roughly here on this
line, the exact spot doesn't matter."

Real folding has this move: pin a point you can put your finger on. We want it as a
first-class construction, and we want the position to be recoverable later as an
*adjustable parameter* (so tooling can eventually expose it), without weakening the
exact kernel.

## Non-goals

- **Live sliders / degrees-of-freedom visualisation.** Filed separately as a GitHub
  issue. This spec only lays the metadata hook.
- **Symbolic free variable (`t` as a true kernel unknown).** The dream version where
  geometry stays exact-in-`t` and incidence tests go parametric. Large number-kernel
  change; explicitly deferred. The surface syntax here is forward-compatible with it.
- **Region (2-DOF) free points** ("anywhere in the sheet"). Out of scope; this feature
  is 1-DOF, constrained to a line.

## Core stance: `free` is provenance, not a kernel relaxation

A free point is a **concrete exact rational point** that the number kernel treats like
any other. `free` records *how* it was placed and *that its position is not load-bearing*
— it does **not** make the geometry approximate. Incidence tests, meets, and axioms see
an ordinary point. This is what lets the feature ship on today's exact kernel with §6
("all geometry is exact") untouched.

The symbolic-in-`t` future extension would reinterpret the same syntax by promoting `t`
to a kernel unknown. That is out of scope here; the point is that nothing in the surface
syntax forecloses it.

## Semantics

### Domain

The point lies on **exactly one contiguous bundle of `--l`'s material chords** within
the current paper.

- A line may cross the paper's material in several disjoint runs (faces, gaps at
  creases). The relevant domain is *one* contiguous bundle: the in-between chord gaps
  along a single run are inferred/bridged, and the bundle's **two furthest-out points**
  become the parameter endpoints `P0`, `P1`.
- `P0` and `P1` are exact (line ∩ material boundary).
- The parameter `t ∈ [0, 1]` runs from `P0` (`t=0`) to `P1` (`t=1`). The seed point is
  `P0 + t·(P1 − P0)`, exact for rational `t`.

### Orientation and bundle selection

An **anchor endpoint** does both jobs with one mechanism:

```
.p = free on --l from .x
```

- `.x` selects the contiguous bundle whose `.x`-side furthest-out point is the anchor,
  and fixes that end as `t = 0`; the opposite furthest-out point is `t = 1`.
- Selection is by exact incidence (no metric "nearest").
- `.x` is typically a salient, already-named point (a corner or a meet). If it isn't
  named yet, the user constructs and names it — consistent with Beloch's "every point is
  a named construction" ethos.

*(Considered alternative: `toward .y`, orienting `t` by the sign of the projection onto
the line direction. Rejected for v1 in favour of the single `from` anchor — simpler, and
it selects the bundle at the same time. `toward` remains available as a future addition
if disjoint-bundle cases need orientation without a named endpoint.)*

### Seed value

```
.p = free on --l from .x            ; t defaults to 1/2 (midpoint of the bundle)
.p = free on --l from .x at 2/5     ; explicit rational t
```

`at` takes a rational literal (grammar already has `number := /[0-9]+(\/[0-9]+)?/`).

### Usage

A free point is a first-class point value. It is usable anywhere a point operand is
accepted — `through .p`, `map .p onto …`, `map … onto … at .p`, `mark … at .p`,
perpendicular/projection axioms, etc. The kernel handles it as an ordinary exact point.

### Errors

- **Line misses material** — `--l` has no material chord in the current paper: error
  (no domain).
- **Anchor does not resolve one bundle** — `.x` is not a furthest-out endpoint of a
  contiguous material bundle of `--l` (not on the line's material, or ambiguous): error.
- **`t` out of range** — `t ∉ [0, 1]`: error (outside the bundle).

## Syntax / grammar

Extend point construction (grammar `point_operand` / `point_stmt`):

```
point_operand := … | free_point
free_point    := "free" "on" line_operand "from" point_operand ("at" number)?
```

- `line_operand` — an existing line value (`--name` or inline axiom, per current rules).
- `from point_operand` — the anchor endpoint (required; pins orientation + bundle).
- `at number` — optional rational `t`, default `1/2`.

## FOLD metadata emission

Emit a `beloch:free` custom property describing the point's parameterisation, alongside
the existing `beloch:*` custom fields (`beloch:marks`, `beloch:edges`,
`beloch:source_line`, axiom provenance on edges). This is the forward-compatibility hook
for tooling — **no renderer consumes it in this feature.**

Shape (per free point):

```json
"beloch:free": {
  "line": <crease_id or line coefficients>,
  "t": "2/5",
  "endpoints": [[x0, y0], [x1, y1]],   // P0 (t=0), P1 (t=1), exact paper coords
  "anchor": <point ref / source>,
  "source_line": <1-based source line>
}
```

A future renderer MAY read this to build a `t`-slider over `[P0, P1]`. Emission is the
only obligation of this spec.

## Testing

Inline-assertion `.bel` cases in `tests/cases/` (per the repo's assertion-test
convention), covering:

1. **Placement** — `free on --l from .x at t` lands the expected exact point (assert
   coordinates / incidence with `--l`).
2. **Default `t`** — omitted `at` seeds the bundle midpoint.
3. **Consumption** — a free point feeds an axiom (e.g. `through .p`) and produces the
   expected crease.
4. **Bundle selection** — a line crossing material in two disjoint runs; the anchor
   picks the correct bundle; the furthest-out points are the endpoints.
5. **Orientation** — swapping the anchor to the other end flips `t=0`/`t=1`
   (assert the `t`→coordinate mapping reverses).
6. **Errors** — line-misses-material, bad anchor, `t` out of `[0,1]` each raise the
   specified error.
7. **Emission** — the FOLD output carries a well-formed `beloch:free` for the point.

## Spec-document changes

- **§3 Values** — note that a point may also be a *free point on a line* (1-DOF,
  provenance-tagged, still exact).
- **New subsection under §4** — `free on … from … at …` construction: domain (contiguous
  material bundle, furthest-out endpoints), orientation, seed, errors. Cross-reference §6
  (still exact) and §7 (`beloch:free` emission).
- **§7 output** — document the `beloch:free` custom property.
- Version bump note (next `-dev`).

## Out to issues

- **Slider / DOF visualisation** (renderer reads `beloch:free`, exposes an interactive
  `t`): GitHub issue, filed with this spec.
- **Symbolic-in-`t` kernel**: future extension, noted here, not yet ticketed.
