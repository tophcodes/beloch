# 2026-07-06 — the evaluated program is a diff/commit history, not just an endpoint

Follow-on from `2026-07-06-fold-as-operation-sequence.md`. Once evaluation is
accepted as imperative (statement N mutates state, deterministically, no
solver), what falls out is a stronger claim than "we get the folded state":

**We get a full history of mutations to points, flaps, and creases, from the
flat sheet to the finished model.** That history is structurally a diff /
commit log, not just a snapshot.

## The analogy

- **Flat sheet** = initial commit (empty repo / root state).
- **Each fold statement** = one commit. It touches a specific, identifiable
  subset of the mesh — the points it introduces, the creases it adds, the
  flaps it splits or re-layers. Everything untouched by that statement is
  unchanged, exactly like unchanged files in a commit.
- **Final folded state** = HEAD.
- **Any intermediate state** = checking out an earlier commit. Well-defined
  because evaluation order is a total order (this is what "imperative" buys
  us) — there's no ambiguity about what "the state after step 3" means.

This isn't a metaphor bolted on after the fact — it's just what you get for
free once you take Claim 2 of the operation-sequence note seriously: a
deterministic imperative mutation trace over a versioned structure *is* a
commit history, by definition, whether or not the code is architected to
expose it as one.

## Why this is worth writing down (not just cute)

Every rendering mode Beloch already has or plans is a **view over this
history**, not a separate computation:

- **CP view** ([[beloch-render-engine-design]], `renderCP`) = the union of all
  creases across the whole diff, flattened back onto flat-sheet coordinates.
  It's "git diff root..HEAD, but only the crease-touching hunks, applied as
  an overlay."
- **Folded view** (`renderFolded`) = state at HEAD.
- **YR-style step diagrams** (stated future output, see CLAUDE.md) = the
  history rendered **one commit at a time** — literally per-statement diffs,
  shown in sequence. This is the one where the commit-log framing stops being
  cute and starts being load-bearing: a YR diagram generator doesn't need new
  machinery, it needs to walk the existing history and render each commit's
  diff.
- **Fold scope** (ADR 0016, PR #67, [[beloch-fold-scope-and-operand-model]]) —
  already, in effect, lets a statement select *which prior commits' resulting
  state* it operates against (mover/stayer partitioning per hinge). The
  commit-log framing was already implicit in shipped work; this note just
  names it.

## Open fork (not decided, not urgent)

Should the *language* ever expose this history as an addressable object —
e.g. "the crease introduced at step 3" as a first-class reference, the way
`git log`/`git blame` expose history as queryable? Interesting, but a
capability-layer question ([[beloch-two-layer-design]]), separate from
current roadmap ([[beloch-workflow-and-roadmap]]). Flagging so it doesn't get
reinvented from scratch later.

## Non-citation note

This is a software-engineering analogy (version control), not an
origami-math claim — no `refs/` grounding needed. If it ever gets formalized
as "fold history is a DAG" (branching/undo semantics), *that* would need
checking against any procedural-origami-description-language literature
before writing it up as fact.
