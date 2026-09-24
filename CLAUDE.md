# CLAUDE.md: Beloch

Beloch is a declarative language for origami, built on the Huzita-Justin axioms,
that evaluates `.bel` source into folded states, crease patterns, and YR-style
folding diagrams. Architecture decisions live in `decisions/` (ADRs); read those
before proposing anything structural. Design journal in `notes/`, dead ends in
`notes/antipatterns.md`. The contracts live in `spec/`: `MODEL.md` what a
program means, `KERNEL.md` what `packages/core` realizes, `BELOCH.md` the
language, `FOLD.md` the output. `SPECIFICATION.md` is being dissolved into
`BELOCH.md` and `KERNEL.md` (ADR 0021): add nothing to it, and move a section
you have to touch.

## Where work goes

Per-slice design documents are not kept in the working tree. They were
point-in-time records of how one slice was built, they went stale as the code
moved on, and code comments pointing into them taught readers things that had
stopped being true. What a slice decided belongs in an ADR, what it contracts
in `spec/`, and what it is worth remembering about a dead end in
`notes/antipatterns.md`. The documents themselves stay in the Git history;
`git log --diff-filter=D --stat -- docs/superpowers/specs` finds them.

A skill that writes a spec or a plan to `docs/superpowers/` writes it to the
session scratchpad instead; the path is ignored. Progress and handoffs go in
the pull request description or the GitHub issue.

Issues live on GitHub: `gh issue … -R tophcodes/beloch`.

Every text in the repository is English: code, comments, docs, commit
messages, PR and issue bodies, and drafts of any of these shown in chat.

## Checks and pushes

Inside the devshell (`nix develop`, or direnv):

- `check` runs every test suite. Run it after the last edit and before every
  push.
- `check-all` adds the API docs, the script tests and the site build. It is
  what CI runs, and a push to `main` deploys the site.

The kernel suites have known failures, held against
`scripts/known-failures.txt`; anything beyond them fails the check.

Commit subjects are checked when they are pushed. The types and scopes are
those `scripts/check-commit-subjects.sh` prints; a package's scope is its
directory under `packages/` or its npm name without `@beloch/`.

## Web pages

Dev server: in `packages/www`, `bunx astro dev --host 127.0.0.1 --port <n>`. In
a fresh jj workspace, run `bun scripts/render-figures.ts` from the repository
root first, or the figures are missing.

Before reporting a change to a page as done, load the page with the console
open and exercise the interaction that changed. A 200 from the server says
nothing about the script on the page.

## Sources & citations

Full-text papers/books live in `refs/` (gitignored, because they are
copyrighted). Each file is named by its BibTeX cite key, with both `.pdf` and
an extracted `.txt`/`.md` (e.g. `refs/caruana2007.txt`). Machine-readable
metadata is in `paper/references.bib`.

**Citation discipline: look it up, don't guess.**

- When a claim needs a source for full context, **first search `refs/`** (use
  `rg` over the `.txt`/`.md` files, which searches all sources at once) and
  cite by key + locator, e.g. `[caruana2007, §3]` or `[hull2020, p. 142]`.
- If the relevant source **isn't in `refs/`**, say so explicitly and **ask the
  user to drop it in** (`refs/<citekey>.txt` + add to `paper/references.bib`).
  Do **not** answer origami-math/PL claims from memory. Memory has already
  produced a wrong attribution once, misremembering Caruana and Pace.
- New source → add a `paper/references.bib` entry
  in the same change.

A 5-second `rg` to ground a sentence is always worth it, and a missing source
is worth one sentence to the user where a confident guess would go.

## Communication

Caveman mode is off in this project. The mathematics has to be explained until
Toph can defend it ("checked" means understood): full sentences,
defined terms, intuition before formalism.

The same holds for the code. Explain an identifier, a key binding or an
internal term the first time it appears in chat. End a turn with a numbered
list of what needs Toph's decision or action, or say that nothing does.

## Math notation

In `notes/`, `docs/` and memos, formulas are LaTeX math (`$...$` inline,
`$$...$$` display); GitHub, Forgejo and the VS Code preview render KaTeX.
Symbol names (`AL8`), code identifiers and paths go in backticks, never bare.
Chat gets words instead of LaTeX, since the terminal does not render it.
