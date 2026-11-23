# Spec Delta

## Purpose

How Beloch is built and how the project works: the implementation languages and the number kernel, the module boundaries of the kernel, the FOLD as the one data layer, the readers, the documents and the checks the repository runs.

## ADDED Requirements

### Requirement: The OpenSpec specification binds every implementation
The requirements under `openspec/specs/` SHALL be the binding specification of Beloch. Every implementation of the language SHALL satisfy them, and a rule that no requirement states SHALL bind no implementation. Where a page under `docs/reference/` and a requirement disagree, the requirement SHALL hold and the page SHALL be corrected. Introduced by the change adopt-openspec; its design gives the reason under ADR-0032.

#### Scenario: A page contradicts a requirement
- **WHEN** a sentence of `MODEL.md` states a rule that a requirement under `openspec/specs/` contradicts
- **THEN** the requirement holds
- **AND** a change corrects the page

#### Scenario: Behavior that no requirement states
- **WHEN** the OCaml kernel does something that no requirement states
- **THEN** a second implementation that does it differently still satisfies the specification

### Requirement: The kernel and command pages describe one implementation
`KERNEL.md`, `CLI.md` and `CLI-STAGES.md` SHALL describe the reference implementation, the kernel in `packages/core` and the `beloch` command, and SHALL bind no other implementation. They MAY name modules, functions and data structures. A statement in them that contradicts a requirement SHALL count as a bug in the implementation or a gap in the specification. Introduced by the change adopt-openspec; its design gives the reason under ADR-0032.

#### Scenario: A ceiling of the kernel
- **WHEN** `KERNEL.md` states a ceiling of the OCaml kernel
- **THEN** an implementation without that ceiling still satisfies the specification

#### Scenario: The site keeps the two groups apart
- **WHEN** a reader opens the reference on the site
- **THEN** the kernel and command pages stand in the group "Reference implementation"
- **AND** the model, language and output pages stand in a group of their own

### Requirement: The reference pages divide by role
The pages under `docs/reference/` SHALL divide by role: `MODEL.md` states the meaning, the `BELOCH*.md` pages the language, `FOLD.md` the output format. The language pages SHALL divide by sort and by write, with errors and grammar on pages of their own, never by layer into vocabulary, syntax and semantics. A change SHALL edit the page whose role it touches and add no page per increment. Introduced by the change adopt-openspec; its design gives the reason under ADR-0032.

#### Scenario: A new write statement
- **WHEN** a change adds a write statement to the language
- **THEN** it edits `BELOCH-WRITES.md`, and `MODEL.md` where the meaning changes
- **AND** it adds no page of its own for the statement

### Requirement: The grammar of the language stands on one page
`BELOCH-GRAMMAR.md` SHALL hold every grammar block of the language. The other language pages SHALL state meaning, resolution, errors and examples in prose and code, carry no grammar block, and name a rule in backticks where they need it. The grammar page SHALL group its rules by the page that states their meaning and link to that page. Introduced by the change adopt-openspec; its design gives the reason under ADR-0045.

#### Scenario: Only the grammar page carries grammar blocks
- **WHEN** the check of the repository looks for grammar blocks
- **THEN** ``! rg -l "^\`\`\`grammar" docs/reference --glob "BELOCH*.md" --glob "!BELOCH-GRAMMAR.md"`` exits 0

#### Scenario: A page names a rule
- **WHEN** `BELOCH-WRITES.md` describes the syntax of `fold`
- **THEN** it names the grammar rule in backticks and carries no fragment of it

### Requirement: Every page under docs/ is one of four kinds
Every page under `docs/` SHALL be a guide, a manual, a reference or an explanation page, and SHALL stand in the directory of its kind: `docs/guide/`, `docs/manual/`, `docs/reference/` or `docs/explanation/`. `docs/` SHALL hold no other directory. Introduced by the change adopt-openspec; its design gives the reason under ADR-0054.

#### Scenario: The directories under docs/
- **WHEN** the check of the repository lists the directories under `docs/`
- **THEN** `[ -z "$(find docs -mindepth 1 -maxdepth 1 -type d ! -name guide ! -name manual ! -name reference ! -name explanation)" ]` exits 0

### Requirement: A page keeps the form of its kind
A guide page SHALL teach by doing with programs the site build evaluates. A manual page SHALL get one task done with a program or script the build runs. A reference page SHALL state what a thing does, an API reference included. An explanation page SHALL explain a choice or a concept, carry no syntax, and cite the requirements and model statements it rests on without restating them. Introduced by the change adopt-openspec; its design gives the reason under ADR-0054.

#### Scenario: A guide page
- **WHEN** the site build reads `docs/guide/first-folds.md`
- **THEN** it evaluates every program the page carries

#### Scenario: An explanation page after a language change
- **WHEN** a change alters the syntax of a write statement
- **THEN** no explanation page needs an edit, because none carries syntax

### Requirement: The site shows one navigation group per kind with a page
The site SHALL show one navigation group per kind of page, and a group SHALL appear with the first page of its kind. No group SHALL stand empty. Within a kind, an area with a reader of its own, such as the language or the rendering libraries, SHALL be a subgroup. Introduced by the change adopt-openspec; its design gives the reason under ADR-0054.

#### Scenario: No manual page yet
- **WHEN** `docs/` holds no manual page
- **THEN** the site's navigation shows no group for manuals

#### Scenario: The first explanation page
- **WHEN** a change adds the first page under `docs/explanation/`
- **THEN** the site's navigation gains a group for explanations holding that page

### Requirement: The records directory holds only the design journal
`records/` SHALL hold the design journal in `records/notes/`, dated entries of thinking in progress such as a failing example, a spike or a half-formed idea, and its README. It SHALL hold no decision records; the OpenSpec specification and its changes record every decision. A journal entry SHALL be no page of the site. Introduced by the change adopt-openspec; its design gives the reason under ADR-0062.

#### Scenario: The layout of the prose trees
- **WHEN** the check of the repository inspects the layout
- **THEN** `[ -d docs/reference ] && [ -d records/notes ] && [ -d openspec/specs ] && [ ! -e records/adr ] && [ ! -e records/bep ] && [ ! -e docs/decision ] && [ ! -e docs/notes ] && [ ! -e spec ] && [ ! -e decisions ] && [ ! -e notes ]` exits 0

### Requirement: A decision goes through an OpenSpec change
A decision about how Beloch is built or what a program means SHALL be proposed as a change under `openspec/changes/`, whose delta specs state the requirements it adds, modifies or removes, and whose design names each rejected alternative with its reason. A change to a capability other than `architecture` SHALL edit the pages under `docs/reference/` that explain the rule, in the same pull request. Introduced by the change adopt-openspec; its design gives the reason under ADR-0062.

#### Scenario: A change to a language rule
- **WHEN** a pull request changes which layers a fan moves
- **THEN** it carries a change under `openspec/changes/` with a delta to the capability of that rule
- **AND** it edits the reference page that explains the rule

#### Scenario: A change to the architecture
- **WHEN** a pull request moves a boundary between core modules
- **THEN** its change modifies a requirement in `architecture` and edits no page under `docs/reference/` for that reason alone

### Requirement: Work that waits has one place per reason
An idea set aside untried SHALL be an issue with the label `parked`. A question that waits for a decision SHALL be an issue from the template `design`. Thinking in progress SHALL be a dated entry in `records/notes/`. Introduced by the change adopt-openspec; its design gives the reason under ADR-0062.

#### Scenario: An idea set aside
- **WHEN** a contributor sets an idea aside without trying it
- **THEN** it becomes an issue labeled `parked`, and no list in the repository collects it

#### Scenario: An open question
- **WHEN** a question needs a decision before work can go on
- **THEN** it becomes an issue opened with `gh issue create --template design`

### Requirement: A link between documents names an id
A link between documents SHALL name an id, `[[kind/stem]]`, with `#anchor` where it enters the document and `|text` for its label. The kind SHALL be the directory under `docs/`, or `notes` for a journal entry, and the stem the file stem, case-folded. A resolver SHALL turn the id into a link on the site and in the rendered PDFs, and the check SHALL fail on an id that names no document or no anchor. Introduced by the change adopt-openspec; its design gives the reason under ADR-0054.

#### Scenario: Every link resolves
- **WHEN** the check of the repository runs
- **THEN** `bun scripts/id-links.ts --check` exits 0

#### Scenario: A link to a missing anchor
- **WHEN** a page carries `[[reference/model#def-nothing]]` and `MODEL.md` has no anchor `def-nothing`
- **THEN** `bun scripts/id-links.ts --check` names the file and line and exits 1

### Requirement: Documents cite a requirement by capability and name
A document or code comment that cites a rule's reason SHALL name the requirement by its capability and its name, as `openspec/specs/<capability>/spec.md`, "Requirement: <name>", and a code comment MAY shorten this to `(spec <capability>, "<name>")`. No link SHALL name an ADR or a BEP. Introduced by the change adopt-openspec; its design gives the reason under ADR-0062.

#### Scenario: No link names a retired record
- **WHEN** the check of the repository looks for links to records
- **THEN** `! rg -n '\[\[(ADR|BEP)-[0-9]{4}' docs records` exits 0

#### Scenario: A code comment cites a rule
- **WHEN** a comment in the kernel gives the reason for the number representation
- **THEN** it reads `(spec architecture, "A number is rational, a field element or a qqbar value")`

### Requirement: A defined term has a glossary entry of its own
Every term that a definition of `MODEL.md` introduces, listed in its `defines` attribute, SHALL have a glossary entry of its own, a `.term` block whose id is that term, linked to the definition that owns it. Alignment, construction, candidate and selection SHALL each have an entry of its own. Introduced by the change adopt-openspec; its design gives the reason under ADR-0064.

#### Scenario: A new definition
- **WHEN** a definition block in `MODEL.md` lists `term-hinge-angle` in `defines`
- **THEN** `MODEL.md` holds a block `::: {.term #term-hinge-angle …}`

#### Scenario: The four terms of selection
- **WHEN** a reader looks up alignment, construction, candidate or selection in the glossary
- **THEN** each term has its own entry

### Requirement: The evaluator core is written in OCaml
The kernel in `packages/core` SHALL be written in OCaml and built with dune: lexing, parsing, name resolution, geometric evaluation, layer order and the emission of the FOLD file. Introduced by the change adopt-openspec; its design gives the reason under ADR-0001.

#### Scenario: Building the kernel
- **WHEN** a contributor runs `dune build` inside the devshell
- **THEN** it builds the library `beloch` and the executable `beloch` from OCaml sources in `packages/core`

### Requirement: The tooling edge is written in TypeScript
The rendering library, the runtime, the site and the editor extension SHALL be written in TypeScript. They SHALL reach evaluation through the FOLD file the kernel writes, or through the kernel compiled to JavaScript by js_of_ocaml, and SHALL implement no evaluation of their own. Introduced by the change adopt-openspec; its design gives the reason under ADR-0001.

#### Scenario: Evaluating in the browser
- **WHEN** the site evaluates a program in the browser
- **THEN** it runs the kernel compiled by js_of_ocaml from `packages/eval-web`

#### Scenario: Rendering a drawing
- **WHEN** `packages/render-2d` draws a crease pattern
- **THEN** it reads the drawing from a FOLD file

### Requirement: The kernel implements no rule the specification lacks
A change that adds or alters what a program means SHALL state the rule as a requirement in a capability other than `architecture`, in the same pull request as the kernel code that realizes it. The kernel SHALL grow one concept at a time, each with its rule stated. Introduced by the change adopt-openspec; its design gives the reason under ADR-0003.

#### Scenario: A new write statement in the kernel
- **WHEN** a pull request adds a write statement to `packages/core`
- **THEN** the same pull request adds a requirement for it under `openspec/changes/`

### Requirement: The kernel parses with Menhir and sedlex
The kernel SHALL lex a program with sedlex and parse it with a Menhir grammar, `packages/core/lib/parser.mly`, into a typed syntax tree. A syntax error SHALL be reported with the span where the parser stopped. Introduced by the change adopt-openspec; its design gives the reason under ADR-0004.

#### Scenario: A syntax error
- **WHEN** `beloch fold` reads a program that does not parse
- **THEN** it prints `syntax error` with the source line and span to standard error and exits 1

### Requirement: The editor grammar is a hand-written Tree-sitter grammar
Editor highlighting SHALL come from the Tree-sitter grammar in `packages/grammar/grammar.js`, written by hand beside the Menhir grammar and derived from it by no tool. It SHALL accept half-typed input so that highlighting keeps working while a statement is incomplete. Introduced by the change adopt-openspec; its design gives the reason under ADR-0004.

#### Scenario: A new keyword
- **WHEN** a pull request adds a keyword to the lexer
- **THEN** the same pull request adds it to `packages/grammar/grammar.js` by hand

#### Scenario: Half-typed input
- **WHEN** an editor holds a write statement that is missing its operand
- **THEN** the Tree-sitter grammar still classifies its tokens for highlighting

### Requirement: A program is a file with the extension .bel
A Beloch program SHALL be stored in a file whose name ends in `.bel`, and every tool of the repository that looks for programs SHALL select files by that extension. Introduced by the change adopt-openspec; its design gives the reason under ADR-0005.

#### Scenario: The editor extension
- **WHEN** the editor extension in `packages/vscode` registers the language
- **THEN** it claims the extension `.bel`

#### Scenario: The credits check
- **WHEN** `bash scripts/check-program-credits.sh` collects the programs of the repository
- **THEN** it lists the tracked files ending in `.bel`

### Requirement: Beloch is released under the MIT license
The repository SHALL carry the MIT license in `LICENSE.md`. A library linked into the kernel SHALL carry a license that permits linking from MIT code; FLINT, under the LGPL, is one. Introduced by the change adopt-openspec; its design gives the reason under ADR-0006.

#### Scenario: The license file
- **WHEN** the check of the repository reads the license
- **THEN** `rg -q 'Permission is hereby granted, free of charge' LICENSE.md` exits 0

### Requirement: Beloch is an evaluator
The kernel SHALL evaluate a program into a data artifact, the FOLD file, and produce no executable. It SHALL run in three phases: a front end that lexes, parses and resolves names; geometric evaluation that applies the writes to the folded state; and emission of the FOLD file. Documents SHALL call it the evaluator. Introduced by the change adopt-openspec; its design gives the reason under ADR-0007.

#### Scenario: Folding the crane
- **WHEN** a contributor runs `beloch fold examples/crane.bel`
- **THEN** the command writes one FOLD document to standard output and exits 0

### Requirement: One beloch command carries the subcommands
The reference implementation SHALL ship one command, `beloch`, with subcommands in the style of git and nix. `beloch fold` SHALL evaluate a program and write its FOLD file, `beloch render` SHALL render a visual output, and `beloch --version` SHALL print the version. `beloch check` and `beloch lsp` SHALL stay reserved for a type check and a language server. Introduced by the change adopt-openspec; its design gives the reason under ADR-0007.

#### Scenario: A reserved subcommand
- **WHEN** a user runs `beloch lsp`
- **THEN** the command says that it is not implemented and exits 1

#### Scenario: No argument
- **WHEN** a user runs `beloch` without an argument
- **THEN** it prints its usage and exits 2

#### Scenario: A failing program
- **WHEN** `beloch fold FILE.bel` meets an error
- **THEN** it writes nothing to standard output, prints a diagnostic to standard error and exits 1

### Requirement: The language is total
Beloch SHALL be a standalone language with no loop, no recursion and no input or output, so that every program terminates. A definition SHALL see only the definitions written before it, so that no definition applies itself, directly or through another. A program that needs computation SHALL be written by a host language that emits `.bel` source. Introduced by the change adopt-openspec; its design gives the reason under ADR-0009.

#### Scenario: A definition applies itself
- **WHEN** the body of `def corner(.o) { … }` holds `apply corner(.o)`
- **THEN** evaluation fails with `def corner is not defined before this body`

### Requirement: The kernel computes geometry exactly
The kernel SHALL hold every coordinate and every line coefficient as an exact real algebraic number. It SHALL decide equality, sign, comparison and the position of a point against a line or polygon exactly, with no tolerance. Introduced by the change adopt-openspec; its design gives the reason under ADR-0008.

#### Scenario: Two routes to one point
- **WHEN** two constructions reach the point with x coordinate `√8 / 4` and `√2 / 2`
- **THEN** the kernel finds the two points equal

#### Scenario: A point on a crease
- **WHEN** a point lies on a crease line
- **THEN** the kernel decides that it lies on the line by an exact sign of zero

### Requirement: A float stands only in output or in front of an exact decision
The kernel SHALL turn a number into a float only for the FOLD file, a message or a display value. A float computation MAY stand in front of an exact decision as a filter where it returns the exact answer in every case or leaves the case undecided; an undecided case SHALL go to the exact computation. Introduced by the change adopt-openspec; its design gives the reason under ADR-0012.

#### Scenario: Output coordinates
- **WHEN** the kernel writes an irrational coordinate to the FOLD file
- **THEN** the file carries a JSON decimal number
- **AND** the kernel keeps computing with the exact value

#### Scenario: An undecided overlap filter
- **WHEN** the interval boxes of two faces neither separate nor overlap on every axis
- **THEN** the kernel decides the overlap with exact arithmetic

### Requirement: Rational input stays rational through axioms 1 to 4
The kernel SHALL hold a rational number as an exact rational and compute on it without the irrational machinery. Axioms 1 to 4 over rational points and lines SHALL produce rational results, and an irrational result that turns out rational SHALL collapse to a rational. Introduced by the change adopt-openspec; its design gives the reason under ADR-0012.

#### Scenario: A perpendicular bisector of two corners
- **WHEN** a program folds one corner of the square onto the opposite corner
- **THEN** the crease line's coefficients are rationals and no FLINT value is created

### Requirement: A number is rational, a field element or a qqbar value
The kernel SHALL hold a number in one of three forms: an exact rational, an element of one real extension field given as a rational polynomial in one generator, or a value of FLINT's qqbar. A qqbar value SHALL be irrational. Arithmetic that crosses fields, or needs a composite extension, SHALL convert to qqbar and collapse the result back to a rational or a field element where it can. Introduced by the change adopt-openspec; its design gives the reason under ADR-0013.

#### Scenario: A value across two fields
- **WHEN** the kernel compares the square of the cube root of 2 plus the square root of 2 with the cube root of 2 plus the square root of 2
- **THEN** it answers within 1 second

#### Scenario: A rational result
- **WHEN** an operation on two irrational values yields a rational
- **THEN** the kernel holds the result as a rational

### Requirement: The kernel finds the real roots of a polynomial exactly
The kernel SHALL return the real roots, in ascending order, of a polynomial whose coefficients are its numbers. For degree up to 3 with a nonzero discriminant it SHALL try FLINT's root solver first and fall back to its own elimination when FLINT's limits refuse the field; every root SHALL be verified by exact evaluation before it enters the representation. Introduced by the change adopt-openspec; its design gives the reason under ADR-0013.

#### Scenario: A cubic with three real roots
- **WHEN** an axiom-7 crease solves a cubic with three real roots
- **THEN** the kernel returns three exact roots in ascending order, though no real radical expresses them

### Requirement: A value up to the degree cap is held over one generator
The kernel SHALL hold an irrational value whose degree lies at or below `field_degree_cap` as a field element. A qqbar value within the cap SHALL become the generator of its own field when it first meets another value in an addition or a multiplication. A value above the cap SHALL stay a qqbar value. Introduced by the change adopt-openspec; its design gives the reason under ADR-0081.

#### Scenario: Stacked axiom-7 constructions
- **WHEN** an axiom-7 crease runs through points that an earlier axiom-7 crease placed and yields values of degree 9
- **THEN** the kernel computes with them as field elements

#### Scenario: A value above the cap
- **WHEN** a value's degree exceeds `field_degree_cap`
- **THEN** the kernel keeps it as a qqbar value

### Requirement: The degree cap follows a measurement
`field_degree_cap` SHALL be a constant in the kernel's code, and its comment SHALL state what the last run of the benchmark in `packages/core/bench` found. The cap SHALL move when a run of that benchmark shows a different crossover between field and qqbar arithmetic, or when programs reach degrees the last run did not cover. Introduced by the change adopt-openspec; its design gives the reason under ADR-0081.

#### Scenario: Reading the cap
- **WHEN** a contributor reads `field_degree_cap` in `packages/core/lib/num.ml`
- **THEN** the comment beside it names the benchmark and the degrees and timings it measured

#### Scenario: A program past the measured degrees
- **WHEN** a program reaches a degree above the highest degree the last benchmark run covered
- **THEN** the benchmark runs again before the cap changes

### Requirement: A degree test rules out a shared field before the long lattice searches
When the kernel tries to express a value x over a generator g, it SHALL compute the degree of g + x before the lattice searches at the two highest precisions. If that degree does not divide the degree of g, the kernel SHALL conclude that x lies outside the field of g and stop the search. Introduced by the change adopt-openspec; its design gives the reason under ADR-0081.

#### Scenario: A value outside the field
- **WHEN** the lattice searches at the four lower precisions find no polynomial and the degree of g + x does not divide the degree of g
- **THEN** the kernel reports that x lies outside the field of g without running the searches at precision 4096 and 65536

### Requirement: The core modules form one dependency chain
The core SHALL split into the modules `Ctx`, `Resolve`, `Axiom`, `Flatten_solve`, `Action` and `Eval`, each with an `.mli` that is its contract, in the acyclic dependency order `Ctx`, `Resolve`, then `Axiom` and `Flatten_solve`, then `Action`, then `Eval`. A module SHALL depend only on modules earlier in the chain, and `Action` SHALL not depend on `Flatten_solve`. Introduced by the change adopt-openspec; its design gives the reason under ADR-0018.

#### Scenario: The five modules of the first split have interfaces
- **WHEN** the check of the repository inspects the core
- **THEN** `for m in ctx resolve axiom flatten_solve eval; do [ -f "packages/core/lib/$m.mli" ] || exit 1; done` exits 0

#### Scenario: Action has an interface
- **WHEN** the check of the repository inspects the core
- **THEN** `[ -f "packages/core/lib/action.mli" ]` exits 0

### Requirement: Each core module owns one phase
`Ctx` SHALL own the evaluation context, `Resolve` the turning of names and selectors into geometry and material, `Axiom` the axis lines of the seven axioms, and `Flatten_solve` the flatten solver. `Action` SHALL own the writes that change the folded state, `mark`, `fold` and `reverse`. `Eval` SHALL hold the dispatch, `def`, `apply`, `export` and the output record. Introduced by the change adopt-openspec; its design gives the reason under ADR-0034.

#### Scenario: A binding that changes no state
- **WHEN** a statement binds a free point on a line
- **THEN** `Eval` handles it, because it leaves the folded state untouched

### Requirement: A stateful core function takes the context first
Every stateful function of the core modules SHALL take the context, `(ctx : Ctx.ctx)`, as its first parameter, and none SHALL close over it. A type that crosses a module boundary SHALL be abstract unless a caller reads it. Introduced by the change adopt-openspec; its design gives the reason under ADR-0018.

#### Scenario: A new resolver function
- **WHEN** a change adds a function to `Resolve` that reads the folded state
- **THEN** its signature in `resolve.mli` starts with `Ctx.ctx ->`

### Requirement: eval.ml stays under 900 lines
`packages/core/lib/eval.ml` SHALL stay under 900 lines; a change that would cross the limit SHALL move a phase into a module of its own first. Introduced by the change adopt-openspec; its design gives the reason under ADR-0018.

#### Scenario: The line count of eval.ml
- **WHEN** the check of the repository measures the evaluator
- **THEN** `[ "$(wc -l < packages/core/lib/eval.ml)" -lt 900 ]` exits 0

### Requirement: The core never depends on the research package
The multifold research package SHALL live outside this repository. The core SHALL never depend on it, and SHALL change for the research track only where the change serves the language on its own. The research package MAY consume `beloch` as a library like any other consumer. Introduced by the change adopt-openspec; its design gives the reason under ADR-0020.

#### Scenario: No research code in the repository
- **WHEN** the check of the repository searches the packages
- **THEN** `! rg -qi multifold packages` exits 0

#### Scenario: The development shell
- **WHEN** a contributor enters the devshell
- **THEN** `msolve` is on the `PATH` for the research package, which a contributor develops from this checkout

### Requirement: The kernel holds flat folded states only
The kernel SHALL hold a folded state whose every hinge angle is 0, π or minus π, and `Fold_state.make` SHALL refuse any other angle. A non-flat folded state stays an intended goal; reaching it SHALL change the kernel's types to 3D points, 3D rigid motions per face, and coordinates per pair of face and vertex. Introduced by the change adopt-openspec; its design gives the reason under ADR-0063.

#### Scenario: A hinge at a right angle
- **WHEN** `Fold_state.make` receives a hinge whose angle is one half, in units of π
- **THEN** it returns `Error (Bad_angle i)` for that hinge

### Requirement: Declared credits reach the FOLD file without loss
The emitter SHALL carry the credits a program declares, who wrote it, who designed its model and which sequence it follows, into the FOLD file it writes without loss. Model credits SHALL stay apart from the credit for the evaluator's code, which the MIT notice covers. Introduced by the change adopt-openspec; its design gives the reason under ADR-0019.

#### Scenario: A credited program evaluates to a FOLD file
- **WHEN** a program that states `@author "Ann"` and `@design traditional` evaluates
- **THEN** the FOLD file it writes carries both credits

#### Scenario: A program without credits
- **WHEN** a program declares no credits
- **THEN** the FOLD file it writes carries none

### Requirement: Attribution is a capability and never a license duty
Beloch's code SHALL stay under the MIT license everywhere, with no field-of-use clause and no clause that requires a user to keep or show model credits. Declaring credits SHALL be opt-in for a program. Introduced by the change adopt-openspec; its design gives the reason under ADR-0019.

#### Scenario: A user renders a FOLD file elsewhere
- **WHEN** a user exports a FOLD file and draws it in another viewer without its credits
- **THEN** no license term of Beloch forbids it

#### Scenario: The license file
- **WHEN** a reader opens the license of the repository
- **THEN** it is the MIT license with no added clause

### Requirement: The mark is the output of a Beloch program
The project's mark SHALL be one flat-foldable vertex that the evaluator produces from the program `packages/www/public/brand/mark.bel`. Three marked lines meet at the vertex at (1/3, 2/3), and `flatten` solves the fourth ray, the mark's single mountain fold. Introduced by the change adopt-openspec; its design gives the reason under ADR-0023.

#### Scenario: Evaluating the mark
- **WHEN** `mark.bel` evaluates
- **THEN** the vertex has the sectors 139.40, 71.57, 40.60 and 108.43 degrees
- **AND** it satisfies Kawasaki's theorem, and Maekawa's theorem gives M minus V equal to -2

### Requirement: The mark carries no color and comes in two sizes
The mark SHALL take the ink color of its background and use no color of its own. Above 48 pixels it SHALL draw mountains and valleys in the renderer's crease notation; at 48 pixels and below a simplified variant SHALL draw every crease alike. The favicon SHALL carry an embedded `prefers-color-scheme` rule. Introduced by the change adopt-openspec; its design gives the reason under ADR-0023.

#### Scenario: The favicon on a dark tab
- **WHEN** a browser with a dark color scheme shows the favicon
- **THEN** the favicon draws the simplified variant in a light ink

#### Scenario: A circular crop
- **WHEN** the mark fills an avatar with a circular crop
- **THEN** the mark occupies at most 87 percent of the crop and no corner of the sheet is cut off

### Requirement: A runtime core that consumers compose onto holds the web client's state
A runtime core SHALL hold the web client's state: one evaluated document or nothing; an event fills that slot. Evaluation with a swappable backend, the chooser among entities that share a pixel and the map between source positions and entities SHALL be optional modules that compose onto the core, and the core SHALL import none of them. Introduced by the change adopt-openspec; its design gives the reason under ADR-0024.

#### Scenario: The core imports no module that composes onto it
- **WHEN** the check runs over the runtime core
- **THEN** `! rg -q "from \"@beloch/runtime-" packages/runtime/core/src` exits 0

#### Scenario: A consumer that evaluates nothing
- **WHEN** a document card takes its document from the markup it is embedded in
- **THEN** it composes the core and a renderer and carries no evaluator

### Requirement: The runtime core draws through a renderer the consumer plugs in
The runtime core SHALL name no color, geometry or element and SHALL derive each render command as plain data. The view, the occlusion mode and the colors SHALL be arguments of the drawing request. Pan, zoom and animation progress SHALL belong to the renderer. Introduced by the change adopt-openspec; its design gives the reason under ADR-0024.

#### Scenario: The core does not touch the DOM
- **WHEN** the check runs over the runtime core
- **THEN** `! rg -q "(document|window|navigator)\.|HTMLElement|SVGElement" packages/runtime/core/src` exits 0

#### Scenario: Two drawings of one state
- **WHEN** a document card draws the crease pattern and the folded form of one document
- **THEN** it asks the core twice from a single state, once per view

### Requirement: The editor owns the source text
The editor SHALL own the source text and report its changes to the runtime. Everything derived from that text SHALL belong to the runtime. Introduced by the change adopt-openspec; its design gives the reason under ADR-0024.

#### Scenario: An edit in the playground
- **WHEN** the author types in the playground editor
- **THEN** the editor reports the change, and the runtime derives the document from the new text

### Requirement: An event that changes nothing returns the state it was given
The runtime core SHALL return the identical state object for an event that changes nothing, so that a renderer decides by identity whether anything moved. Introduced by the change adopt-openspec; its design gives the reason under ADR-0024.

#### Scenario: A pointer resting on one crease
- **WHEN** the pointer moves over the same crease and the core receives one hover event per mouse move
- **THEN** each event after the first returns the state it was given, and the renderer does not restart a running animation

### Requirement: Every reader shows an error's hint apart from its message
Every reader of an error SHALL carry its message and its hint as two parts. The command line SHALL print the hint as a `help:` line under the caret line. The browser evaluator's answer SHALL carry the message, the hint and the whole span, start and end. The playground SHALL show the message in the caret row and the hint in the row beneath it. Introduced by the change adopt-openspec; its design gives the reason under ADR-0028.

#### Scenario: The command line reports an error with a hint
- **WHEN** `beloch fold` rejects a program whose error has a hint
- **THEN** standard error shows the message at the caret line and the hint on a `help:` line beneath it

#### Scenario: The browser evaluator answers a failed run
- **WHEN** the browser evaluator runs a program that fails
- **THEN** its answer carries the message, the hint and the start and the end of the span

### Requirement: The examples are complete popular models
The directory `examples/` SHALL hold complete models only, each a popular model with a technique the others lack, judged by its last flat state. A base or a single technique SHALL live as a test case under `packages/core/tests/cases/`. A model by a named designer SHALL enter only once that designer's credit is settled. Introduced by the change adopt-openspec; its design gives the reason under ADR-0049.

#### Scenario: A new base
- **WHEN** a contributor writes a program that folds the bird base and stops there
- **THEN** it goes under `packages/core/tests/cases/` with its assertions, and stays out of `examples/`

### Requirement: An example follows a published sequence and names it
Each program in `examples/` SHALL follow a published folding sequence, a freely available diagram included, and name it in a `@source` annotation. A comment at each statement SHALL name the step it folds. A program SHALL state the sequence in its own words and copy no figure of the diagram. Introduced by the change adopt-openspec; its design gives the reason under ADR-0049.

#### Scenario: The examples name their sequences
- **WHEN** the check runs over the repository
- **THEN** `bash scripts/check-program-credits.sh` exits 0

#### Scenario: A statement of the crane
- **WHEN** a reader looks at a statement of `examples/crane.bel`
- **THEN** a comment beside it names the step of the cited sequence that it folds

### Requirement: A model the kernel cannot fold yet keeps its program
A model whose program the kernel cannot evaluate yet SHALL still get its program in `examples/`, and the failing step SHALL become a kernel issue. The README and the website SHALL show only the models that evaluate. Introduced by the change adopt-openspec; its design gives the reason under ADR-0049.

#### Scenario: An example fails at one step
- **WHEN** an example's program fails at a statement
- **THEN** an open kernel issue names that step
- **AND** the README and the website leave the model out until it evaluates

### Requirement: The website compares an example with earlier languages
Where an earlier origami language wrote the same model as an example, the website SHALL set both programs side by side and report for each the statement count, the number of points and lines it names and the evaluation time. The README SHALL hold no such comparison. Introduced by the change adopt-openspec; its design gives the reason under ADR-0049.

#### Scenario: The flapping bird
- **WHEN** a reader opens the comparison of the flapping bird with Fisher's Origami Language [fisher1994, §4.2]
- **THEN** the page shows both programs beside each other with their statement counts, named points and lines and evaluation times

### Requirement: The FOLD is the only data layer
The FOLD file SHALL be the only data layer between the evaluator and every output. No page file or second file format SHALL sit beside a program. Its frames, `beloch:statements` and `beloch:annotations` SHALL be everything an output reads, with Beloch's fields under the `beloch:` prefix. Introduced by the change adopt-openspec; its design gives the reason under ADR-0065.

#### Scenario: An output needs the step groups
- **WHEN** an output draws a folding diagram with one panel per step group
- **THEN** it reads the groups from `beloch:annotations` and `beloch:statements` of the FOLD file and opens no other file

### Requirement: Each output kind is a TypeScript library over the FOLD
Each output kind SHALL be a TypeScript library that offers primitives that select statements, labels, annotations and frames from an evaluated FOLD, and primitives that draw for its medium. An output SHALL be a function over these primitives. Each library SHALL ship a default function, and the libraries SHALL evaluate nothing. Introduced by the change adopt-openspec; its design gives the reason under ADR-0065.

#### Scenario: A diagram without author code
- **WHEN** an author runs `beloch render crane.bel --view yr`
- **THEN** the default function of the YR library draws the diagram and the author writes no code

#### Scenario: A library in the browser
- **WHEN** the playground draws a FOLD document with an output library
- **THEN** the library takes the evaluated FOLD and runs no evaluator

### Requirement: The repository's check requires every program's credits
In this repository every `.bel` file SHALL state `@author`, and every program in `examples/` SHALL state `@design` and at least one `@source`. A source SHALL cite in the bracket form `@source "[ida2020, Fig. 7.19]"`, and each cite key in its brackets SHALL name an entry of `bibliography/references.bib`. The kernel checks the form and place of credits; a script checks that they are present. Introduced by the change adopt-openspec; its design gives the reason under ADR-0068.

#### Scenario: The repository states its credits
- **WHEN** `check` runs
- **THEN** `bash scripts/check-program-credits.sh` exits 0

#### Scenario: A program without an author
- **WHEN** a `.bel` file in the repository lacks `@author`
- **THEN** `bash scripts/check-program-credits.sh` prints the file with `no @author` and exits 1

#### Scenario: A source cites an unknown key
- **WHEN** an example states `@source "[nobody2020, p. 3]"` and `bibliography/references.bib` has no entry `nobody2020`
- **THEN** `bash scripts/check-program-credits.sh` names the key and exits 1

### Requirement: The kernel stores the layer order as a side per pair of overlapping faces
A state in the kernel SHALL store, for every two faces whose places on the table share a region of positive area, which of the two lies above, and nothing for two faces that lie apart or touch along an edge or at a point. The kernel SHALL store no list of all faces and no operation SHALL read a height of a face. Introduced by the change adopt-openspec; its design gives the reason under ADR-0069.

#### Scenario: Two faces that touch along an edge
- **WHEN** two faces of a state share an edge on the table and no region of positive area
- **THEN** the state has no entry for the pair, and `faceOrders` in the FOLD file has no triple for it

#### Scenario: The square twist
- **WHEN** a test builds the square twist from its pairs: 9 faces, 12 folded hinges and 28 overlapping pairs
- **THEN** the kernel accepts the state, in which the four corner faces lie in a cycle

### Requirement: A stacking given as a list keeps only its overlapping pairs
A caller MAY describe a state by a list of faces from the bottom up. The kernel SHALL keep the side of every overlapping pair of that list and drop the rest, so that two lists that agree on every overlapping pair give one state. A state whose layers lie in a cycle SHALL be built from its pairs. Introduced by the change adopt-openspec; its design gives the reason under ADR-0069.

#### Scenario: Two lists that differ on faces apart
- **WHEN** a caller builds a state from two lists that order two faces lying apart differently and agree on every overlapping pair
- **THEN** the two states compare equal pair by pair

### Requirement: The kernel checks the pairs against the conditions of the model
The kernel SHALL check every layer order against the order condition, no cycle among three faces that share a region of positive area, and against the taco-tortilla and taco-taco conditions of `MODEL.md`. The taco conditions SHALL compare only faces that overlap where they are compared. Introduced by the change adopt-openspec; its design gives the reason under ADR-0069.

#### Scenario: Two folds on one line open to opposite sides
- **WHEN** two folded creases lie on one table line and their pairs of faces open to opposite sides of the line
- **THEN** no condition relates the two pairs and the kernel accepts the state

#### Scenario: Three faces in a cycle over one point
- **WHEN** a caller gives pairs in which three faces over one point of the table lie in a cycle
- **THEN** the kernel rejects the state

### Requirement: A fold derives the pairs of the new state from the old pairs
A fold SHALL compute the layer order of its result from the pairs of the state it reads. Two faces that stay SHALL keep their side, and two faces of one moved block SHALL exchange sides. A plain valley fold SHALL put the moved face above every staying face it lands on, a mountain fold below. A fold that pushes paper between layers SHALL decide the new pairs by the conditions of the model. Introduced by the change adopt-openspec; its design gives the reason under ADR-0069.

#### Scenario: A valley fold onto a staying face
- **WHEN** `fold (map .a onto .c)` lays a block on a face that stays
- **THEN** each face of the moved block lies above that face in the new state
- **AND** two faces of the moved block lie in the opposite order to the one they had

### Requirement: A reviewed type is declared with its full definition in an interface
A type the maintainer reviews SHALL be declared with its full definition in an `.mli` interface, transparent or `private`, and its doc comment SHALL state the condition every value of the type meets. A type SHALL stay abstract only where its representation may change without its callers noticing. An `.mli` absent from the hash list counts as unreviewed. Introduced by the change adopt-openspec; its design gives the reason under ADR-0080.

#### Scenario: A reader of a reviewed interface
- **WHEN** the maintainer opens a reviewed `.mli`
- **THEN** it shows each reviewed type's cases or fields and a doc comment with its condition

### Requirement: The form of a reviewed type excludes wrong shapes
A reviewed variant SHALL have one case for each shape a value may take, and a reviewed record SHALL hold only fields that exist together. A boolean flag or two independent options that admit a combination with no meaning SHALL be replaced by a variant. Introduced by the change adopt-openspec; its design gives the reason under ADR-0080.

#### Scenario: Two options with a meaningless combination
- **WHEN** a reviewed record would hold two options of which only one may be set at a time
- **THEN** the type holds a variant with one case per option instead

### Requirement: The module of a private type establishes its condition
A condition the form cannot carry, such as each piece of a bundle passing through its vertex, SHALL be established by the type's module. The type SHALL be `private`, so only that module builds values; a parse function returns a value or an error. Tests SHALL accept valid input and reject each kind of invalid input. The module SHALL hold only the type and the functions that build and read it. Introduced by the change adopt-openspec; its design gives the reason under ADR-0080.

#### Scenario: Code outside the module builds a value
- **WHEN** code outside the module of a `private` type writes a value of it directly
- **THEN** the compiler refuses to build it

#### Scenario: A parse function with invalid input
- **WHEN** a test hands a parse function a bundle whose piece misses the vertex
- **THEN** the function returns an error

### Requirement: The check holds the maintainer's hash of each reviewed interface
A list in the repository SHALL hold one SHA-256 hash per reviewed `.mli`. On every pull request the CI job `reviewed-interfaces`, apart from `check`, SHALL fail while a listed file no longer matches its hash, until the maintainer writes the new hash. An agent SHALL write the list only after the maintainer approves the call; a hook in the agent settings asks the maintainer. Implementation files carry no hash. Introduced by the change adopt-openspec; its design gives the reason under ADR-0080.

#### Scenario: The reviewed interfaces match their hashes
- **WHEN** the job `reviewed-interfaces` runs on a pull request
- **THEN** `bash scripts/check-reviewed-interfaces.sh` exits 0

#### Scenario: A pull request changes a reviewed interface
- **WHEN** a pull request edits an `.mli` whose hash is on the list
- **THEN** the job `reviewed-interfaces` fails and names the file, while `check` still passes

#### Scenario: An agent writes the list
- **WHEN** an agent runs a command that writes the hash list
- **THEN** the hook asks the maintainer before the command runs

