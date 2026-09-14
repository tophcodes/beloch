# Assertions become statements (design, 2026-09-14)

`; assert faces = 6` and `; expect error "..."` move out of the comment track
and into the language as real statements. This note records the decisions and
what they rule out. The spec follows once the item-syntax slice has fixed the
statement grammar.

## Why the comment form existed, and why it stops

The 2026-07-14 design gave one reason for putting assertions in comments: the
lexer already skips them, so the runner reads the raw file text and never has
to touch the parser. That was a v1 shortcut. Its cost is
`packages/core/tests/bel_assert.ml`: 429 lines carrying a second tokenizer and
a second parser for a second language that happens to live inside `;`-comments.

The motive behind the format survives the move, and is the reason the answer
is not "put the expectations in the OCaml tests": a test file states its own
expected outcome. Nobody should have to read a `.bel` file here and a test
registry somewhere else to learn that this program is supposed to raise, or
that those two points are supposed to coincide.

## What was decided

**Assertions are part of the language.** A Beloch program can state what it
claims about the state it builds. This is a commitment about what Beloch is,
not a refactor of the test harness; the harness shrinking is a consequence.

**`assert` keeps its own grammar underneath.** The observation vocabulary
(`faces`, `steps`, the `paper`/`table` space qualifier, `incident`,
`is mountain`) means something under `assert` and nowhere else. The rejected
alternative was to make it general: `faces` as an expression anywhere,
`paper` and `table` as spaces any point expression can be read in, incidence
as a predicate of the language. That would give Beloch a second half, one that
talks about results rather than constructing them, and `spec/MODEL.md` would
have to carry it. The gain did not justify that.

Operands are the exception and get richer for free: as a statement, `assert`
inherits `point_operand` and `line_operand` from the grammar, so
`assert .[--a --b] = .c` becomes expressible where the hand-rolled tokenizer
accepted a bare name only.

**An assertion holds where it stands.** Today every `; assert` line is checked
against the final state regardless of where it sits, so a file cannot say
anything about an intermediate state. As statements they are checked in
sequence, which makes `assert faces = 2` after the first fold and again after
the second two different claims. This changes the meaning of the existing
corpus files, in the direction the format was reaching for.

**`expect error "substr"` applies to the statement that follows it.** The
program names which statement fails and with which diagnosis:

```
expect error "#["
fold (map .c onto .a) (moving .c) (up to .p)
```

After an error there is no defined state to continue from, so a program holds
at most one `expect error` and nothing may follow the statement it guards.

Two alternatives were rejected. As a declaration at the top of the file it
would only say "this program fails" and lose which statement fails, which is
information the current format already fails to carry. Left as a comment it
would keep the extractor alive for one construct, defeating the point.

The positional form covers every error the corpus pins: all 25 `expect error`
cases are evaluation errors, geometric or semantic. None is a parse or lex
error, so none of them needs an expectation that survives a program the parser
rejects. A parse-level expectation would need a different mechanism, and
nothing asks for one yet.

## Left open for the spec

- What `faces` and `steps` mean at a point in the middle of a program, where
  "the final `foldedForm` frame" no longer names anything.
- What remains of `bel_assert.ml` once extraction and tokenizing are gone, and
  whether the checking belongs in the evaluator (an assertion is evaluated) or
  stays beside the runners.
- Whether `spec/MODEL.md` §5 has to name a judgment alongside its operations,
  given that every operation there produces state and an assertion does not.
- The migration: 89 corpus files, the tagged blocks in `spec/BELOCH.md`, the
  tree-sitter grammar, the highlighting queries and the three runners.

## Sequencing

This lands after the item-syntax slice, not beside it. An `assert` statement
has to fit the statement grammar that slice is still moving, and its tasks 11
and 14 rewrite `SPECIFICATION.md` and `BELOCH.md`, the same documents an
assertion statement has to appear in.
