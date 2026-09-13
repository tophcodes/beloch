---
id: "0022"
title: "A construction is its alignment set; an axiom number names one"
date: 2026-09-13
status: accepted
---

# 0022: A construction is its alignment set; an axiom number names one

## Context

A construction is the read that yields a fold line: the seven Huzita-Justin
axioms, written today as seven prose forms (`map .a onto .c`, `through .a
.b`, `perp --l through .p`, …) and represented in the syntax tree by seven
constructors of `Ast.axiom`, one per axiom, each dispatched to its solver in
`Axiom`.

Alperin and Lang show that each axiom is a minimal set of alignments, an
alignment being an incidence between two objects of which one is a point or
line folded across the line sought: point onto point, point onto line, line
onto line, the fold line through a point, the fold line perpendicular to a
line. The seven axioms are the seven such sets that determine one fold line
with finitely many solutions, and the same alignments distributed over two
fold lines give the 489 two-fold axioms [alperin2006, §3, §4]. The language
reference (`spec/BELOCH.md`, Constructions) and the model (`MODEL.md`,
Definition 4.7) now state constructions in these terms: the alignment set is
the canonical form, written `(align …)`, and the prose forms are sugar for
it. `packages/multifold` (ADR 0020) enumerates the two-fold sets under
Alperin and Lang's names.

The question this record settles is what the syntax tree keeps. Two options
were designed side by side in
`docs/superpowers/specs/2026-09-13-item-syntax-design.md`:

- A: recognise an `align` form in the parser and map it onto the existing
  seven constructors; the alignment set is a surface object and is gone after
  parsing.
- B: the alignment set is the one representation of a construction in the
  tree; the prose forms desugar to it at parse time; the seven sets are
  recognised where a solver is needed.

Two sites in library code match on the seven constructors today,
`Axiom.axis_of` with seven arms and the implied-anchor derivation in `Eval`
with three arms; one test file matches on them in 36 lines.

## Decision

Option B. A construction in the syntax tree is a record holding its
alignments, its named fold lines (empty for a one-fold construction) and its
selection (`toward`). The prose forms are parsed into that record; no
constructor per axiom remains.

- `Axiom.classify` maps an alignment set to one of the seven axioms by the
  multiset of its alignment kinds, with source order fixing operand order
  where a kind occurs twice (axioms 1 and 7). A set that is none of the seven
  is an error naming the alignments. A construction with named fold lines,
  or an alignment carrying a fold-line prefix, is parsed and kept and fails
  at evaluation as not yet solvable.
- `Axiom.implied_point` derives the moved point a map fold implies as its
  anchor from the alignment set, so that the knowledge of which alignment
  carries the anchor lives beside `classify` and outside `Eval`.
- Provenance tags (`"axiom1"` … `"axiom7"`) and the `sources` record are
  produced from `classify`'s result and are unchanged in the output.
- The sugar claim, that a prose form and its `align` spelling mean the same,
  is checked by evaluating both and comparing the resulting lines, since the
  two spellings need not fix the same alignment order in the tree.

## Alternatives considered

- **A, recognition in the parser onto the seven constructors.** Rejected.
  The canonical form would exist in the documents and nowhere in the
  program's representation; a formatter could not print `align` from a tree
  parsed from prose; and the two-fold constructions of ADR 0020 need the
  alignment set in the tree, so a second representation would arrive with
  them and every consumer would handle both.
- **Both representations, `align` as an eighth constructor beside the
  seven.** Rejected for the same reason in the present tense: two ways to say
  one fact, and consumers that have to agree on them.

## Consequences

- The seven axiom numbers remain as names: in error messages, provenance,
  documentation and the recognition table. They are no longer types.
- Two library sites and one test file change; the solvers in `Axiom` are
  untouched below `classify`.
- The two-fold constructions of `packages/multifold` have a source-level
  object to bind to when they are wired into the kernel; the syntax for
  naming fold lines inside `align` stays open in `spec/BELOCH.md`
  (`#open-multifold-syntax`).
- `spec/MODEL.md` Definition 4.7 already states a construction as a set of
  alignments; nothing in the model changes.
