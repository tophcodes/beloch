# 0014 — A crease is a bundle of segments

## Status
Accepted (2026-07-03)

## Context
After #28 a named crease was `Material(crease_id, line)` and was treated as a
single line at every use-site. But creating a crease runs `subdivide`, which cuts
**every face the axis crosses** and tags each resulting edge with one shared
`crease_id`. So a crease was *already* — materially — a **set** of edges; the
language merely collapsed it to its supporting line.

This became unavoidable when designing how to reference *one* segment of a crease
(the piece on a particular flap). #28's `--( --d #(...) )` escape hatch was clunky
and clashed grammatically with `--( … )` line-construction. The deeper facts a
single "line" hides:

- a crease drawn across a stack of N layers is **N segments**, one per layer;
- those segments are collinear **only** in the folded configuration at creation —
  folds are reflections, so on unfold each maps to a differently placed and
  oriented preimage, scattering across the crease pattern;
- each segment is the axis clipped to its face polygon, so they generally have
  **different lengths** and may occupy disjoint intervals.

"Crease = line" is therefore true only in one fleeting collinear moment.

## Decision
A crease name denotes a **bundle**: one `crease_id` realised as a set of material
segments (one per crossed face, further split by later crossings). The bundle,
not the line, is the durable referent of a crease name.

- **Singleton-target rule.** An operation that consumes a crease as its *target*
  requires a **length-1** bundle. A length-1 bundle is reached three ways: an
  unsegmented/trivial crease; creating a single segment (a `pinch` primitive); or
  projecting a longer bundle down by disambiguation (an `at` selection operator).
  Consuming a bundle of length >1 is an error that asks for disambiguation.
- **Collapse to a line** (when a fold/reflection *axis* is wanted) is valid only
  while the bundle is currently collinear; once (un)folding has scattered it the
  collapse is refused and the program must select a segment, which then supplies
  its own supporting line. Selection is incidence-based and so works in any form,
  folded or flat.
- Deferred: a **segment-set as a first-class value** (an array-of-segments
  datatype). Single-segment work goes through `at`/`pinch`; whole-bundle work
  through a bare bind (which already creases every layer). Revisit only if
  selecting a proper subset proves common.

The surface mechanisms (`at`, `pinch`) and their exact syntax are a
specification/slice concern, not this decision; the durable decision is the
bundle model itself. Full design:
`notes/2026-07-03-crease-segment-at-operator.md` and
`notes/2026-07-03-crease-layer-selection.md`.

## Alternatives considered
- **Keep "crease = line", add a separate segment type.** Rejected: it denies what
  the data already is (one `crease_id`, many edges) and forces every crease
  reference to choose up front between "line" and "segment", when the natural
  referent is the whole bundle and the line/segment are *projections* of it.
- **A dedicated sigil for segments** (distinct from `--` creases). Rejected: a
  segment is not a different *kind* of entity, only a projection of a bundle, and
  a set-of-segments never becomes a value you pass around (see the deferral).
  Surface spelling — sigil vs. keyword operator — is a specification/slice detail,
  out of scope for this ADR (per the ADR scope rule).
- **Make the segment-set first-class now.** Rejected as premature: it is the one
  case that would justify an array datatype, and it is rare. Deferred until a real
  need forces it, keeping the type surface at line + segment.

## Consequences
- Supersedes #28's `--( --d #(...) )` / `#(...)` restrict escape hatch, folded
  into the `at` operator.
- The "crease = line" mental model is retired: a crease is a set, collapsed to a
  line only when collinear, and never a single line in the crease pattern.
- Points and flaps carry layer identity, so they are the selectors that reach
  across the stacking axis; a purely table-space selector cannot disambiguate
  stacked copies.
- ">1 ambiguous" becomes a routine outcome, so bundle **inspection** (enumerate a
  crease's segments, in folded and CP coordinates) becomes a needed
  evaluator/tooling affordance — not a language construct.
- Implementation is mostly additive: `fold_state` edges already carry `crease_id`
  + endpoints, so `at` is a query over the existing subdivision; `pinch` is a
  narrowed `subdivide` plus a display flag on the edge.
- The spec (`spec/SPECIFICATION.md`) is extended only when the implementing slice
  lands; until then this feature sits in Appendix B.
