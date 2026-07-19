# CLAUDE.md — Beloch

Beloch is a declarative language for origami, built on the Huzita-Justin axioms,
that evaluates `.bel` source into folded states, crease patterns, and YR-style
folding diagrams. Architecture decisions live in `decisions/` (ADRs); read those
before proposing anything structural. Design journal in `notes/`, dead ends in
`notes/antipatterns.md`.

## Sources & citations

Full-text papers/books live in `refs/` (gitignored — copyrighted). Each file is
named by its BibTeX cite key, with both `.pdf` and an extracted `.txt`/`.md`
(e.g. `refs/caruana2007.txt`). Machine-readable metadata is in
`paper/references.bib`; annotated prose notes in `paper/bibliography.md`.

**Citation discipline — do this, don't guess:**

- When a claim needs a source for full context, **first search `refs/`** (use
  `rg` over the `.txt`/`.md` files — fast, all sources at once) and cite by key
  + locator, e.g. `[caruana2007, §3]` or `[hull2020, p. 142]`.
- If the relevant source **isn't in `refs/`**, say so explicitly and **ask the
  user to drop it in** (`refs/<citekey>.txt` + add to `paper/references.bib`).
  Do **not** answer origami-math/PL claims from memory — memory has already
  produced a wrong attribution once (Caruana–Pace misremembered).
- New source → add a `paper/references.bib` entry and a `paper/bibliography.md`
  note in the same change.

This is an option to use freely, not a heavyweight ritual: a 5-second `rg` to
ground a sentence is always worth it; a missing source is worth one sentence
telling the user rather than a confident guess.
