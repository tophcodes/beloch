# BEPs

A BEP (Beloch Evolution Proposal) records a decision about what a program
means ([[ADR-0062]]). `docs/reference/` states the current rule; the BEP
keeps why the rule is what it is, the case that showed it, and what was
rejected. States and numbering: `../README.md`.

The pull request that adds a BEP edits the reference in the same change.
After the merge nobody edits the BEP's prose. A later BEP that changes the
rule edits the reference again and names the earlier one under `amends`.

## Format

```yaml
---
id: BEP-0063
title: "Which layers a fan moves"
date: 2026-11-18
status: accepted               # accepted | superseded | abandoned
issue: tophcodes/beloch#150    # optional: the issue that raised it
reference:                     # the reference sections the pull request changed
  - reference/beloch-writes#fan
amends: []                     # earlier BEPs whose rule this one changes in part
superseded-by: null            # set when the BEP moves to archive/ as superseded
---

# BEP-0063: Which layers a fan moves
```

The title names the subject. The sections, in order:

- **Summary**: the decision in two or three sentences, without terms the
  reader has to look up.
- **Example**: a program on a real model, with its folded state and layer
  order, and what the rule makes of it.
- **Rule**: the text that went into the reference, in the reference's terms,
  with an id link to each section it changed.
- **Alternatives considered**: what was rejected, with the case that rejects
  it.
- **Open questions**: what this BEP leaves undecided; each one names its
  issue.
- **Consequences**: what the rule commits the language and the kernel to.
- **Why abandoned**: only in an abandoned BEP; the case or the argument that
  ended it.

The BEPs numbered up to 0061 were written as decision records before
[[ADR-0062]] and keep their sections.
