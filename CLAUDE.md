# CLAUDE.md: Beloch

Beloch writes origami folding sequences as programs over the Huzita-Justin
axioms. It evaluates `.bel` source into one FOLD file with the folded state after
every step; crease patterns and YR-style folding diagrams are renderings of it. Architecture decisions live in `docs/decision/` (ADRs); read those
before proposing anything structural. Design journal in `docs/notes/`, dead ends in
`docs/notes/antipatterns.md`. The contracts live in `docs/reference/`: `MODEL.md` what a
program means, `BELOCH.md` the language, `FOLD.md` the output. Beside them,
binding no other implementation: `KERNEL.md` what `packages/core` realizes,
`CLI.md` the `beloch` command. `SPECIFICATION.md` is being dissolved into
`BELOCH.md` and `KERNEL.md` (ADR 0032): add nothing to it, and move a section
you have to touch.

## Where work goes

Per-slice design documents are not kept in the working tree. They were
point-in-time records of how one slice was built, they went stale as the code
moved on, and code comments pointing into them taught readers things that had
stopped being true. What a slice decided belongs in an ADR, what it contracts
in `docs/reference/`, and what it is worth remembering about a dead end in
`docs/notes/antipatterns.md`. The documents themselves stay in the Git history;
`git log --diff-filter=D --stat -- docs/superpowers/specs` finds them.

A skill that writes a spec or a plan to `docs/superpowers/` writes it to the
session scratchpad instead; the path is ignored. Progress and handoffs go in
the pull request description or the GitHub issue.

Issues live on GitHub: `gh issue … -R tophcodes/beloch`. They are tracked on
the project board "Beloch" (`gh project … 3 --owner tophcodes`), whose fields
Status and Topic say where an issue stands and what part of Beloch it belongs
to.

- Before starting on an issue, look it up on the board. If it is closed or its
  Status is Done, stop and ask. Otherwise set its Status to In Progress.
- A new issue starts from a template in `.github/ISSUE_TEMPLATE/`
  (`gh issue create --template build|design|docs`), names the ADR it follows
  from in its first line, and goes on the board with a Topic and one `kind:`
  label.
- A pull request body names its issue with `Closes #n` when the pull request
  finishes it and `Refs #n` when it contributes to it, and the pull request
  carries the issue's `kind:` label. A pull request without an issue carries
  `no-issue` in place of the reference. The check on pull requests enforces
  both; no other word (`For`, `Fixes`) counts.
- A pull request that changes what a renderer draws, or adds or changes a
  model in `examples/`, shows the drawings in its body: each affected figure
  as an image linked at the pull request's head commit
  (`https://raw.githubusercontent.com/tophcodes/beloch/<sha>/<path>`), the
  figure before the change beside it where one existed. A reviewer judges a
  drawing by looking at it.
- Annotation keys such as `@orient` go in backticks in a pull request or
  issue body, and stay out of titles and commit subjects, which render no
  code spans: GitHub links a bare `@word` to the user of that name.
- Commit messages carry no issue references. The pull request links its
  commits to the issue, and a `#n` in a commit adds a line to the issue's
  timeline on every rewritten push.

Every text in the repository is English: code, comments, docs, commit
messages, PR and issue bodies, and drafts of any of these shown in chat.

## Checks and pushes

Inside the devshell (`nix develop`, or direnv):

- `check` builds the kernel and runs its suites, the bun suites of
  `packages/render-2d`, `packages/runtime` and `packages/www`, the type
  check (`tsc`) of `packages/render-2d` and `packages/runtime`, the prose
  lint at level error, and the check that every program states its credits
  (ADR 0051). Run it after the last edit and before every push.
- `check-all` runs `check`, then the API docs and register, the README
  drawings against their programs, the script tests (`bun test scripts`) and
  the site build.

Both run every step even after one has failed, end with a summary of the
failed steps, and exit non-zero if there is one. Only the kernel suites wait
for `dune build`.

CI runs `check` on every pull request, in the job `build-and-test` of
`.github/workflows/build-and-test.yml`, and skips it when the pull request
changes only Markdown that no suite reads. A push to `main` that touches the
site, the kernel, `docs/reference/`, `examples/`, `scripts/` or the flake runs
`check-all` in the deploy job, which deploys the site when it passes; any
other push to `main` runs only the commit subject check.

The kernel suites have known failures, held against
`scripts/known-failures.txt`; anything beyond them fails the check.

Commit subjects are checked when they are pushed. The types and scopes are
those `scripts/check-commit-subjects.sh` prints; a package's scope is its
directory under `packages/` or its npm name without `@beloch/`.

Everything reaches `main` through a pull request, an ADR's acceptance and a
chore included: the ruleset on `main` requires the pull request check, and a
commit that has not passed it is refused.

A pull request of several commits lands as a merge commit, so every commit on
its branch reaches `main` as it stands. A pull request of one commit lands by
moving `main` onto it (`jj bookmark set main -r <change>`, then push); GitHub
marks the pull request merged, and no merge commit repeats its title. A correction to a commit on a branch that is not merged
yet folds into that commit (`jj squash --into <change>`) instead of following
it as a new one; force-pushing that branch afterwards is fine.

## Web pages

Development server: in `packages/www`, `bunx astro dev --host 127.0.0.1 --port <n>`. In
a fresh jj workspace, run `bun scripts/render-figures.ts` from the repository
root first, or the figures are missing.

Before reporting a change to a page as done, load the page with the console
open and exercise the interaction that changed. A 200 from the server says
nothing about the script on the page.

## Sources & citations

Full-text papers/books live in `refs/` (gitignored, because they are
copyrighted). Each file is named by its BibTeX cite key, with both `.pdf` and
an extracted `.txt`/`.md` (e.g. `refs/caruana2007.txt`). Machine-readable
metadata is in `bibliography/references.bib`.

**Citation discipline: look it up, don't guess.**

- When a claim needs a source for full context, **first search `refs/`** (use
  `rg` over the `.txt`/`.md` files, which searches all sources at once) and
  cite by key + locator, e.g. `[caruana2007, §3]` or `[hull2020, p. 142]`.
- If the relevant source **isn't in `refs/`**, say so explicitly and **ask the
  user to drop it in** (`refs/<citekey>.txt` + add to `bibliography/references.bib`).
  Do **not** answer origami-math/PL claims from memory. Memory has already
  produced a wrong attribution once, misremembering Caruana and Pace.
- New source → add a `bibliography/references.bib` entry
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

In `docs/` and memos, formulas are LaTeX math (`$...$` inline,
`$$...$$` display); GitHub, Forgejo and the VS Code preview render KaTeX.
Symbol names (`AL8`), code identifiers and paths go in backticks, never bare.
Chat gets words instead of LaTeX, since the terminal does not render it.
