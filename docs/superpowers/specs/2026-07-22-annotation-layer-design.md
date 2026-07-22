# Annotation layer — `;;` doc-annotations for display-layer concerns

**Status:** Proposed (2026-07-22). First client is the provenance stance in
[decisions/0018-attribution-carried-by-construction.md]. Not yet implemented.

## Context

Beloch statements describe *folding* — geometry the evaluator turns into a
folded state. A second, separate class of information is about **presentation**,
not geometry:

- **who designed the model** (author, source, license) — see [ADR 0018];
- **prose between steps** — the caption text a diagram shows alongside a fold;
- **step grouping** — which folds collapse into one displayed step.

None of these have a home today. A `.bel` file can only say them in a `;`
comment, and the lexer discards `;`-to-EOL before the parser sees it
(`packages/core/lib/lexer.ml`: `';', Star (Compl '\n') -> token buf` recurses
without emitting a token). So a comment cannot carry anything that must reach
emit or render — it is thrown away by construction. ADR 0018's "provenance is a
first-class output concern" therefore needs a channel that **survives to the
AST**. This spec designs that channel, and makes it general enough to serve all
three concerns rather than bolting on a provenance-only hack.

These three concerns share a nature: **display-layer, non-geometric, must
survive to emit/render, ignored by the fold evaluator.** One low-level mechanism
can carry all three; only their surface differs.

## The mechanism: `;;` doc-annotations

Mirror the doc-comment convention (`//` vs `///` in Rust, `;` vs `;;;` in Lisp):

- `;` stays a **throwaway comment** — unchanged, still discarded by the lexer.
- `;;` is a **retained annotation** — it lexes to an `ANNOTATION` token carrying
  its text and source position, reaches the parser, and lands in the AST as a
  node the evaluator ignores and the emitter/renderer consumes.

This is purely additive and collision-free. Today `;; foo` is just a comment
that happens to start with `;`. A `;;` lexer rule ordered **before** the `;`
rule matches the longer prefix first; nothing about the fold grammar changes.

Because a `;;` annotation is a real token in the statement stream, its
**position is recorded for free** — an inline note "lands here" between the two
fold statements it sits between, with no extra machinery.

## Three tiers

One node type, three surface uses:

### Tier 1 — file-meta (ships in slice 1)

A **recognized keyset** — `author`, `source`, `license` — in the **leading
annotation block, before the first fold statement**. First word after `;;` is
the key; the rest is the value.

```
;; author Jon Akashima
;; source https://jonakashima.com.br/2020/08/17/origami-peacock/
paper square
...
```

Consumed by emit: `author` → FOLD `file_author`, a `title` key → `file_title`,
`source`/`license` → `beloch:source` / `beloch:license` extension fields (per
[ADR 0002]). This is the propagation ADR 0018 §1 requires.

### Tier 2 — inline note (ships in slice 1)

An annotation whose first word is **not** a recognized key, appearing **between**
statements, is free-text caption prose attached to that position.

```
fold --h moving .c
;; Valley-fold the wing down to the spine.
mark --l = map .c onto .a #[.c]
```

Consumed by the step-diagram output ([ADR 0002]'s versioned instruction JSON)
and the docs stepper as the caption for the step at that position.

### Tier 3 — step grouping (deferred)

"These N folds are one displayed step" is a **span**, not a point, and it
reopens the deliberately-retired `step` keyword (numeric frames only, revisit
later — see the step-keyword-retired history). It is a genuinely harder shape
and is **out of scope for slice 1**; noted here only so the mechanism is
designed not to preclude it (a paired `;; step {` … `;; }` or a block form can
layer on later without changing the token).

## Disambiguation rule

To keep `;; author Jon Akashima` (metadata) apart from `;; Valley-fold …`
(prose) with no ambiguity:

- **Recognized keys** (`author`, `source`, `license`, `title`) are metadata
  **only in the leading block** before the first fold statement. First token
  after `;;` matches the key exactly.
- **Everything else** — any `;;` after the first fold statement, or a leading
  `;;` whose first word is not a recognized key — is a free-text note.

This means a mid-file `;; author was drunk` is prose, not metadata, and the
leading block cannot be accidentally polluted by ordinary comments (which stay
single-`;` and are still discarded).

## Consumption path

- **Parser / AST**: add an annotation node kind carrying `{ kind: meta-key |
  note, text, position }`. The evaluator threads it through untouched — it never
  affects folded-state geometry.
- **`fold_emit.ml`**: read leading meta-keys into the FOLD metadata dict already
  being built next to `file_creator`.
- **First-party renderers / playgrounds**: display declared attribution by
  default — this is the "lead by example" lever from [ADR 0018] §3, and the only
  enforcement Beloch has. Not a license duty on anyone; Beloch's own surfaces
  simply show the credit.
- **Instruction / step JSON + docs stepper**: attach notes to their positional
  step.

## Slice 1 scope

**In:** `;;` lexer rule + `ANNOTATION` token; annotation AST node; Tier 1
file-meta emitted to FOLD author/title/source/license and displayed by the
first-party playground/renderer; Tier 2 notes emitted to the instruction JSON.
`playground/peacock.bel` becomes the first real user of `;; author` /
`;; source`.

**Out:** Tier 3 step grouping; the `refs/`-grounded community-norm prose
(ADR 0018 open item). No license change of any kind — MIT stays intact
([ADR 0006]); attribution is a capability, not an obligation.

## Open questions

- Is `title` part of the recognized keyset from day one, or only
  `author`/`source`/`license`? (Leaning: include it — cheap, maps to
  `file_title`.)
- Do notes need any lightweight markup, or is plain text enough for the diagram
  caption? (Leaning: plain text; revisit if the stepper needs emphasis.)
- Multi-line values: does a `;; source` URL ever wrap? (Leaning: one line per
  annotation, no continuation — keep the lexer rule trivial.)
