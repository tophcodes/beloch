# Changelog

Each release of Beloch gets one section here. The GitHub release of a tag
carries the same text: the release workflow copies the section when the tag
is pushed.

## [Unreleased]

## [0.4.0] - 2026-09-25

The traditional crane folds flat end to end, and the site moved to
belochlang.org.

**The language.** A meet, `--x * --y` or `.[--x --y …]`, is the one paper
point its operands share when both are read as sets of points (ADR 0027).
Every meet 0.3.0 accepted keeps its point. Operands that lie on more than one
line, such as a crease bent by a fold or a paper edge, now meet wherever they
share exactly one point, and narrowing with `&` is optional there. A meet that
fails says which of three things went wrong: no common point, several (listed
in paper coordinates), or a shared stretch.

**Errors.** An error carries its hint apart from its message (ADR 0028). The
command line prints the hint as a help line under the caret; the playground
shows it as a quieter row below the underlined word. A kernel precondition
failure is reported against the statement that caused it.

**The output.** The FOLD file carries more provenance. `beloch:statements`
lists every top-level statement with the axis it moves, `beloch:edges` points
into that list by index, and the new `beloch:references` records every place
the program mentions a crease by name. Named points and lines say which
statement bound them. `spec/FOLD.md` has the fields.

**Speed.** The number kernel admits field generators up to degree 4, searches
for field embeddings on a precision ladder and caches them per generator pair,
and a folded state derives its face polygons once. The crane through step 16
took 373 s natively before this release and takes 1.4 s now; the FOLD output
is unchanged at 9 decimals.

**What runs.** `examples/crane.bel` follows steps 2 to 17 of Ida's crane
program (Tetsuo Ida, *An Introduction to Computational Origami*, Fig. 7.19) in
sixteen statements; the bird bases locate
their center and side corners as meets. The playground, the cards in the
documentation and the tour of the model share one runtime (ADR 0024): a
clicked crease lights the statement that made it, a crease the program never
named carries its source line, and a coincidence asks which line the reader
meant.

**What does not.** Flat folded states only, no 3D and no thickness.
Step-by-step folding diagrams are a goal and are not implemented. `check` and
`lsp` are stubs. Annotations (ADR 0029) and the flat statement log (ADR
0030) are decided and not implemented; both change the FOLD output again.


## [0.3.0] - 2026-09-22

First tagged release, cut to be cited: this is the version a paper or a
dataset can point at.

**The language.** All seven Huzita-Justin axioms as primitive operations,
evaluated over an exact real-algebraic number kernel, so a constructed
coincidence either holds or does not. No tolerance, no epsilon. `mark` scores a
crease, `fold` moves paper, `flatten` derives the crease that closes a vertex
when no axiom constructs it, and `reverse` places a flap on the other side of
the stack.

**The output.** Every program emits FOLD, which the existing tooling in the
origami community reads. The renderer turns that into crease patterns and
folded states as SVG, in color or in Yoshizawa-Randlett line style for print.

**What runs.** The bird base, the fish base, the preliminary base and a swivel
rabbit ear compile end to end; the corpus is in `examples/`. The site at
beloch.toph.so carries a playground that evaluates in the browser.

**What does not.** Flat folded states only, no 3D and no thickness. Step-by-step
folding diagrams are a goal and are not implemented. `check` and `lsp` are
stubs. The language specification is at v0.27-dev and still moves.

The architecture decisions behind all of this are in `decisions/`, the language
specification in `spec/SPECIFICATION.md`.


[0.4.0]: https://github.com/tophcodes/beloch/releases/tag/v0.4.0
[0.3.0]: https://github.com/tophcodes/beloch/releases/tag/v0.3.0
