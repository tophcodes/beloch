# 0019 — Attribution is carried by construction

## Status

Accepted (2026-07-22) — the *stance* below is decided. The input mechanism that
populates provenance (a source-level annotation) is designed separately in
[docs/superpowers/specs/2026-07-22-annotation-layer-design.md] and is **not yet
implemented**; until it ships, the emitter has nothing to propagate.

Does **not** change [0006 — Permissive license (MIT)]. MIT stands everywhere,
unchanged. Attribution here is a *capability*, never a license obligation — see
*Decision* §3.

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

### 3. Attribution is a capability, not a license obligation

The license stays **permissive MIT everywhere** ([0006]), unchanged. It grants
no exception and imposes no attribution duty. Our license does not tell a user
*"if you use this, you must handle attribution."* It tells them *"here is how you
declare attribution"* — a way to say who designed a model — and then gets out of
the way.

The norm is set by **example, not by force**: Beloch's **first-party tooling —
the official playgrounds and renderers — displays declared attribution by
default.** In the surfaces people actually look at, the credit is simply there.
That makes the honest path the visible default without constraining, in any way,
what anyone may do with the MIT-licensed code.

### 4. Explicitly rejected: license teeth of any kind

Two framings were considered and both rejected, recorded so we do not
relitigate:

- **Field-of-use ("visualization only for your own works").** Does not defend
  the goal: if FOLD-emit is free-for-anything, the `.fold` file is out and *any*
  FOLD viewer (Rabbit Ear, Oripa, a three.js snippet) renders it prettily —
  restricting Beloch's *own* renderer only pushes pretty replication elsewhere,
  never stops it. It also binds the wrong population (taxes the honest user, the
  thief ignores it) and reverses [0006]'s adoption-first stance (a field-of-use
  clause is not open source — fails freedom 0) for that illusory gain.
- **Attribution-retention as a license obligation** ("declared credit must
  survive in rendered output, or you are in violation"). Rejected too: it is
  exactly the *"you must handle attribution"* framing we do not want. It taxes
  honest users with a legal duty and contradicts the permissive stance, to
  protect against stripping that, per the first bullet, any third-party FOLD
  viewer sidesteps anyway.

The lever is not law. It is making declaration easy and showing the result in
our own tools.

### 5. Not frozen here

- The exact `.bel` input syntax for the provenance declaration — designed in the
  annotation-layer spec, not this ADR.

## Consequences

- **MIT stays intact everywhere.** No license split, no multi-licensing, no new
  clause. [0006] is unchanged.
- **Attribution is opt-in.** Nothing is forced on a plain scratch file; a `.bel`
  that declares no provenance carries none. Where it *is* declared, the honest
  path becomes the visible default because our own tools show it — deleting
  credit becomes a deliberate act rather than the ambient outcome.
- **First-party tooling leads by example.** The official playgrounds and
  renderers display declared attribution by default. This is the whole
  enforcement mechanism: not a legal duty on anyone, but Beloch's own surfaces
  modelling the norm.
- **Honest limit — no overclaim.** Beloch cannot stop anyone from stripping
  credit, and this ADR says so plainly. Its reach is exactly two things: make
  declaring provenance easy, and show it by default in first-party surfaces.
  Someone who exports FOLD and renders elsewhere is free to do as they like.
- **Roadmap.** The provenance feature — input syntax, emit propagation, and
  first-party display — is its own slice, tracked separately, with the
  annotation layer as the vehicle and attribution as its first client.
- **Open — community-norm grounding.** The origami community's attribution norm
  (the folded-object-vs-diagram/CP distinction; Lang's writing on origami and
  copyright) is real but **not yet sourced in `refs/`**. This ADR deliberately
  does not state it from memory (a wrong attribution has happened before — see
  CLAUDE.md). To cite it in the paper or spec, drop `refs/<citekey>.txt` +
  `paper/references.bib`; until then this is a marked gap, not a claim.

## Alternatives considered

- **Attribution-retention as a license obligation** — MIT-plus-attribution on
  the visualization features, credit required to survive in rendered output.
  Rejected: it is the "you must handle attribution" framing we explicitly do not
  want, and it fragments the license for protection any third-party viewer
  sidesteps. See Decision §4.
- **Field-of-use split** ("renderer only for your own works") — see Decision §4.
