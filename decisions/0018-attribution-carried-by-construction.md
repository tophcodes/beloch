# 0018 — Attribution is carried by construction

## Status

Accepted (2026-07-22) — the *stance* and the *license split* below are decided.
The input mechanism that populates provenance (a source-level annotation) is
designed separately in
[docs/superpowers/specs/2026-07-22-annotation-layer-design.md] and is **not yet
implemented**; until it ships, the emitter has nothing to propagate and the
retention clause has nothing to protect.

Amends [0006 — Permissive license (MIT)], which now holds for the language core
and the FOLD-emit runtime only. See *Decision* §3.

## Context

A recurring worry about a language like Beloch: doesn't it make it *easy to
steal* someone's model — replicate anything you see and re-render it prettier
for your own site?

The honest answer is that Beloch opens **no new door**. Replication from
observation was always possible: crease patterns, `.fold` files, published
diagrams, and photographs already let anyone reconstruct a model. A source
language changes the *medium* of replication, not its *possibility*. The "you
could steal models with this" argument applies just as well to the folding
diagrams the origami community has shared for decades.

What Beloch *does* change is that it makes re-expression cheap and decouples a
polished rendering from its source. You can look at a model, transcribe it into
`.bel`, and render it more nicely than the original. That is not a new
*capability* — it is an **attribution-dilution** risk. Credit falls off easily
because a fresh re-expression looks like original work.

Today credit falls off completely, because it is first-class *nowhere*. The
evidence is in the tree: `playground/peacock.bel` carried a hand-written
`# Copyright:` line pointing at the designer's page — dead text the lexer does
not even tokenize (`#` is taken by `#[`/`#(`; only `;`-to-EOL is a comment). The
one honest signal the author bothered to write had no place to live.

## Decision

### 1. Provenance is a first-class output concern

A source-level provenance declaration — model **author**, **source**, and
**license** — SHALL exist, and the emit path is responsible for propagating it
into every export **without loss**. This is a *design principle*, not a feature
shipped by this ADR.

The mechanism already has a home. `packages/core/lib/fold_emit.ml` writes
`file_creator: "beloch <version>"` into every FOLD file today. Model provenance
maps directly onto FOLD's standard metadata keys — `file_author`, `file_title`,
`file_classes` — plus `beloch:source` / `beloch:license` as namespaced
extensions (per [0002 — FOLD-extended as output]). No new subsystem; a slot that
already exists, populated from a declaration that does not yet exist.

### 2. Two attribution objects, kept distinct

- **Code attribution** — who wrote the *evaluator*. Already handled everywhere
  by MIT's notice-retention requirement. This ADR does not touch it.
- **Model / content attribution** — who designed the *origami*. New, and the
  only thing this ADR governs.

Conflating the two is the usual mistake. MIT already makes you keep the code
notice; it says nothing about the model whose crease pattern you transcribed.

### 3. License shape — a split, not a field-of-use restriction

- The **language and the FOLD-emit runtime** stay **MIT** ([0006]). Use them for
  anything.
- The **visualization / rendering features** carry **MIT plus an
  attribution-retention clause**: where a `.bel` declares model provenance, that
  credit MUST survive in the rendered output; stripping it is a license
  violation. There is OSI-compatible prior art for attribution-in-output
  (badgeware / CPAL-style clauses). The exact SPDX identifier or license text is
  **not decided here** — only the shape.

This is deliberately *attribution-copyleft*, not *field-of-use*. It constrains
whether declared credit may be **stripped**, never *what you are allowed to
depict*.

### 4. Explicitly rejected: "visualization only for your own works"

An earlier framing split the runtime by *use*: the renderer usable only to
depict your own models, or free-with-attribution otherwise. Rejected, for
reasons worth recording so we do not relitigate:

- **It does not defend the goal.** If FOLD-emit is free-for-anything, the
  `.fold` file is out, and *any* FOLD viewer (Rabbit Ear, Oripa, a three.js
  snippet) renders it prettily. Restricting Beloch's *own* renderer only pushes
  pretty replication to another viewer — it never stops it.
- **It binds the wrong population.** A field-of-use clause taxes the honest user
  who actually wanted Beloch's renderer, while the model thief ignores it as
  readily as any attribution norm.
- **It reverses openness for that weak gain.** A field-of-use restriction is not
  open source (it fails freedom 0) and reverses [0006] wholesale, costing
  adoption and contributors — for a protection §4's first bullet already shows is
  illusory.

### 5. Not frozen here

- The exact `.bel` input syntax for the provenance declaration — designed in the
  annotation-layer spec, not this ADR.
- The exact visualization license text / SPDX identifier.

## Consequences

- **The monorepo becomes multi-licensed**: core + emit under MIT, visualization
  under MIT-plus-attribution. This must be documented at the package level
  (`packages/render-2d`, `packages/eval-web`, `LICENSE.md` pointers) when the
  clause is chosen. [0006] is amended accordingly.
- **Retention bites only where provenance is declared.** No declaration, nothing
  to retain. The honest path becomes the default path, and deleting credit
  becomes a deliberate act rather than the ambient outcome — but nothing is
  forced on a plain scratch file.
- **Honest limit — no overclaim.** The clause governs Beloch's *own* renderer's
  output, not the universe. Someone who exports FOLD and renders elsewhere is
  outside its reach, and this ADR says so plainly. It makes stripping credit from
  Beloch's polished output a violation; it cannot and does not police re-rendering
  by third-party tools.
- **Roadmap.** The provenance feature — input syntax, emit propagation, and the
  visualization license — is its own slice, tracked separately, with the
  annotation layer as the vehicle and attribution as its first client.
- **Open — community-norm grounding.** The origami community's attribution norm
  (the folded-object-vs-diagram/CP distinction; Lang's writing on origami and
  copyright) is real but **not yet sourced in `refs/`**. This ADR deliberately
  does not state it from memory (a wrong attribution has happened before — see
  CLAUDE.md). To cite it in the paper or spec, drop `refs/<citekey>.txt` +
  `paper/references.bib`; until then this is a marked gap, not a claim.

## Alternatives considered

- **Norm + mechanism, no license teeth** — carry attribution by construction
  (populate `file_author`) but never mandate it; MIT stays intact everywhere.
  The minimal, conflict-free path. Rejected in favour of the retention clause,
  which gives the stated principle actual force in Beloch's own output without
  fragmenting adoption. (The retention clause degrades gracefully to this if the
  license work is ever dropped: the emit propagation stands on its own.)
- **Field-of-use split** — see Decision §4.
