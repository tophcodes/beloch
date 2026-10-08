---
id: "0045"
title: "The grammar of the language stands on one page"
date: 2026-10-01
status: accepted
issue: tophcodes/beloch#65
checks:
  - desc: Only the grammar page of the language carries grammar blocks
    run: '! rg -l "^\`\`\`grammar" docs/reference --glob "BELOCH*.md" --glob "!BELOCH-GRAMMAR.md"'
---

# 0045: The grammar of the language stands on one page

This record replaces one sentence of [[decision/0032]], the one that has each
construct keep its syntax together with its resolution, its errors and its
example. The rest of [[decision/0032]] stands.

## Context

[[decision/0032]] lets the language document span several pages, divided by sort
and by write, and gives the collected grammar a page of its own. It also
has each construct keep its syntax beside its resolution, errors and
example, so every page stated its grammar in fragments and the grammar page
collected them.

Split over five pages, that meant a rule on one page referring to a rule on
another. The site's renderer and the grammar register had to read every
page to resolve a reference, and the grammar page repeated every rule a
second time as a generated copy.

## Decision

**The grammar of the language stands on the grammar page, and only there.**
The other pages of the language state meaning, resolution, errors and
examples in prose and code, and carry no grammar fragment. The grammar page
groups its rules by the page that states what they mean and links to it.

A reader who wants the syntax reads one page from top to bottom; a reader
who wants the meaning of a construct reads its page and follows the link to
the grammar when the syntax matters.

## Alternatives considered

- **Keep the fragments on their pages and collect them on the grammar
  page**, as [[decision/0032]] has it. Rejected: every rule stands twice on the
  site, and a reference across pages needs a resolver that reads every
  page of the language.

## Consequences

- The grammar register reads the grammar page alone, and the keyword
  cross-check against the lexer is held to it.
- The generated copy of the grammar goes: there is nothing left to collect.
- A page that describes a construct names its rules in backticks where it
  needs them; the link to their definition is on the grammar page.
