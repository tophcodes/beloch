Beloch, named after [Margherita Piazzola Beloch][mpb], is a declarative language for origami, built on the [Huzita-Justin axioms][huzita-justin], that evaluates source models into folded states and crease patterns.

[mpb]: https://en.wikipedia.org/wiki/Margherita_Piazzola_Beloch
[huzita-justin]: https://langorigami.com/article/huzita-justin-axioms/

A program is a sequence of folds. Each line applies one of the seven axioms to
the points and creases the sheet already carries, or collapses a vertex flat,
and the evaluator works out where the paper ends up. Coordinates stay exact,
so "does this point lie on this line" has an answer rather than a tolerance.
Those seven constructions and three writing verbs are the whole language.

> **Status:** the evaluator implements all seven Huzita-Justin axioms over an
> exact real-algebraic number kernel and emits [FOLD][fold-spec]. The language
> reference is [`spec/BELOCH.md`](spec/BELOCH.md), the mathematics
> [`spec/MODEL.md`](spec/MODEL.md), the architecture
> [`decisions/`](decisions/), the design journal [`notes/`](notes/). Licensed
> MIT ([`LICENSE.md`](LICENSE.md)). Try it at
> **[beloch.toph.so](https://beloch.toph.so)**.

[fold-spec]: https://github.com/edemaine/fold

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22884252.svg)](https://doi.org/10.5281/zenodo.22884252)

## Reading a program

Everything below uses six pieces of notation. The full grammar is in
[`spec/BELOCH.md`](spec/BELOCH.md).

| | |
|---|---|
| `paper square` | the unit square. It pre-binds the corners `.a` `.b` `.c` `.d` counter-clockwise from the origin, and the edges between them as `--ab` `--bc` `--cd` `--da`. |
| `.name` | a point. |
| `--name` | a crease, whose geometric value is an infinite line. |
| `(…)` | a construction: `(through .a .c)` is the line through two points, `(map .a onto .c)` the fold that carries one point onto another, `(map --ab onto --diag)` the one that carries one line onto another. Each is an axiom; the table under [a note on axiom numbering](spec/SPECIFICATION.md#a-note-on-axiom-numbering) maps all seven onto the rival schemes, because Wikipedia's numbering disagrees with this one. |
| `as --name` | binds the crease a statement scores, so later statements can name it. |
| `--l \ .p` | the part of a crease bundle *away from* a point. `--ba \ .a` is the ray of `--ba` that does not run through `.a`. |

Three verbs write: `mark` scores a crease without moving paper, `fold` moves
paper, and `flatten` collapses a vertex flat. `flatten` is the one that does
more than apply an axiom: given the rays that meet at a vertex, it derives the
crease that closes it, which is how a program expresses a fold no axiom
constructs from the points it has named.

Every program emits a [FOLD][fold-spec] file, which renders into the pairs
below. The crease pattern shows the sheet as it is folded: mountains and
valleys are derived from the layer order, and the construction lines that were
only scored stay flat.

## Bases

### Fish base

Two long flaps from opposite corners. Each half of the diagonal is collapsed
with `flatten`, which derives the crease that closes the vertex: the one
crease here that no axiom constructs from the named points.

```
paper square

mark (map .a onto .c) as --diag
mark (through .a .c) as --ray

mark (map --ab onto --diag) as --l1
mark (map --da onto --diag) as --l2
flatten (--l1) (--l2) (--ray) (toward .d)

mark (map --cd onto --diag) as --l3
mark (map --bc onto --diag) as --l4
flatten (--l3) (--l4) (--ray) (toward .d)
```

| crease pattern | folded |
| --- | --- |
| ![fish-base.bel as a crease pattern: the a-c diagonal, four kite creases folded onto it, and the two emergent creases that close the vertices](examples/bases/fish-base-cp.svg) | ![fish-base.bel folded: two narrow flaps from opposite corners](examples/bases/fish-base-folded.svg) |

Both drawings above are the output of the renderer, checked into the
repository and reproduced by:

```sh
beloch render examples/bases/fish-base.bel fish-base-cp.svg --view cp --legend
beloch render examples/bases/fish-base.bel fish-base-folded.svg --view folded --legend
```

### Swivel rabbit ear

A rabbit ear whose hinges sit at a free height on the side edges rather than
at the triangle's angle bisectors. Only three of the four rays at the hinge
vertex are given, and flat-foldability forces the fourth, so the crease that
closes the vertex is not constructible by any Huzita axiom from the named
points. `flatten` solves for it and binds it to `--ear`.

The scaffolding is what locates the hinge height; it is scored and stays flat.

```
paper square

mark (map .a onto .b) as --v      ; x = 1/2: spine, also the symmetry axis
.m = --v * --cd                   ; apex (1/2, 1)

mark (through .a .m) as --_am     ; scaffolding: locates the hinge height
mark (through .b .m) as --_bm
mark (map --ab onto --_am) as --_ba
mark (map --ab onto --_bm) as --_bb
.o = --_ba * --_bb

.lowerp = --_ba * --_bm
mark (perp --bc through .lowerp) as --lowerh

mark (through .a .[--bc --lowerh]) as --ba   ; hinge from a, free height
mark (through .b .[--da --lowerh]) as --bb   ; hinge from b, same height

flatten (--ba \ .a) (--bb \ .b) (--v \ .m) (toward .c) as --ear
```

| crease pattern | folded |
| --- | --- |
| ![swivel-rabbit.bel as a crease pattern: scaffolding lines flat, two hinge valleys, and the single emergent mountain](examples/bases/swivel-rabbit-cp.svg) | ![swivel-rabbit.bel folded: the ear swivelled to one side](examples/bases/swivel-rabbit-folded.svg) |

More programs, from a kite to the bird base, are in [`examples/`](examples/).
Most of them end in `; assert` lines (`assert steps = 2`,
`assert --bd is mountain`), which the test suite checks, so a corpus program
states what it is supposed to produce and fails the build when it stops.

## What exact arithmetic costs

Coordinates are real-algebraic numbers, so a cube root stays a cube root and a
coincidence either holds or does not. That is the reason to use this over a
floating-point tool, and it is paid for in evaluation time. Measured on the
benchmark corpus with `dune exec packages/core/bench/bench_fold.exe`, on one
developer machine:

| program | |
|---|---|
| fish base (√2 throughout) | 0.24 s |
| swivel rabbit ear | 0.13 s |
| rabbit ear | 0.13 s |
| two-ear fish | 0.24 s |
| cube root (axiom 7) | 0.13 s |

These are programs of ten to thirty statements. How the kernel behaves on
chained cubic folds, or on a crease pattern with hundreds of vertices, has not
been measured. The benchmark runs a fixed corpus, listed at the top of
`packages/core/bench/bench_fold.ml`; measuring another program means adding it
there.

## Running a program

```sh
beloch fold   examples/bases/fish-base.bel            # FOLD JSON on stdout
beloch render examples/bases/fish-base.bel out.svg    # SVG, --view cp|folded
beloch render examples/bases/fish-base.bel --open     # render and open it
```

The browser playground at [beloch.toph.so](https://beloch.toph.so) runs the
same evaluator, compiled to JavaScript with js_of_ocaml and backed by a
WebAssembly build of FLINT for the algebraic numbers. It carries one limit: an
operation that forces a value the browser backend cannot canonicalise says so
and asks for the native evaluator, rather than returning a wrong answer.
Rational programs, the axiom-7 cube-root fragment included, round-trip in the
browser.

## Development

The evaluator core is OCaml; tooling lives at the edges in TypeScript (see
[decision 0001](decisions/0001-ocaml-core-typescript-edge.md)). A Nix flake
provides the OCaml toolchain (dune, menhir, sedlex, ocaml-lsp, …), so Nix and
[direnv](https://direnv.net/) are the only prerequisites:

```sh
direnv allow          # or: nix develop
dune build
dune exec beloch -- --help
```

Tests run with `scripts/run-ocaml-tests.sh`, which holds the alcotest suites
against a recorded baseline in `scripts/known-failures.txt`. The suite is not
green: four cases fail on one defect in flatten's tier pre-mask (issue #51),
and the baseline exists so that a new failure anywhere still fails the build
while that one is open. The TypeScript side runs with `bun test` in each
package.

## Layout

```
packages/core/      evaluator core + `beloch` CLI (OCaml)
packages/render-2d/ FOLD→SVG render engine (bun)
packages/www/       landing + docs + Playground site
packages/eval-web/  js_of_ocaml browser eval bundle
packages/grammar/   tree-sitter grammar
packages/vscode/    editor extension
spec/         BELOCH.md the language, MODEL.md the mathematics, KERNEL.md the
              implementation, FOLD.md the output; SPECIFICATION.md holds what
              has not moved into those yet
decisions/    architecture decision records (ADRs)
notes/        dated design journal (+ antipatterns.md dead ends)
examples/     .bel programs, tagged works / aspirational / anti
paper/        the eventual write-up (arXiv / JOSS / OSME) + references.bib
```
