---
id: "0005"
title: "Name: Beloch"
status: accepted
---

# 0005 — Name: Beloch

## Context

The project was "OrigamiDL" for years. The `-DL` suffix is a dated IDL-era
convention, awkward to say aloud (needed often at a conference talk), and
"origami" is heavily SEO-claimed (Facebook/Quartz Composer Origami, the FT
design system, Origami Risk, the Ruby PDF library). There was no muscle memory
or live domain to preserve — only a GitHub org the author doesn't care about
(self-hosting on Forgejo with a GitHub mirror anyway).

## Decision

Name the language **Beloch**, after **Margherita Piazzolla Beloch**.

- Her 1936 work showed origami constructions solve general cubic equations,
  making paper-folding more powerful than straightedge-and-compass.
- The **Beloch fold is axiom 6** — the single hardest thing in the language to
  handle (up to three solutions, no closed form, the cubic-solving one, the
  disambiguation problem the design keeps circling). Naming the language after
  the person whose axiom defines its central design problem reads as intentional
  in hindsight.
- She is notably under-credited; the name is a small corrective at zero cost.
- "beloch" has essentially no tech collision — the project will dominate search
  for its own name within a year.

Practical notes:

- Pronunciation: Italian, ~"beh-LOK", stress on second syllable, hard `ch`/k.
- File extension: **`.bel`**.
- Language vs implementation split, if ever needed: **Beloch** the language,
  **belochc** (or **Piazzolla**, her middle name) the compiler.
- `beloch fold file.bel` reads as English and is literally the operation — and
  "fold" is also the functional-programming reduce, which is what the evaluator
  does. (See [0007](0007-evaluator-not-compiler.md).)

## Alternatives considered

- **Keep OrigamiDL** — defensible (descriptive, existing org) but dated suffix,
  hard to say, SEO-drowned.
- **Pleat / Crease / Plica** — short, evocative, low collision; good but no
  story.
- **Kami / Ori** — Japanese roots; some overload.

Beloch won on: a story worth telling on stage, the axiom-6 symmetry, the
historical corrective, and near-zero search collision.

## Consequences

- Domain/TLD still open (leaning `beloch.it` for the nationality + "Beloch [solves]
  it" read, `beloch.dev` as fallback); optional while self-hosted.
- README one-liner and license already updated to the new name.
