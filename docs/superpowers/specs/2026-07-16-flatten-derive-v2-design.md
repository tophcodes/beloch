# flatten V2: one solver — constraints filter, `{toward}` disambiguates (design)

## Status

Approved direction (2026-07-16, with Toph; supersedes this file's earlier
same-day draft that still split derive/validate by `toward`-presence). Builds
on the two-tier opposite-ray fix (`feat/flatten-opposite-ray`, 364660f).

## Motivation

At the fish-base vertex the emergent ray is unique but the fold has two
physical realizations (ear to the b-side or d-side) — the difference lives in
the M/V pattern of the *given* rays, which V1 treated as bound (default
valley). So `toward .b` ≡ `toward .d`: useless as a direction choice. The
swivel-rabbit vertex masked this (there, ray choice and side choice
coincide). The user's model is simpler and wins: **the user supplies the
topology and, when needed, a direction; mountain/valley and stacking are the
solver's job.**

## The model: one mode, one pipeline

`flatten` no longer has validate/derive modes. Every statement runs the same
pipeline:

1. **Count rays.** Odd → one emergent ray is part of the solution space
   (candidates from the V1 machinery: same-direction filter, opposite-ray
   admitted, two-tier preference). Even → no emergent ray.
2. **Enumerate the solution space**: (emergent-ray candidate ×) M/V
   assignment over all rays (Maekawa |M−V| = 2) × stacking — each candidate
   realization checked by the collapse oracle (Kawasaki closure,
   non-crossing, in-bounds anchor) and filtered by every **hard constraint**
   the statement gives: `mountain`/`valley` element markers, `(x over y)`.
   Realizations are deduped by observable stacking signature.
3. **Decide by |S|** (S = surviving realizations):
   - |S| = 0 → infeasible error (out-of-paper vs does-not-close
     differentiation as today).
   - |S| = 1 → fold it. A disambiguator, if present, is redundant — allowed,
     never an error (redundancy is lint-territory, not error-territory).
   - |S| > 1 → apply the **disambiguator** `{toward .p}`: keep the
     realization maximizing `(centroid(final placement of MOVED faces) − O) ·
     (toward − O)`, exact over `Num`. Moved faces = faces whose final
     placement differs from their pre-flatten placement. Tie or no
     disambiguator → ambiguous error naming what's missing ("N realizations;
     add `{toward .x}`" / "aim it off the creases" on a tie).
   - Tier rule (364660f) applies before scoring: realizations on line-new
     emergent candidates outrank opposite-ray ones; the deciding set is
     tier 1 if non-empty.

## Syntax

```
flatten_stmt  := [ CREASE_NAME "=" ] "flatten" flatten_item+
flatten_item  := "(" flatten_elem ")"
               | "(" over_flap "over" over_flap ")"
               | "(" "standing" flap_operand ")"
               | "{" "toward" point_operand "}"
flatten_elem  := line_operand [ "mountain" | "valley" ]
```

- **`()` vs `{}` is semantic**: parentheses carry the problem statement (rays
  and hard constraints — they *filter* S); braces carry selection from the
  remaining solution space (they *choose* within S). `{toward .p}` is an item
  (any position, at most one); the old trailing `toward` is removed.
- `valley` joins `mountain` as an explicit marker; a **bare element is
  unconstrained** — the solver assigns its M/V. (Old semantics: bare =
  valley. This is the one deliberate break; see Migration.)
- `{…}` deliberately previews issue #46's `#{…}` solution-space family:
  braces = solution space; `#{…}` will *denote* one, `{…}` *selects from*
  one. Extending `{}` to axiom-level `toward` is #46's scope, not this
  slice's.

## Kernel changes

- `Collapse.elem.valley : bool` generalizes to a tri-state constraint
  (`Free | M | V`) at the language boundary; the kernel enumerates Maekawa-
  consistent completions of the free slots.
- New enumerating entry point (`collapse_all`) returning every
  distinct-signature Ok realization; the single-result-or-`e_ambig` contract
  becomes a wrapper over it (used by nothing after migration, but keeps the
  kernel honest and the old error strings testable).
- The 364660f probe/materialize helper (one pre-minted cid, no ctx mutation)
  is reused for candidate rays.

## Migration (this slice)

- `examples/bases/waterbomb.bel` + its golden: **deleted** (Toph: obsolete;
  not worth migrating).
- `swivel-rabbit.bel`: `toward .c` → `{toward .c}`; bare rays now mean
  unconstrained — the material-centroid metric must still pick the same
  right-hand swivel; **the golden is the regression anchor. If a different
  realization scores higher for `toward .c`, STOP and adjudicate — do not
  regenerate silently.**
- `tests/cases/**` flatten cases: migrate syntax (`{toward …}`); revisit
  expectations only where bare-element freedom genuinely widens S (each
  change cites this spec).
- `spec/SPECIFICATION.md` §4.9: rewrite to the one-pipeline model (topology +
  hard constraints in `()`, selection in `{}`, M/V derived, Maekawa/Kawasaki
  as the oracle), including the `valley` marker and the `{}`-syntax rationale.
- Fish-base acceptance: `{toward .b}` and `{toward .d}` produce the two
  mirror realizations (DIFFERENT folded states — the whole point).

## Scope / deferred

- Single vertex only; multi-vertex flatten (true fish base) stays deferred
  (spec §4.9 Appendix B).
- `#{…}` literals + axiom-wide `{}` selection = issue #46.
- Combinatorics: n ≤ 6 rays realistic → ≤ 2n Maekawa patterns × ≤ 3 candidate
  rays × small stacking counts — cheap; no optimization work in this slice.

## References

- Two-tier fix 364660f (this branch); V1 design
  `2026-07-15-flatten-generalizes-collapse-design.md`.
- [hull2020, §5.3 (Kawasaki), Thm 8.5; §6.6 NP-hardness context].
- spec/SPECIFICATION.md §4.9; issue #46 (solution-space surface).
