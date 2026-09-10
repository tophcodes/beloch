# Origami⁴ Version-of-Record Check

**Date:** 2026-09-10. The typeset book chapter [alperin2006, pp. 371–393 in
*Origami⁴*, A K Peters 2009] was obtained via interlibrary loan. All 23
chapter pages were photographed and checked against the December 2006
preprint that `refs/alperin2006.txt` is extracted from. The photographs, a
hand transcription of the symbol listing, and the working diff live in
machine-local `refs/` (gitignored, copyrighted material). The decisive
claims below were verified twice: once by the transcription pipeline, once
by direct visual reading of the relevant book pages.

## Findings

**1. The printed symbol listing is identical to the preprint's.** The book
states and contains exactly 489 symbols, and the set is equal in both
directions to `packages/multifold/tests/fixtures/al489.txt`. Method: hand
transcription from high-resolution crops with overlapping strip re-reads,
then a mechanical set diff.

**2. All five strict-valid symbols that R4 excludes are absent from the
book listing too:** `AL2ab8`, `AL2a7a8`, `AL2a7b8`, `AL2a7a9`, `AL2a7b9`.
On the listing page [alperin2006, p. 382] the `AL2ab*` run ends at
`AL2ab7ab` and continues with `AL2a3b8`, and the `AL2a7*` run begins at
`AL2a7a10aa`. The sibling blocks `AL2a3b8`/`AL2a3b9`, `AL2a5a8`/`AL2a5a9`,
`AL2a5b8`/`AL2a5b9`, `AL2a6b8`/`AL2a6b9` are all present, so the absence
is specific to these five and is reproduced verbatim from the preprint.

**3. No additional criteria.** Definitions 1–13, the five-step enumeration
procedure, and §5–§8 contain no realness, minimality, or exclusion rule
beyond the preprint text. The book is a light copyedit of the preprint
(typo fixes such as "permuation" → "permutation", "iff" spelled out,
minor grammar and citation-position changes).

**4. The eq. (2) misprint is present in print** [alperin2006, p. 375],
with the same text as the preprint. The book prints

$$F_{L_F}(L) = \left( \frac{x(X_F^2 - Y_F^2) + 2 X_F Y Y_F}{X_F^2 - 2 X X_F - 2 Y Y_F + Y_F^2},\ \frac{y(X_F^2 - Y_F^2) - 2 X X_F Y_F}{X_F^2 - 2 X X_F - 2 Y Y_F + Y_F^2} \right)$$

(the lowercase $x$, $y$ in the numerators are the chapter's own notational
slip; the line is $L = (X, Y)$ per the surrounding text). Relative to the
corrected derivation in the Phase-1 reproduction note, the printed first
component equals $-\text{num}_X$ and the printed second component equals
$+\text{num}_Y$, over the correct denominator. The error is a single sign
flip in the first component. This supersedes the earlier "components
effectively swapped" description, which came from reading the garbled OCR
of the preprint. Worked check: fold line $x = 1$, chart $(X_F, Y_F) =
(-1, 0)$, given line $x + y + 1 = 0$, chart $(1, 1)$. The reflection
$(x, y) \mapsto (2 - x, y)$ sends the line to $-x + y + 3 = 0$, chart
$(-\tfrac{1}{3}, \tfrac{1}{3})$; the corrected formula reproduces this,
the printed formula yields $+\tfrac{1}{3}$ in the first component.

## Consequences

- The three-candidate finding (`AL2ab8`, `AL2a7a9`, `AL2a7b9`) now stands
  against the version of record. The published listing omits them, and the
  published text contains no criterion that would exclude them. Remaining
  explanations: an unwritten convention in the authors' enumeration, a
  divergence between our alignment semantics and the authors' intent, or a
  gap in their enumeration. The next available probe is a query to the
  authors.
- Eq. (2) is a published erratum, present in both the preprint and the
  book. Citable as such in the paper.
- Bibliographic data confirmed from the scans: pp. 371–393, A K Peters,
  2009, ed. Robert J. Lang.
