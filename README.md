Beloch, named after [Margherita Piazzola Beloch][mpb], is a declarative language for origami, built on the [Huzita-Justin axioms][huzita-justin], that compiles source models into folded states, crease patterns, and step-by-step folding diagrams.

[mpb]: https://en.wikipedia.org/wiki/Margherita_Piazzola_Beloch
[huzita-justin]: https://langorigami.com/article/huzita-justin-axioms/

> **Status:** early restart. Scaffolding and design records are in place; the
> minimal evaluator core (v0.0) is not implemented yet. See
> [`decisions/`](decisions/) for the architecture and [`notes/`](notes/) for the
> design journal.

## Development

The evaluator core is OCaml; tooling lives at the edges in TypeScript (see
[decision 0001](decisions/0001-ocaml-core-typescript-edge.md)). A Nix flake
provides the OCaml toolchain (dune, menhir, sedlex, ocaml-lsp, …):

```sh
direnv allow          # or: nix develop
dune build
dune exec beloch -- --version
```

## Layout

```
lib/          evaluator core (OCaml library)
bin/          the `beloch` CLI
spec/         human-readable language specification (grows per increment)
decisions/    architecture decision records (ADRs)
notes/        dated design journal
examples/     .bel programs, tagged works / aspirational / anti
paper/        the eventual write-up (arXiv / JOSS / OSME)
antipatterns.md  dead ends and rejected approaches
bibliography.md  annotated sources
```
