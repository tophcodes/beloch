# VSCode highlighting — TextMate grammar

**Status:** approved
**Date:** 2026-07-03
**Subsystem of:** [VSCode extension foundation](2026-07-03-vscode-extension-foundation-design.md)

## Goal

Fill the foundation's stub grammar (`editors/vscode/syntaxes/beloch.tmLanguage.json`)
with a rich, contextual TextMate grammar for Beloch, mapped onto standard
TextMate scopes so any VSCode theme colors it without a bundled theme. This is
the accepted stopgap per [decision 0004](../../decisions/0004-menhir-then-treesitter.md)
(Tree-sitter comes later); semantic, symbol-aware coloring is the LSP subsystem's
job, not this grammar's.

## Scope

**In:** the TextMate grammar patterns + a grammar test suite.

**Out:** Tree-sitter, semantic tokens, any symbol resolution (which name is
defined where — that requires the LSP). The grammar distinguishes tokens only by
*syntactic position*, never by cross-line/cross-scope meaning.

## Foundation contract refinement

The foundation froze `package.json`. This subsystem refines that: the
`contributes` blocks (grammars, commands, configuration, activationEvents) stay
frozen, but `devDependencies` and `scripts` may be extended **additively** by a
subsystem (each of the three needs its own test dependency; additive edits to
disjoint keys don't collide). This subsystem adds `vscode-tmgrammar-test` as a
devDependency and a `test:grammar` script. The foundation `README.md` ownership
note is updated to state this refinement.

## Token → scope map

Beloch has no numeric literals (coordinates arise from constructions, not
literals), so there is no number scope. `--` is the crease sigil and `--(` a
line-construction opener — **never** a comment; the grammar must scope these as
Beloch entities.

| Token | TextMate scope |
| --- | --- |
| `; …` to end of line | `comment.line.semicolon.beloch` |
| `paper` | `keyword.control.paper.beloch` |
| `square` | `constant.language.shape.beloch` |
| fold/construction verbs `map` `perp` `cross` `through` | `keyword.control.fold.beloch` |
| `flip` | `keyword.control.flip.beloch` |
| modifiers `onto` `and` `toward` `moving` | `keyword.operator.word.beloch` |
| `mountain` (direction) | `keyword.other.direction.beloch` |
| declaration `def` `step` | `storage.type.beloch` |
| `apply` `export` `as` | `keyword.control.import.beloch` |
| `@` (mutating commit-fold prefix) | `keyword.control.fold.commit.beloch` |
| `!` (intentional-shadow marker) | `keyword.operator.shadow.beloch` |
| `=` | `keyword.operator.assignment.beloch` |
| `.point` (regular) | `variable.other.point.beloch` |
| `._temp` (leading underscore) | `variable.other.point.temp.beloch` |
| `--crease` | `variable.other.crease.beloch` |
| `$instance` | `variable.other.instance.beloch` |
| openers/brackets `--(` `.(` `--[` `.[` `( ) { }` | `punctuation.section.*.beloch` |

## Contextual rules (the "rich" distinctions)

All reliably expressible in TextMate regex (no cross-line state):

1. **`@`-commit-fold** — the `@` before a fold verb gets its own scope
   (`keyword.control.fold.commit.beloch`); the verb keeps its fold scope. Signals
   visually "this line actually folds" vs. a bare verb which only marks a crease.
2. **Temp points** — `._name` (leading `_` after the dot) →
   `variable.other.point.temp.beloch`, distinct from ordinary points. Themes may
   dim/italicize.
3. **Definition-site names** (keyword-anchored, cheap, not positional):
   - `def NAME` → NAME as `entity.name.function.beloch`
   - `step NAME` → NAME as `entity.name.section.beloch`
4. **Shadow marker** — `!` following an export name → `keyword.operator.shadow.beloch`.

Explicitly dropped: LHS-vs-RHS binding distinction (definition vs. use of a
`.point`/`--crease`). The visual gain is marginal, the positional regex is the
most fragile part of the grammar, and real definition/use coloring belongs to the
LSP's semantic tokens, which know where a name is actually defined.

## Files

- `editors/vscode/syntaxes/beloch.tmLanguage.json` — the grammar (fills the
  foundation stub's empty `patterns`). The only non-test file this subsystem owns.
- `editors/vscode/test/grammar/*.bel` — inline-assertion test fixtures.
- `editors/vscode/package.json` — additive only: `vscode-tmgrammar-test` devDep +
  `test:grammar` script.
- `editors/vscode/README.md` — update the ownership note with the devDeps/scripts
  refinement.

## Testing

`vscode-tmgrammar-test` (inline-assertion mode, backed by `vscode-textmate` +
`vscode-oniguruma` WASM — bun-compatible). Fixtures assert the scope of each token
directly beneath it:

```
@map .a onto .b
; <- keyword.control.fold.commit.beloch
;    ^^^ keyword.control.fold.beloch
;         ^^ variable.other.point.beloch
```

Fixtures cover, at minimum: a `;` comment; `@`-commit vs. bare `map`; `._temp` vs.
regular point; `--(` NOT scoped as a comment; `--crease`, `$instance`; `def NAME`
and `step NAME` definition names; the `!` shadow marker in an `export`; and a full
real program from `examples/` (e.g. `cube-root.bel`) tokenizing without any
`Compl`/fallback scope leaking. TDD: write the assertion (red) → add the grammar
pattern (green).

## Related

- [decision 0004](../../decisions/0004-menhir-then-treesitter.md) — TextMate stopgap
  before Tree-sitter.
- Semantic, symbol-aware coloring is deferred to the LSP subsystem (its own spec).
