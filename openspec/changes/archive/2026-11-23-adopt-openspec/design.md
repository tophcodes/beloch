## Context

The specification starts with this change. Each requirement comes from one
or more ADRs or BEPs that were in force on `main`; a superseded or abandoned
record contributed nothing, except where a record in force depended on it.

## Decisions

- **Distill, keep the reason here.** A requirement states the rule with
  scenarios; the argument behind it is one or two lines below, under the id
  of the record it came from, because the records leave the tree.
- **One `architecture` capability for ADRs, topic capabilities for BEPs.**
  Every `architecture` requirement names this change, so its reason is found
  below. Rejected: one capability per record, which would keep the record
  boundaries the specification replaces.
- **A rule stated where it holds now.** Where a later record amended an
  earlier one, the requirement states the amended rule and maps both records
  to it.
- **Record id links are retired.** Pointers name the capability and the
  requirement. Rejected: a redirect from each record id, which would keep
  the id scheme alive beside the specification.

## Reason per record
### ADR-0001: OCaml for the evaluator core, TypeScript for the tooling edge
The evaluator is tree-shaped data under many passes, which algebraic data types and exhaustive matching serve best; Rust would have stacked learning a language on top of designing one and solving the layer problem.
Rendering, editors and the site sit where the JavaScript ecosystem is, and reach the kernel through its FOLD file or its js_of_ocaml build.

### ADR-0003: Restart from a minimal formal core
The 2018 design grew features first and stalled when the layer problem made them inconsistent; a core whose every rule is stated before it is built cannot reach that state.

### ADR-0004: Menhir for the compiler parser, Tree-sitter for editors
A compiler needs precise diagnostics and an editor needs error-tolerant incremental parsing, two different jobs; grammars derived from one another by a tool come out poor, and the surface syntax changes little, so both are kept by hand.

### ADR-0005: Name: Beloch
The language is named after Margherita Piazzolla Beloch, whose fold is axiom 7; the file extension `.bel` is the one rule of the name a tool depends on.

### ADR-0006: Permissive license (MIT)
The audience is academic and lab users, who often may not use copyleft code, and nobody will turn an origami language into a service worth guarding against; MIT keeps adoption friction lowest.

### ADR-0007: Beloch is an evaluator, not a compiler; CLI shape
Like Nix, Beloch turns source into a data artifact and produces no machine code, so "evaluator" is the term that does not mislead readers who know programming languages; one command with subcommands keeps `beloch fold` as the primary verb.

### ADR-0008: Exact rational arithmetic for the geometry engine
A tolerance comparison makes membership and equality fuzzy at the foundation and accumulates error across folds; exact numbers decide them once and for all.

### ADR-0009: A constrained total language, Rabbit Ear as a consumer
A model description gains its value from what it cannot do: a total program is a linear, analyzable sequence of folds that yields step diagrams, static analysis and several back ends, which a script in a host language does not guarantee.

### ADR-0012: Real-algebraic number kernel
Axiom 7 solves cubics whose three real roots no real radical expresses, so a cube-root generator cannot hold them; real algebraic numbers hold every origami number, and a float filter may only speed up a decision it cannot change.

### ADR-0013: FLINT qqbar backend for irrational values
The kernel's own resultant arithmetic grew degrees multiplicatively and could not represent composite extensions; FLINT's qqbar does both, about 1000 times faster on the measured cases, so the kernel keeps its own fast paths and hands the rest to FLINT.

### ADR-0018: Core module boundaries
One evaluator function of 2416 lines made every change carry the whole file and let the compiler miss dead code; a split by phase gives each phase an interface, while a split by statement kind would repeat every phase per kind.

### ADR-0019: Attribution is carried by construction
Beloch opens no new way to copy a model; it makes credit easy to drop. Showing declared credit in Beloch's own tools sets the norm, and a license clause would tax honest users while any other FOLD viewer sidesteps it.

### ADR-0020: The multifold research package lives in a separate repository
Unpublished research is easier to hold back before it is written up; a one-way dependency keeps the language free of carve-outs for it.

### ADR-0023: The mark is a Beloch program
A valid crease pattern cannot form the digit seven, and a flat-foldable vertex whose fourth ray `flatten` solves shows the operation that sets Beloch apart from a library of axioms.

### ADR-0024: The web client holds its state in a composable runtime
Three surfaces answered the same questions with their own state and disagreed on what a selection is; a planned editor preview has no DOM and evaluates by subprocess, so evaluation and drawing sit beside the core.

### ADR-0028: An error carries its hint apart from its message
The command line and the playground show the suggestion in its own row, and splitting one string at its punctuation breaks with the next message someone writes.

### ADR-0032: The specification binds every implementation; the kernel document describes one
Counting the kernel document into the contract would bind a second implementation to the data structures and ceilings of the first. The OpenSpec specification now takes the binding role the three reference documents held.

### ADR-0034: Action is the sixth core module
The verbs that change the folded state share one property, and naming a module after it gives `eval.ml` room under its line limit; a binding that never touches the state stays in `Eval`.

### ADR-0045: The grammar of the language stands on one page
Grammar fragments spread over five pages made every cross-page rule need a resolver that reads every page, and the grammar page repeated each rule as a copy.

### ADR-0049: The examples are popular models, each folding a published sequence
A base shows one operation; complete popular models show folders models they know and give a paper programs long enough to measure against earlier languages.

### ADR-0054: A document is one of four kinds, and a link names an id
Diátaxis kinds give the manual and explanations a place that guides and decision records could not hold; a link by path breaks on every move, and a link without a resolver and a check rots unnoticed.

### ADR-0062: Records live apart from the pages
The project's own records serve a different reader than the site's pages; with decisions moved into OpenSpec, the journal is the one record left in `records/`, and a rule is stated once, in a requirement.

### ADR-0063: 3D folded states need a type-level rework of the kernel
The kernel's points and motions are planar, so a non-flat fold cannot be a parameter on the existing state; stating the ceiling keeps downstream code from assuming a 3D placement that does not exist.

### ADR-0064: A defined term stands on its own with a glossary entry of its kind
One glossary entry for five terms made a reader look up one term in the definition of another; an entry per term lets an extension change construction and candidate while alignment and selection stay put.

### ADR-0065: The FOLD is the only data layer, and each output kind is a library over it
The FOLD already carries frames, statements and annotations, and the media differ more than one instruction schema can absorb; layout is a computation, which belongs in the host language.

### ADR-0066: The FOLD logs every executed statement in one flat list
Annotations target statements inside `def` bodies and a diagram draws a repeated `apply`; a flat list with a parent index carries the call tree without making every consumer recurse.

### ADR-0068: The FOLD carries a program's credits, and the repository's check requires them
A header comment is read by no tool and does not reach the FOLD; annotations do, and the repository's convention is enforced by a script while the language asks for nothing.

### ADR-0069: The kernel stores the layer order as a side per pair of overlapping faces
One list of all faces orders faces the paper leaves unordered, makes results depend on the route to a state, and cannot hold a cyclic state such as the square twist.

### ADR-0080: A reviewed type states its contract in an interface, and the check holds the maintainer's hash of it
Agents write most of the code and the maintainer reviews types first; a hash per reviewed interface, checked outside `check`, tells the maintainer which change waits for review, where CODEOWNERS would block every pull request opened under the maintainer's account.

### ADR-0081: The number kernel holds values up to a measured degree over one generator
Field arithmetic over one generator beats qqbar, which computes a minimal polynomial for every result, up to the measured cap; a degree fixed in prose would go stale with the next measurement.

### BEP-0011: Beloch is an action model (folding), not only crease-pattern construction
A crease's mountain or valley depends on the side it is seen from, so a program describes the folding actions and derives the crease pattern and the letters from the states, as a folder does on paper.

### BEP-0014: A crease is a bundle of segments
A crease scored through N layers is N segments that lie on one line only in the state that scored it, so the bundle is the durable referent and the line is read off it while it is straight.

### BEP-0015: Flat folded states only (2D isometries); 3D is a goal, not a carried feature
The kernel's folds are reflections of angle 180 degrees, so the language guarantees the all-layers simple-fold model and no 3D generality until a hinge fold evaluates.

### BEP-0016: Typed operands: bundle values, singleton slots
A stored single segment or flap goes stale when a later fold splits it, so names hold only time-stable points and bundles and a slot resolves to one referent in the state where it is used.

### BEP-0017: A flap is a coplanar cluster of faces, not a single precrease polygon
Counting every marked crease as a flap boundary made points on a flat sheet fall on different flaps and left a point straddling a fold's moving set, so a flap ends only at a folded hinge.

### BEP-0025: Construction, candidate, selection and material stand on their own
A construction yields finitely many candidates and only a selection reaches a line, so the place where two-fold constructions turn a line into a tuple stays visible.
The writes that change the state are named by a property, effective, because a list of verbs goes stale with the first new write.

### BEP-0027: The meet is the intersection of its operands as point sets
Requiring each operand to lie on one paper line refused meets with one common point; picking among several crossings would read the folded state, so ambiguity stays an error that lists the points.

### BEP-0029: Annotations pass through to the FOLD, and each output kind is a TypeScript library over it
Annotations in the source are checked on every run where a sidecar file drifts; keeping them out of the geometry means an annotation-only edit cannot change the fold, and a step group as an annotation cannot grow a scope.

### BEP-0030: A program has two axes, and the FOLD logs every executed statement on them
The model counts states and the language counts statements; a stepper walks the writes while an editor needs a stop for every binding, and neither should parse the program.

### BEP-0031: toward names the side that stays; heading names the direction of the crease
One rule for toward covers axioms 5, 6 and 7, since a line has no landing point and a folder points at where paper goes; the older rules picked different candidates per axiom kind.
heading asks for the direction of the crease without a position, which keeps degrees and lengths out of one measure.

### BEP-0033: A line reads as the bundle it names; a mark's bundle is its extent
Reading a mark as all the paper on its table line made its material change with every later fold, so every read takes the bundle under the name, and a mark's bundle is its extent.

### BEP-0036: A write reaches every layer under its axis; moving names a side
A folder presses a crease through the whole stack under the finger, so every write takes all layers by default and moving names only a side.
Folding one flap alone is the case that needs saying, and up to says it.

### BEP-0037: A fan moves its tip; a single crease moves every layer under it
A fan through several separate flaps takes a hand per flap; moving every layer would fold the back flap of the preliminary base along with the front one.

### BEP-0038: squash takes a bare alignment of its spine; the vertex completes the axis
A diagram gives a squash with one word and an arrow; the vertex the write already knows completes the alignment, so the program writes no eight-ray fan.

### BEP-0039: on marks the named flap alone, where the folder opens the model to do it
A folder creases one layer of a hinged flap by opening the model partway, and the states before and after are flat, so the mark succeeds instead of failing or scoring the whole tip.

### BEP-0040: A fan sits at a table point; on names the flap it folds
A reverse or squash crosses its spine in every layer at once, so its fan belongs to the table point and its construction or spine names the anchor.

### BEP-0041: The vertex of a fan may lie off the paper or at infinity
A reverse parallel to its spine is a valid fold; Kawasaki's condition holds only where the paper surrounds the vertex.

### BEP-0043: A reverse fold turns the hinges across its opening
A tip of several layers can open in more than one place, and a folder picks where; a default opening fits no case in general.

### BEP-0044: A fan moves each piece by the creases on its paper path
On folded paper two pieces of one wedge move differently; placing faces by paper paths [hull2020, Def. 6.5] covers squash and reverse with one fan.

### BEP-0046: A sheet is a square of given size or a flap cut from a folded sheet
A keyword per shape would grow the language and need irrational literals; a shape built by folding a square reaches every ratio by construction and keeps the source free of coordinates.

### BEP-0047: A trim exports the names it lists
A body cannot rebind the square's `.c` while it still folds with it, so the trim renames on export and every opening program sees the names the shape's author chose.

### BEP-0048: staying names a sector of the anchor by points
Fisher's two waterbomb bases on a folded rectangle differ only in which part is held; a flap reaches every sector of a marked layer and cannot tell them apart.

### BEP-0050: A 3D state is flat blocks turned on hinges; a simulation only fills what the program leaves free
Until a hinge fold evaluates, every state stays flat; the planned 3D state keeps every comparison exact and lets a simulation fill only degrees of freedom no later statement reads.

### BEP-0051: A program states who wrote it, who designed its model and what it follows, as annotations of the program
Credits are facts about the whole program and no statement is their target; text names a source for any reader, where a cite key would tie the language to one bibliography.

### BEP-0052: A fold placed over or under a flap takes the layers between its depth and that flap
A folder tucking a side lifts every layer between the depth and the target, hinged or not; closing over hinges alone left a raw-edged layer behind and the fold pierced it.

### BEP-0053: unfold turns layers over a crease and opens the hinges on it
A separate verb lets a reader tell from the text whether a write opens hinges or folds new ones; one direction word both selects and places the layers, so the result never depends on a hidden check.

### BEP-0055: A flatten folds several fans at once
The petal fold turns about two vertices in one motion; as one statement it replaces two reverse folds and a valley fold.

### BEP-0057: The layers a flap is hinged to hold its squash
The first squash a folder learns has no material beyond its target line; the layers the flap is hinged to there hold it without an extra item.

### BEP-0058: The outline ranks the states of every fan
A squash or petal that reaches past the outline is ordinary folding; ranking keeps the tie-break the corpus needs without failing those folds.

### BEP-0059: A fold orders two faces only where they overlap
Paper relates two layers only where they overlap, and a stored stacking holds an order the paper lacks; reading it made the crane's neck open differently on two routes to one bird base.

### BEP-0060: A rule that picks one of several results reads the pairs only
Two results that agree on every overlapping pair are one state, so a choice among results that compared stackings would count one state several times.

### BEP-0061: A verb chooses its result by conditions, and a squash has two valleys at its flanks
A ranking gives an answer on every input and hides the other states; a squash differs from a swivel fold on the same creases by its two valley flanks [lang2011secrets, §2.2].

### BEP-0077: A verb gives the units of its fan's layer order
Units of one motion made both layers of a reverse fold's strip turn over as one, which is no reverse fold; the verb knows its blocks, so it hands them to the one shared search.

### BEP-0078: A point names the wedge of the emergent ray, and flatten takes no toward
`toward` chose by a score; a point in the wedge states the same choice as a condition.

### BEP-0079: A fan folds at a point of the paper
Table regions fold every ray in every layer under the vertex; the frog's petal fold folds a crease in one layer and leaves it flat in the other.

### BEP-0082: An over item orders the faces of its two points
Ordering whole pieces makes a flap folded between two layers of one piece satisfy no `over` item in either direction.

### BEP-0083: A name with two dashes holds a crease
A line bound with `=` was a value the program knew and the paper did not show, so a name holds a crease or an edge, and a line a later fold aligns to is scored first.

### BEP-0084: A program unites no bundles
The union `[--l --m]` looked like a meet with its `.` dropped and no program needed it, so a bare bracket is an error and every bracket form selects one thing of its sigil's sort.

Rules that are decided and not built went to open changes, which keep their reason: ADR-0067 and BEP-0035 to `report-warnings`, the display of credits from ADR-0019 to `show-declared-credits` and their place in exports other than the FOLD file to `carry-credits-in-every-export`, the kinds of glossary entries from ADR-0064 to `glossary-term-kinds`, and the reading of namespaced annotations by the YR library from BEP-0029 to `read-yr-annotations`.

Records that contributed nothing:

- ADR-0002: superseded; the FOLD output is held by the output capability (ADR-0065, FOLD.md) and the boundary by "The tooling edge is written in TypeScript"
- ADR-0010: superseded by ADR-0012; its exact-sign rule lives on in "The kernel computes geometry exactly"
- ADR-0021: superseded by ADR-0032, which ADR-041 of the fleet repository supersedes in turn; SPECIFICATION.md is gone from the tree
- ADR-0073: abandoned: Ortac cannot translate the non-crossing postconditions; no rule in force depends on it
- ADR-0074: abandoned; its fix, joining on the statement index the emitter writes, is held by output "A consumer joins on the entry index"
- BEP-0022: superseded by BEP-0031 (selection), which carries forward the alignment set as the canonical form of a construction
- BEP-0026: superseded by BEP-0030; its two axes and statement log are held by output "A position in a program is a pair of a state and a statement count" and "The FOLD logs every executed statement in one flat list"
- BEP-0042: superseded by BEP-0043; its rule now held by reverse-fold "A reverse fold opens its tip at one opening"
- BEP-0056: superseded by BEP-0058; its rule now held by multifold "The outline ranks the states of every fan"
- BEP-0070: abandoned history of the 2018 design; its one lasting rule is held by "The kernel implements no rule the specification lacks" (ADR-0003)
- BEP-0071: abandoned; the split into def, apply, export and step is held by the names capability
- BEP-0072: abandoned; crossings are computed on material in paper space (BEP-0027, operands)
