# Grammar blocks (design)

## Status

Draft for review (2026-09-13, with Toph). Decided before this document and
taken as given here:

- Grammar fragments carry a language tag of their own and are parsed at build
  time. The notation stays what `spec/BELOCH.md` already writes; no
  tree-sitter grammar is written for it.
- Every rule gets an id, every nonterminal on a right-hand side links to its
  rule, and a nonterminal that no rule of the page defines fails the build.
- The collected grammar under `## Grammar` is generated from the fragments of
  the page. The hand-written copy is deleted.
- The parsed grammar is written to `_build/` and one cross-check ships with
  it: the quoted keywords of the documented grammar against the keyword table
  of `packages/core/lib/lexer.ml`.

## Motivation

`spec/BELOCH.md` states its grammar twice: once per section as a fragment, and
once whole under `## Grammar`. The second copy is maintained by hand, so a
section that gains a rule and a collected grammar that does not are a silent
inconsistency. The fragments are untagged code blocks, so a reference to
`flap_operand` in `fold_item` is plain text: the reader scrolls, and a rule
referenced but never stated reads the same as one stated three sections down.

ADR 0021 makes this document the language reference and moves the grammar
appendix here whole, section by section. During that migration the two halves
of the grammar live in two files, which is exactly when a reference to a rule
that is nowhere costs the most.

`spec/MODEL.md` already has the machinery for this shape of problem: typed
blocks, generated ids, generated cross-reference lines, one register in
`_build/` that a second renderer and the tests read
(`packages/www/src/lib/remark-model-blocks.ts`, `scripts/model-blocks.lua`,
`scripts/api-register.ts`). Grammar fragments get the same treatment.

## The notation

The notation is what the fragments and `SPECIFICATION.md` Appendix A write
today, stated as a lexer over one line at a time:

| form | class | meaning |
|---|---|---|
| `name` at column 0 followed by `:=` | `gr-rule` | defines a rule; the anchor |
| `name` on a right-hand side | `gr-nonterminal` | a reference; a link |
| `"paper"`, `"#["` | `gr-keyword` | a keyword |
| `CREASE_NAME` | `gr-token` | a token; upper case, digits, `_` |
| `:=` `\|` `[` `]` `(` `)` `*` `+` | `gr-operator` | structure |
| `;` to end of line | `gr-comment` | a comment |
| everything else | `gr-plain` | whitespace |

A rule starts at column 0 and runs to the next line that starts at column 0 or
to the end of the fragment. An indented line continues the current rule,
whether or not it opens with `|`. Appendix A wraps long alternatives without a
leading `|`, and both forms have to parse for the migration to be a move
rather than a rewrite.

A quoted string whose content matches `^[a-z]+$` is a *word keyword* and enters
the cross-check below. A quoted string with any other content (`"#["`, `"--["`)
is a symbol and is recorded apart from the word keywords.

Any other character is an error: the notation admits no free prose outside a
`;` comment.

## Blocks

Three fenced tags, all read the same way by remark (`node.lang`) and by pandoc
(the code block's first class):

````
```grammar
fold_item := axis
           | "moving" flap_operand
```
````

A fragment. Its rules are defined here, anchored here, and collected from here.

````
```grammar-external
point_operand   ; SPECIFICATION.md Appendix A
prose_axiom     ; SPECIFICATION.md §4.1 to §4.5c
```
````

The names a rule of this page may refer to while their definition still lives
in `SPECIFICATION.md`. One name per line, its home written as a `;` comment.
Each entry gets the same id a rule would get (`#rule-point_operand`) and
renders under `## Grammar` as *Defined elsewhere*, so a reference to an
external name is a live link that lands on a line naming the file. No
reference to a documented name is ever a dead link, before or after migration.

The declaration cannot rot, because three states fail the build: a name that
is both declared external and defined by a fragment, a declared name that no
rule refers to, and a reference to a name that is neither. A section that
migrates deletes its names from the block in the same edit; when the last name
goes, the block goes with it.

````
```grammar-planned
align   ; two-fold constructions are not evaluated yet
```
````

The word keywords the documented grammar states and `packages/core` does not
lex yet. It carries reader value on its own (the page says which keywords the
kernel accepts today) and it is the only allowance the cross-check honours.
An entry the lexer already has fails the check, so this block drains as the
kernel catches up. Today it holds one name, `align`.

````
```grammar-collected
```
````

The marker under `## Grammar`, written empty. The plugin replaces it with
every rule of the page in order of definition. Content inside it is an error:
the hand-written copy cannot survive by accident.

## Ids, links and backlinks

- The defining occurrence of `fold_item` carries `id="rule-fold_item"`. The id
  is the rule name verbatim, underscores included, so a reader can guess an
  anchor from a rule.
- Every nonterminal on a right-hand side renders as
  `<a class="gr-nonterminal" href="#rule-axis">axis</a>`. A reference to an
  external name gets `class="gr-nonterminal gr-external"` and points at the
  entry in the *Defined elsewhere* block.
- Under each rule that other rules refer to, a generated line
  `<p class="gr-links">Used by: <a …>item</a>, <a …>write_stmt</a></p>`, in
  the wording and the styling of the model blocks' links line. A rule nothing
  refers to gets no line.
- The forward direction gets no line. The uses are already links in the rule
  text, which is the reasoning `remark-model-blocks.ts` gives for hiding
  `uses` on a statement.
- Ids and backlink lines live at the definition site. The collected grammar
  renders the same rules with the rule name as a link back to its fragment,
  no ids and no backlink lines, so the page has one anchor per rule.

Keywords do not link to a section yet. The sections that would introduce them
arrive with the per-write sections ADR 0021 plans, and a keyword-to-section
table written before those sections exist is a second index maintained by
hand. The register records the rules each keyword occurs in, so the later
change is a table and an anchor per keyword.

## Rendering

`packages/www/src/lib/grammar-notation.ts` holds the parser and the HTML
renderer and depends on nothing from remark, so the script can import it:

- `parseDocument(source: string, path: string): GrammarDocument` lexes every
  `grammar`, `grammar-external` and `grammar-planned` block of one markdown
  source, derives `usedBy`, checks the four conditions under **Errors**, and
  throws `GrammarError` on the first failure.
- `renderRule(rule, doc, options): string` and
  `renderExternal(doc): string` produce the HTML.

`packages/www/src/lib/remark-grammar.ts` is the plugin. It visits `code` nodes,
mutates the matching ones in place to `type: "html"` the way
`remark-bel.ts` does (which keeps `position` intact, so
`remark-model-blocks.ts`'s range splicing still lines up), and expands the
`grammar-collected` marker into one `html` node. It runs beside `remarkBel` in
`astro.config.mjs`: `[remarkBel, remarkGrammar, remarkModelBlocks, remarkMath]`.
A raw `html` node is invisible to Expressive Code, so the emitted
`<pre class="grammar-block"><code>…</code></pre>` survives as written.

The plugin parses rather than reading `_build/grammar.json`: `astro dev` has to
work before any script has run, and the undefined-name error has to fire in
every build.

CSS in `packages/www/src/styles/theme.css`. `.grammar-block` joins the
`.bel-block` rule (same ground, same monospace, same scroll), the token classes
take the variables the `.bel-*` classes take, so a grammar fragment and a
program sample read as one system:

```css
.gr-rule        { color: var(--beloch-keyword); font-weight: 600; }
.gr-nonterminal { color: var(--beloch-line); }
.gr-keyword     { color: var(--beloch-keyword); }
.gr-token       { color: var(--beloch-reference); }
.gr-operator    { color: #7E889A; }
.gr-comment     { color: #7E8C73; font-style: italic; }
```

`.gr-links` joins the existing `.stmt-links, .term-links` selector group.

## The register

`scripts/grammar-register.ts` writes `_build/grammar.json`, exports
`buildGrammarRegister(paths: string[]): GrammarRegister`, and takes `--out`,
like `scripts/api-register.ts`. It scans two documents:

- `spec/BELOCH.md`, the rendered one.
- `spec/SPECIFICATION.md`, whose Appendix A block gets the `grammar` tag in
  the same change. It is parsed for its keywords alone: no ids, no links, no
  collection, and its rules do not satisfy an external declaration.

Parsing both means the documented side of the cross-check is the whole
documented grammar while the migration is in flight, and the union shrinks to
`BELOCH.md` by itself when Appendix A is empty.

```json
{
  "documents": [
    {
      "path": "spec/BELOCH.md",
      "fragments": [
        {
          "line": 46,
          "rules": [
            {
              "name": "program",
              "id": "rule-program",
              "line": 46,
              "uses": [],
              "usedBy": [],
              "keywords": ["paper", "square"],
              "symbols": [],
              "tokens": [],
              "lines": [
                [
                  { "class": "gr-rule", "text": "program" },
                  { "class": "gr-plain", "text": " " },
                  { "class": "gr-operator", "text": ":=" },
                  { "class": "gr-plain", "text": " " },
                  { "class": "gr-keyword", "text": "\"paper\"" },
                  { "class": "gr-plain", "text": " " },
                  { "class": "gr-keyword", "text": "\"square\"" },
                  { "class": "gr-plain", "text": " " },
                  { "class": "gr-nonterminal", "text": "stmt", "ref": "rule-stmt" },
                  { "class": "gr-operator", "text": "*" }
                ]
              ]
            }
          ]
        }
      ],
      "external": [
        { "name": "point_operand", "id": "rule-point_operand", "line": 268,
          "note": "SPECIFICATION.md Appendix A" }
      ],
      "planned": [
        { "keyword": "align", "line": 274,
          "note": "two-fold constructions are not evaluated yet" }
      ]
    }
  ]
}
```

`lines` is the rendering contract both renderers consume: a list of lines, each
a list of spans, a span's `class` used verbatim as a CSS class and as a typst
`raw` language. A nonterminal span carries `ref`. Line breaks are the list
structure, so no renderer splits on `\n`.

`scripts/build-api-docs.sh` runs `bun scripts/grammar-register.ts` beside
`api-register.ts`, so one command still produces every generated input the
spec documents read.

## The keyword cross-check

`scripts/grammar-register.test.ts` compares two sets of strings.

- **Documented.** The union of `keywords` over every rule of every document in
  the register, minus every `planned` entry. Symbols (`"#["`, `"--["`) are out:
  they are punctuation the lexer spells as its own branches.
- **Kernel.** The string literals of `packages/core/lib/lexer.ml` matching
  `^\s*\|\s*"([a-z]+)"\s*->` at the start of a sedlex branch. The same filter
  drops `"#["`, `"--["` and `".["` on that side.

Three failures, each naming the keyword:

- a documented keyword the lexer does not have,
- a lexed keyword no documented rule states,
- a `planned` keyword the lexer already has.

The test calls `buildGrammarRegister` in process rather than reading
`_build/grammar.json`, the way `scripts/api-register.test.ts` calls `parseMli`,
so it needs no build order. The written file is what the pandoc filter and
later tests read.

The check is a set comparison over keyword spellings. Out of scope: whether a
keyword may appear where the grammar says it may, whether the rules accept the
same language as the Menhir grammar or `packages/grammar`, and whether the
programs in the documents parse.

Against the grammar as written today the sets differ in one name, `align`:
documented for two-fold constructions and absent from the lexer. The
`grammar-planned` block declares it, and the check passes.

## The PDF side

`scripts/grammar-blocks.lua` is a filter of its own beside
`scripts/model-blocks.lua`, added as a second `--lua-filter` in
`scripts/render-model.sh`. The two share no state, and `model-blocks.lua`
stands at 516 lines.

Shared with the web side: the parse, through `_build/grammar.json`.
`scripts/render-model.sh` runs `bun scripts/grammar-register.ts` before the
pandoc loop, so the PDF can never be built from a stale parse. The filter
walks the code blocks of class `grammar` in document order and takes the
fragments of the register's entry for the document in the same order; a count
mismatch means a stale register, and the filter leaves the block verbatim and
warns `_build/grammar.json is stale; run scripts/grammar-register.ts`.

Duplicated by necessity: the rendering. Pandoc's typst writer emits
`pandoc.Code(text, Attr("", {"gr-keyword"}))` as
`#raw(lang:"gr-keyword", "…")`, which preserves internal spacing and carries
the class as a language, and it drops the id of a `Code`. So a fragment
becomes a `pandoc.Div` of class `grammar-block` holding one `pandoc.Para`
whose inlines are one `Code` per span with `pandoc.LineBreak` between lines; a
nonterminal span is wrapped in `pandoc.Link(…, "#rule-axis")`, which the writer
emits as `#link(<rule-axis>)`; a defining name is wrapped in a `pandoc.Span`
carrying the id, which the writer emits as the label `<rule-fold_item>`.

Colour lives in `scripts/typst-compat.typ`, already passed with
`--include-in-header`, as one show rule per class:

```typst
#show raw.where(lang: "gr-keyword"): it => text(fill: rgb("#8A5A2B"))[#it]
```

The colour table is written twice, once in CSS and once in typst. The class
names are the same on both sides, so the two tables are checkable against each
other by eye.

The collected grammar, the *Defined elsewhere* block and the backlink lines
are built from the same register entry, so the PDF and the page carry the same
rules in the same order.

## Errors

Every message names the file and the line. The plugin throws; the register
script exits non-zero with the same text.

| situation | message |
|---|---|
| reference to an unknown name | `` spec/BELOCH.md:171: rule alignment refers to point_operand, which no rule in this document defines; state it here or list it in the grammar-external block `` |
| rule defined twice | `` spec/BELOCH.md:214: rule flap_operand is already defined at line 96 `` |
| defined and declared external | `` spec/BELOCH.md:268: rule axis is defined at line 160 and declared external; remove the external entry `` |
| external name nothing refers to | `` spec/BELOCH.md:269: point_operand is declared external and no rule refers to it; remove the entry `` |
| content in the collected marker | `` spec/BELOCH.md:255: the grammar-collected block is generated; leave it empty `` |
| a line that is neither a rule head nor a continuation | `` spec/BELOCH.md:150: expected `name :=` or an indented continuation, got "fold_item = axis" `` |
| a character the notation has no class for | `` spec/BELOCH.md:150: unexpected character "%" in rule fold_item `` |
| documented keyword the lexer lacks | `` keyword "align" is stated in spec/BELOCH.md:212 and packages/core/lib/lexer.ml does not lex it `` |
| lexed keyword no rule states | `` keyword "rotate" is lexed by packages/core/lib/lexer.ml and no documented rule states it `` |
| stale planned entry | `` keyword "map" is declared planned in spec/BELOCH.md:275 and packages/core/lib/lexer.ml lexes it; remove the entry `` |

## Acceptance

1. **Parse.** `packages/www/src/lib/remark-grammar.test.ts`, against
   `fixtures/grammar-blocks.md`: a fragment renders as
   `<pre class="grammar-block">` whose spans carry `gr-rule`,
   `gr-nonterminal`, `gr-keyword`, `gr-token`, `gr-operator` and `gr-comment`
   on the expected text, with indentation and line breaks as written.
2. **Ids.** The defining occurrence of `fold_item` carries
   `id="rule-fold_item"`; the fixture's collected block carries the rule and
   no second id.
3. **Links.** `axis` on a right-hand side renders as
   `<a class="gr-nonterminal" href="#rule-axis">axis</a>`; an external name
   renders with `gr-external` and points at its entry in the *Defined
   elsewhere* block.
4. **Backlinks.** `axis` carries
   `Used by: <a href="#rule-fold_item">fold_item</a>, …` in document order;
   `program`, which nothing refers to, carries no links line.
5. **Errors.** Six fixtures, one per build error above, each asserted by its
   full message.
6. **Collected grammar.** The `grammar-collected` block expands to every rule
   of the fixture in order of definition, and the rule names of the collected
   copy link back to the fragments.
7. **Register.** `scripts/grammar-register.test.ts`: `spec/BELOCH.md` yields
   14 rules and 8 external names; the shape of one rule's `lines` matches the
   JSON above.
8. **Cross-check.** The same test compares the documented word keywords
   against `packages/core/lib/lexer.ml` and passes with `align` declared
   planned; removing that declaration fails with the message above; an added
   fixture keyword on either side fails naming that keyword.
9. **PDF.** `scripts/grammar-lua.test.ts` runs pandoc with
   `scripts/grammar-blocks.lua` and `--to typst` over the fixture and finds
   `#raw(lang:"gr-keyword", "\"moving\"")`, `#link(<rule-axis>)` and the
   label `<rule-fold_item>`; the test skips with a message where pandoc is
   absent. `nix develop -c scripts/render-model.sh` produces
   `_build/spec/beloch.pdf` whose grammar pages are coloured and whose rule
   references jump.
10. **Document.** `spec/BELOCH.md` states every rule once. The hand-written
    collected grammar is gone, `## Grammar` holds the marker, the *Defined
    elsewhere* and *Not lexed yet* blocks, and the site build fails when a
    fragment refers to a name no rule defines.

## Non-goals

- Grammar equivalence with anything that parses Beloch. The Menhir grammar of
  `packages/core` and the tree-sitter grammar of `packages/grammar` are
  checked against the documented grammar by the keyword comparison and nothing
  else.
- A corpus check over the documents' example programs. It belongs with the
  item-syntax sections, where the examples get their per-write home.
- A tree-sitter grammar, a Language Server or an editor mode for the notation.
- The `+=` extension form that design documents use when they add alternatives
  to an existing rule. The reference states whole rules.
- Cross-document references. `spec/BELOCH.md` is the one document with
  fragments; `SPECIFICATION.md` is read for keywords.
- Keyword-to-section links, deferred above.

## Migration

The parse fails on a grammar that today's `spec/BELOCH.md` writes in two
places, so the document changes in the same slice:

1. Tag the fragments `grammar`, leave the example programs untagged or tag
   them `beloch`. Only `grammar` blocks are parsed.
2. Replace the hand-written collected grammar with the empty
   `grammar-collected` marker. The prose under `## Grammar` stays; the
   sentence that names `SPECIFICATION.md` Appendix A is replaced by the
   `grammar-external` block, which says the same per name.
3. Declare the eight external names: `point_operand`, `line_operand`,
   `prose_axiom`, `bind_stmt`, `def_stmt`, `apply_stmt`, `export_stmt`,
   `item_body`. `item_body` has no rule anywhere; it is the placeholder the
   per-verb `*_item` rules stand under, and it gets either a rule of its own
   (`item_body := fold_item | reverse_item | mark_item | flatten_item`) or an
   external entry saying where it is going. The other seven name their home in
   `SPECIFICATION.md`.
4. Declare `align` planned.
5. Extend the notation paragraph in the introduction with `( … )` for grouping
   and `;` for a comment to end of line, which the fragments already use.
6. Tag Appendix A's block in `spec/SPECIFICATION.md` `grammar`. That file is
   not rendered by either renderer, so the tag changes nothing a reader sees.

`.github/workflows/deploy.yml` gains a `bun test scripts` step after the
"Build API docs and register" step. That step also picks up
`scripts/api-register.test.ts`, which runs nowhere today.

Astro caches rendered content entries. After changing
`packages/www/src/lib/remark-grammar.ts` or `grammar-notation.ts`, delete
`node_modules/.astro` and `.astro/`, or the old HTML is served.

No `.bel` program changes meaning; the kernel is untouched.
