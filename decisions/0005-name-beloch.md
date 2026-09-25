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
- The **Beloch fold is axiom 7** in the Huzita-Justin numbering this project
  uses (see "Numbering" in `spec/SPECIFICATION.md`). Justin ordered the seven
  axioms by algebraic power, so the Beloch fold is the last and strongest one:
  the single hardest thing in the language to handle, with up to three
  solutions, no closed form, and the disambiguation problem the design keeps
  circling. Naming the language after the person whose axiom defines its
  central design problem reads as intentional in hindsight. (The
  Huzita-Hatori numbering used by Wikipedia calls the same fold axiom 6; the
  mapping table in the specification carries both.)
- She is notably under-credited; the name is a small corrective at zero cost.
- "beloch" has essentially no tech collision — the project will dominate search
  for its own name within a year.

Practical notes:

- Pronunciation: Italian, ~"beh-LOK", stress on second syllable, hard `ch`/k.
- File extension: **`.bel`**.
- Spelling: **Beloch** in prose, since it is a person's name; **beloch** as the
  wordmark, wherever the name stands alone as a mark: site header, landing
  hero, social-preview image.
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

Beloch won on: a story worth telling on stage, the axiom-7 symmetry, the
historical corrective, and near-zero search collision.

## Consequences

- Domain/TLD still open. `beloch.it` was the preferred read (nationality plus
  "Beloch [solves] it") and is taken; `beloch.co.it` is free and reads badly.
  `beloch.dev` remains the fallback. `beloch.toph.so` serves the site today.
  The choice has to close before the first citable publication, because a paper
  fixes the URL.
- README one-liner and license already updated to the new name.
