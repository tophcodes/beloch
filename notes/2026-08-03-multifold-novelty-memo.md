# Multifold Phase 0 — Novelty Memo

**Question:** Does a complete enumeration/classification of 3-fold origami
axioms — the analogue of Alperin & Lang's 489 two-fold operations
[alperin2006] — exist anywhere in the literature?

**Verdict: NO — high confidence. Phase 1 is GO.**

## Method

Three independent checks (two web-research agents + a full read of
[alperin2006] from `refs/`):

1. Citation trail of [alperin2006]: papers citing it that attempt k≥3
   enumeration.
2. OEIS: does a sequence "number of k-fold axioms" (7, 489, …) exist?
3. The Japanese computational-origami school (Ida, Ghourabi, Kasem —
   Eos system), which formalizes fold operations with Gröbner bases.

## Evidence

- [alperin2006] itself enumerates only k=2 (§4: 17 alignment symbols,
  93,636 raw combinations → 489 non-separable 2FAs with AL10 / 203
  without). §8 ("Three-Folds and More") gives Definition 13 (N-fold
  axiom), ONE 3-fold construction (general quintic via Lill), and
  Theorem 1 (degree n solvable with n−2 folds). Minimality of n−2 is
  stated as a conjecture: "We conjecture that this upper bound … is the
  minimum number required." No k=3 enumeration.
- Citation trail: only ad-hoc multifold constructions found, no
  classification. Notably "Geometric solution of a six order equation by
  three-fold origami" (Theoretical and Natural Science, EWA;
  https://tns.ewapub.com/article/view/2729) — a single sextic
  construction, no enumeration. König & Nedrenco (arXiv:1504.07090) and
  Lucero (arXiv:1801.07460, arXiv:1807.09557) stay at k=2; Lucero's
  "On the elementary single-fold operations" (arXiv:1610.09923) at k=1.
- Eos school: uses multifold as a *tool* for specific constructions
  (angle quintisection, SCSS 2008; heptagon knot fold) verified via
  Gröbner bases; their "extensions" of Huzita operations mean conics,
  not multifold (Ghourabi/Kasem/Kaliszyk, ADG 2012). No enumeration.
- OEIS: no sequence counting k-fold axioms. Searches for 489, seq 7,489,
  "origami", "Huzita" — nearest hit A116967 (points reachable after n
  single folds) is a different object. The sequence would be new.

## Caveats / open items

- Our `refs/alperin2006.pdf` is a circulating draft (unresolved "– RJL"
  editorial remark in §6.2.3). The published Origami⁴ chapter (A K
  Peters, 2009) must be obtained and the 489/203 counts verified against
  it before Phase 1 treats them as the reproduction anchor.
- ETH Zürich BSc thesis "Mathematics of Origami" (Kunz, 2024) could not
  be fully inspected (PDF not extractable); no indication of a 3-fold
  classification found in what was visible.
- The sextic three-fold paper should be obtained for `refs/` — it is the
  closest existing k=3 work and must be cited and compared.

## Consequences

- Phase 1 (two-fold machinery, reproduce 489/203) is GO.
- The 3-fold alignment *alphabet* does not exist in the literature and
  must be derived, including an explicit, defended decision on whether
  alignments may nest reflections (F_a(F_b(P))) — [alperin2006] uses
  single reflections only.
- The OEIS sequence (7, 489, …) is available as a cheap secondary
  novelty once our k=2 reproduction and any k=3 count exist.
