# Flatten parities depend on the `sort_ccw` angle origin: finding and fix plan

**Context:** Two-ear fish base (`tests/cases/collapse/flatten-two-ears-sequential.bel`,
both ears `{toward .d}` or `.d`/`.b` respectively). After the flat-hinge taco check
(`ab8aa12`), the second ear has **no** valid realization any more. The state
emitted before that was a ghost (paper passing through the closed ear hinge,
spotted by Toph on the render: wing below the stationary strip, ear above it).

## Causal chain (empirical, BELOCH_COLLAPSE_DEBUG/BELOCH_TT_DEBUG instrumentation)

1. Sector parities come from `sector_isometries`: `det(T_k) = (−1)^k` with
   k = CCW index counted from `sort_ccw`'s **absolute angle origin**. The
   proper/improper assignment is therefore arbitrary and has no geometric basis.
2. Three consumers of this parity:
   - **Anchor eligibility** (`anchor_realization`, det>0 sectors only):
     fixed in `1a4f6d9` (improper fallback + reversed rank).
   - **Validity filter** (`valid_srank`): turns out to be uncritical.
     All `make` checks read rank only through *betweenness*, which is
     reversal-invariant (the variant experiment was a no-op for that reason).
   - **`effective_valley`** → hinge **constraints** → `linear_extensions`:
     HERE is where the damage sits. For the c-vertex of the second ear,
     the origin parity produces the constraint directions of the mirrored
     world: across ALL Maekawa patterns, only 16 of the 24
     sector chains are enumerated; the physically true chain `[2,3,0,1]`
     (stationary at the bottom, wing blocks cleanly above it, ear on top) and its 7
     relatives are missing. The missing set is closed under reversal,
     so mirror seating cannot reach it either.
3. Consequence: every enumerated chain violates a taco check (rightly so!):
   64/64 KILL at nf=12. Before `ab8aa12`, only the 4 ghosts survived.

## Fix direction (next slice)

Compute parity consistently per anchor class instead of globally from the origin:
`collapse_pipeline ~mirror:bool`. With `mirror`, `effective_valley` flips
(and with it the constraints + `ray_assign`), as does `intra`, and anchoring happens on the
det<0 sectors. `collapse_all` = pipeline(false) ∪ pipeline(true) with
signature dedup; `over` reads inverted in the mirror case. This replaces the
reversed-rank fallback from `1a4f6d9` with a consistent model (the
fallback remains contained in it as a special case).

Expectation afterwards: `flatten-two-ears-sequential.bel` green (the true chain is
enumerated, ghosts stay dead), `test_flatten` derive-13 green, no
change to single-flatten cases (there the false pipeline seats as it does today).

## Side findings

- `e_midpaper`/"crease ends inside the sheet" fired for 8 patterns of the
  second ear, presumably the OppositeRay candidate O2→center; reassess after the
  parity fix (interaction with tier question #51).
- Debug hygiene: BELOCH_FLATTEN_DEBUG (`eval`), BELOCH_COLLAPSE_DEBUG
  (`valid_srank`), BELOCH_TT_DEBUG (taco raise) were useful as temporary
  instrumentation; removed before commits. Reintroduce as permanent
  env-gated traces if needed.

## Resolved (2026-07-18, staying slice)

Language-level solution instead of the ~mirror union: `(staying <flap>)` + leading-pair convention
anchor the parity class semantically (#52). In the process, a
third representative arbitrariness was found and fixed: `sector_iso` took the
first face in the sector as the orientation representative. In the mixed
stayer sector of the second ear (base strip det>0 + ear-1 stack det<0),
`effective_valley` therefore read the mirror world (diagnosis confirmed: one
inverted hinge constraint). Fix: per ray, the crease-adjacent face on the
stayer side. The true chain was never a ghost: once enumerated, it passes
`make` + taco checks. `flatten-two-ears-sequential` and derive-13 green;
fallback from 1a4f6d9 removed without replacement. Side finding `e_midpaper`: obsolete,
LineNew-Emergent wins in the regular way; #51 trio stays red as its own slice.
