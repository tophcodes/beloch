# Item syntax for write statements (design)

## Status

Draft for review (2026-09-13). The language decision is fixed by
`spec/BELOCH.md` ("Parameter types", "Write statements", "Constructions",
"Grammar"); this document designs how the implementation meets it and does
not reopen it.

What is fixed:

- Every argument of a write is a parenthesised item. The construction that
  supplies the axis is an item like the others. Items stand in any order.
- The canonical construction is `(align …)` over alignments. The seven prose
  forms are sugar for it.
- Round parentheses are items and braces are blocks. `flatten`'s selection is
  `(toward .q)`; no brace item remains in the language.
- A write's output is named by a clause after the items: `as --f` binds the
  scored crease to a new name, `as --f!` rebinds, `into --l` adds the scored
  material to an existing crease, no clause leaves it anonymous. `=` binds the
  value of a read and nothing else.
- One sigil, two sorts. `--l = …` is a line, `… as --l` is a crease. Slots
  demand one or the other, and the check reads the binding form with no
  geometry.
- Hard cut. The bare-keyword argument forms are removed with no compatibility
  period, every `.bel` file in the repository is rewritten, and the folded
  geometry of every example and case is unchanged.

Two places where the fixed documents disagree with each other or with the
code, resolved here and listed again under Migration:

1. The `=` binding of a write is gone from every verb. `mark --l = …`,
   `fold --f = …`, `reverse --h = …` and `--r = flatten …` all become the
   output clause: `mark … as --l`, `fold … as --f`, `reverse … as --h`,
   `flatten … as --r`. One form for five verbs, and `=` is left to reads, so
   a name's sort is visible at its binding.
2. `spec/BELOCH.md` gives `align`'s multi-line head as `"align" CREASE_NAME*`
   and the brief calls a construction "over two or more fold lines" the
   unevaluated case. A construction with exactly one named line denotes the
   same class and the kernel cannot solve it either, so the rule implemented
   here is: a non-empty name list, or any alignment carrying a line prefix,
   makes the construction unevaluated. A one-line `align` has no use for a
   name, so naming is the marker of the multifold form.

### Against the decision record

- **ADR 0004** (Menhir for the compiler parser, tree-sitter for editors) holds:
  two grammars, maintained by hand. Its consequence line accepts that cost on
  the ground that surface syntax stays low-churn. This slice is a churn event,
  and the reference corpus test is what it puts in place of that ground: both
  grammars are held to the same document by a test rather than by the syntax
  standing still.
- **ADR 0016** §5 (a bare point or line in a flap-typed slot is sugar for a
  one-element constraint list) already decides the `on` slot's operand forms;
  the widening below follows the record rather than extending it.
- **ADR 0018** (core module boundaries) covers the chain
  `Ctx → Resolve → { Axiom, Flatten_solve } → Eval`. `Items` sits on the parse
  side, before that chain, and its `.mli` follows the same convention. The
  `eval.ml` line budget stays green.
- **ADR 0022** (`decisions/0022-constructions-are-alignment-sets.md`) fixes
  the form a construction takes in the tree: the alignment set, with the prose
  spellings desugared to it at parse time and the seven sets recognised in
  `Axiom`. The Constructions section below designs that and records the
  alternative it replaces.

## Motivation

A write's arguments are read today by a per-verb clause chain: `fold_clauses`
is `moving_opt upto_opt place_opt mountain_opt`, `mark_clauses` is
`extent_opt mountain_opt layer_opt`, `reverse_clauses` is
`moving_opt outside_opt`. Three consequences:

- **Order is fixed and arbitrary.** `fold --d moving .b up to .c` parses and
  `fold --d up to .c moving .b` does not, for no reason a reader of the
  language can derive. The comment above `fold_clauses` records that
  `place_opt` was moved ahead of `mountain_opt` so that one wrong order would
  produce a good message instead of a syntax error.
- **Arguments have no boundaries.** `moving .b up to .c` is a token run;
  nothing in the source says where the anchor ends and the depth begins. A
  tool that wants to colour the anchor differently from the depth, or to
  contain a typo inside one argument, has nothing to attach to. The
  tree-sitter grammar reflects that: it is a flat token classifier with no
  rule for any write statement.
- **The construction is not an argument.** The axis arrives as a `markable`
  in front of the clause chain, so the model's signature (a write takes a
  line, a flap, an extent) has one parameter that looks different from the
  rest in the source.

`flatten` already carries the target shape: every argument is a `( … )` item,
items stand in any order, and the statement action partitions them. This slice
generalises that shape to every write and to the construction.

The second half of the motivation is the construction itself. `MODEL.md`
[#def-motion] defines a motion as a set of alignments; the seven axioms are
seven such sets. The language has only the seven prose spellings, so the
canonical object of the model has no written form, and the two-fold axioms
have no syntax to grow into. `(align …)` gives the alignment set a surface,
with the prose forms as named shorthands for seven of them.

## Language design

### Grammar

The collected grammar is in `spec/BELOCH.md`. Restated in the shape the
Menhir file takes:

```
write_stmt   := verb item* [ output ]
output       := "as" CREASE_NAME [ "!" ] | "into" CREASE_NAME
verb         := "mark" | "fold" | "reverse" | "flatten" | "flip"
item         := "(" item_body ")"

item_body    := construction_body                        ; the axis, as a construction
              | line_operand [ "mountain" | "valley" ]   ; the axis, or a flatten ray
              | "moving" flap_operand
              | "up" "to" flap_operand
              | "mountain" | "valley"
              | ( "over" | "under" ) flap_operand
              | "outside"
              | "on" flap_operand
              | "between" point_operand point_operand
              | "at" point_operand
              | "staying" flap_operand
              | over_flap "over" over_flap
              | "toward" point_operand

bind_stmt    := CREASE_NAME "=" "(" construction_body ")"   ; binds a line
              | CREASE_NAME "=" bundle_expr                  ; binds a crease
```

Round parentheses are items and braces are blocks. `{ … }` occurs in `def`
and `export` and nowhere else, so `flatten`'s selection is `(toward .q)` like
every other argument and the language has one bracket per job. The `toward`
that belongs to a construction stays inside the construction's item, where it
selects among that construction's candidate lines; `(toward .q)` as an item of
its own is `flatten`'s selection among candidate states
([open-flatten-selection](/model/#open-flatten-selection)). The two never
collide, because a construction item's body starts with `align`, `map`,
`through` or `perp`.

`item_body` is one nonterminal, the union of every verb's item bodies. The
parser accepts any head after any verb and a second pass classifies the list
against the verb's signature. Three reasons to parse the union rather than a
per-verb item set:

- A head that does not belong to the verb gets a message naming the verb and
  the head, at the item's span, instead of `syntax error` at whatever token
  the LR automaton died on.
- The same shape can be implemented in tree-sitter, which should not carry the
  per-verb signature. One grammar, two implementations, and the reference
  corpus test (below) holds them together.
- The per-verb table then exists in exactly one place, `Items`, and a new verb
  or a new slot is an entry in it.

### The output clause

A write scores one crease and the clause after the items says what becomes of
it. The clause is the same for all five verbs and there is at most one.

- **`as --f`** binds the scored crease to a new name. A name already bound is
  an error; `as --f!` rebinds, with the `!` of `SPECIFICATION.md` §5a.6.
- **`into --l`** adds the scored material to the crease `--l`, which keeps its
  name and its crease id. The new material must lie on the table line of a
  segment of `--l`.
- **No clause** leaves the crease anonymous, reachable by incidence only.

The clause sits after the items rather than before them because the items are
the arguments and the clause is the result, and because a verb followed
straight by `(` is the shape every write now has. `flip` scores nothing, so a
clause on `flip` is an error.

`=` keeps its one job, binding the value of a read, so the sort of a name is
visible where the name is introduced.

### Sorts of a name

One sigil, two sorts. `--l = (map .a onto .c)` binds a line, a value with no
material. `mark (map .a onto .c) as --l` binds a crease, the material scored
under that name. `--x = --l & .p` binds a crease too, because a filter is a
read of sort bundle over creases.

The kernel already separates them and has since the value bindings landed:
`Ctx.crease_val` is `Frozen` for a line, `Material` and `Mark` and `Edge` for
a crease with material, and `Bundle` for a crease-valued expression. The sort
of a name is its constructor, and no geometry is read to tell them apart.

Which sort each slot demands:

| slot | sort |
|---|---|
| the operands of a construction | line or crease |
| the axis item of `mark` | line or crease |
| the axis item `(--d)` of `fold` and `reverse` | crease |
| a `flatten` ray | crease |
| the meet `*` and `.[…]` | crease |
| the filters `&`, `\`, `[…]` | crease |
| `free on` | crease |
| the flap operand's line form (`moving --d`, `up to --d`, `on --d`) | crease |
| `into` | crease, and one with material of its own |

A crease stands where a line is wanted by projecting to its table line, which
exists while its segments are collinear (ADR 0014) and is the existing
`is bent` error once a fold has bent it. A line stands nowhere a crease is
wanted, because it has no material until a `mark` scores it.

**Where the check lives.** In `Resolve`, at the slot, reading the binding's
constructor and nothing else. One function carries it:

```ocaml
val crease_of : Ctx.ctx -> Ast.crease_ref -> slot:string -> Error.span -> Ctx.crease_val
(** The binding of [cr], when it is a crease. Fails with
    "--l is a line; <slot> needs a crease" when the binding is [Frozen]. *)
```

and the four sites in `Resolve` that today report a `Frozen` binding with a
geometry-flavoured message call it instead. The alternative, a pre-pass over
the AST that builds a name-to-sort table before evaluation, is what `beloch
check` will be. It is not this slice: the scope machinery it would need
(`def` bodies, instances, `export` landings, temp names) exists once in `Ctx`,
and a second copy of it is where the two would drift. What the pre-pass adds
over the `Resolve` placement is narrow and worth stating so the follow-up is
contained: it reports a sort error inside a `def` body that no `apply` ever
reaches, and it reports without running the kernel.

### Which items each verb takes

| verb | required | optional |
|---|---|---|
| `mark` | one axis item | one layer item (`on`), one extent item (`between` or `at`), one intent item (`mountain`/`valley`) |
| `fold` | one axis item | one anchor item (`moving`), one depth item (`up to`), one placement item (`mountain`, `over`, `under`) |
| `reverse` | one axis item | one anchor item (`moving`), one kind item (`outside`) |
| `flatten` | one or more ray items | order items (`over`, any number), one stayer item (`staying`), one selection item (`toward`) |
| `flip` | none | none |

An axis item is `(<construction>)` or `(<line>)`. A ray item is `(<line>)` or
`(<line> mountain|valley)`. `mountain` standing alone is an intent value under
`mark` and the placement value *bottom* under `fold`, so `(mountain)` beside
`(over .p)` is two values in the placement slot and is rejected on that
ground, keeping the message the placed-fold slice shipped.

Element order stays semantic for `flatten`: the first two ray items fix the
stayer by convention (`SPECIFICATION.md` §4.9). Every other item carries no
positional meaning, in any verb.

### Constructions

```
construction_body := "align" CREASE_NAME* alignment+ [ "toward" point_operand ]
                   | prose_axiom
alignment         := "(" [ CREASE_NAME ] object "onto" [ CREASE_NAME ] object ")"
                   | "(" [ CREASE_NAME ] "through" point_operand ")"
                   | "(" [ CREASE_NAME ] "perp" line_operand ")"
object            := point_operand | line_operand
```

`prose_axiom` is the seven spellings that exist today, unchanged: `map … onto
…`, `through … …`, `perp … through …`, `map … onto … perp …`, `map … onto …
through … [toward …]`, `map … onto … and … onto … [toward …]`, `map … onto …
[toward …]`.

**Recognition.** An `align` with no named fold lines and no line prefix on any
alignment is recognised by the multiset of its alignment kinds:

| alignment kinds | axiom | operand roles |
|---|---|---|
| through a point, through a point | 1 | `Through (p1, p2)` |
| point onto point | 2 | `MapPoints (p, q)` |
| perp to a line, through a point | 3 | `Perp (p, l)` |
| point onto line, perp to a line | 4 | `MapOntoLine (p, d, m)` |
| line onto line | 5 | `MapLines (l, m, toward)` |
| point onto line, through a point | 6 | `MapThrough (p, d, q, toward)` |
| point onto line, point onto line | 7 | `MapBoth (p, d, q, e, toward)` |

Numbering is the classic Huzita-Justin numbering of `SPECIFICATION.md` §1, the
one the solvers in `Axiom` already carry as their provenance tags
(`"axiom1"` … `"axiom7"`). The operand-role column names the `Ast.axiom`
roles of `Axiom.classify`'s result.

The kinds are a multiset, so alignment order is free. Where one kind occurs
twice, axioms 1 and 7, source order fixes the operand order: the first
`point onto line` of an axiom-7 construction is `p`, which is also the point
`Eval` reads as the implied anchor of a map fold. `toward` is accepted on
axioms 5, 6 and 7, which are the constructions with more than one candidate,
and rejected on the other four.

An alignment whose two objects have kinds outside the table, `(--l onto .p)`
for instance, produces no match and reaches the same "not one of the seven"
message as any other unrecognised set.

#### The alignment set is the AST (ADR 0022)

`decisions/0022-constructions-are-alignment-sets.md` fixes the form: a
construction is its alignment set in the tree, the prose forms desugar to it
at parse time, and the recognition table above is applied in `Axiom`.

`Ast.axiom` is replaced by

```ocaml
type construction = {
  c_fold_lines : string list;        (* CREASE_NAME* in the align head *)
  c_alignments : alignment list;     (* source order, one entry per alignment *)
  c_toward : point_operand option;
  c_span : Error.span;
}
```

Prose forms build the same record, with the alignment list in the order the
spelling fixes: `map .p onto --l through .q` gives
`[point onto line; through a point]`. An `align` gives whatever order the
author wrote. The two agree as sets, which is what recognition reads.

`Axiom` gains two functions and keeps `axis_of` as its entry point:

```ocaml
type classified =
  | Ax1 of point_operand * point_operand
  | Ax2 of point_operand * point_operand
  | Ax3 of point_operand * line_operand
  | Ax4 of point_operand * line_operand * line_operand
  | Ax5 of line_operand * line_operand * point_operand option
  | Ax6 of point_operand * line_operand * point_operand * point_operand option
  | Ax7 of point_operand * line_operand * point_operand * line_operand
           * point_operand option

val classify : Ast.construction -> classified
(** Recognise the alignment set as one of the seven, by the table above.
    Fails naming the alignments when the set matches none of them, and when
    the head names fold lines. Order-insensitive across kinds; where a kind
    repeats, source order fixes the operand roles. *)

val tag : classified -> string
(** The provenance tag, ["axiom1"] … ["axiom7"]. *)

val implied_point : Ast.construction -> Ast.point_operand option
(** The point a map construction moves, which a `fold` takes as its anchor
    when the program names no `moving`: the first operand of axioms 2, 6 and
    7, and [None] for the rest. *)
```

`axis_of` calls `classify` first and then runs today's seven-arm dispatch over
`classified`, so every solver body, the axiom-5 deferral and the error texts
inside them are unchanged. `State.provenance.axiom` comes from `Axiom.tag`,
and `sources` is built from the operands `classified` hands back, so the
provenance strings stay what they are today.

What this costs, counted: two sites in library code match on the seven
constructors, ten constructor arms in total. `Axiom.axis_of` (seven arms) and
`Eval.resolve_markable`'s implied-anchor derivation (three arms: `MapPoints`,
`MapThrough`, `MapBoth`, now one call to `Axiom.implied_point`). `Resolve`,
`Fold_emit`, `Flatten_solve`, `Spine`, `packages/multifold` and
`packages/eval-web` match on none of them. Outside library code,
`packages/core/tests/test_parse.ml` carries 36 lines with such a pattern, all
in that one file; they become assertions over alignment lists. `BindLine`
carries a `construction` instead of an `axiom`, one constructor argument in
`ast.ml` and one pattern in `Eval`.

Two consequences to plan around:

- **The sugar test is axis equality after evaluation.** The two spellings no
  longer produce equal ASTs, since a prose form fixes its alignment order and
  an `align` does not. The test evaluates both spellings in the same program
  and compares the resulting `Geom.line` and the provenance tag. Comparing
  ASTs after sorting the alignment list by kind is the cheaper variant and the
  weaker one: it checks the parser where the other checks the pipeline.
- **Recognition errors fire at evaluation.** A construction in a binding that
  no write ever reaches goes unchecked, since an unevaluated statement still
  parses. The case is narrow, and the reference corpus test evaluates every
  block of `BELOCH.md`, so the recognition table stays under test.

What multifold gains: a construction over named fold lines keeps its
alignments in the tree, so it is representable, the kernel refuses it with a
message from the evaluator, and `packages/multifold`'s naming of two-fold
axioms (`AL6ab8` and its family) has a source-level object to name.

**Rejected: recognise at parse time and keep `Ast.axiom`.** The alignment
production would hand its list to a recogniser in `Items`, which applies the
table and returns one of the seven existing constructors; prose forms would
build those constructors directly, as they do today, and `Axiom`, `Eval` and
`test_parse` would need no change at all. Rejected on two grounds. The
canonical form would exist only in the document: [#def-motion] makes the
alignment set the definition and the axiom number the name of one such set,
and an AST that keeps the name and drops the thing named leaves two
representations in the pipeline with a one-way map between them. And a
multifold construction would have no node to live in, so it would raise inside
the parser and `packages/multifold` would have no input from source, which is
the one growth direction `BELOCH.md` has already fixed the syntax for.

### Examples

```
fold    (map .a onto .c) (moving .a)
fold    (map .a onto .c) (moving .a) (mountain)
fold    (through .m .n) (moving .b) (under .p)
fold    (--d) (moving .b) (up to .c) into --d
fold    (map .a onto .c) (moving .a) as --f
reverse (map .b onto .c) (outside)
mark    (through .a .c)
mark    (map --ab onto --cd) (on #[.c]) (between .a .m) (mountain)
mark    (map .a onto .c) (between .a .m) as --p
mark    (--p) into --p                             ; the same crease, full chord
flatten (--h & --bc) (--v & --cd) (.q over .r) (staying .a) (toward .q)
flatten (--ea) (--ec) (--eb) (toward .a) as --ear
flip
--l = (map --a onto --b toward .p)                 ; a line, no material
--x = [--ea --eb] & .a                             ; a crease, a selection
```

and the same constructions written canonically:

```
fold (align (.a onto .c)) (moving .a)
fold (align (through .m) (through .n)) (moving .b) (under .p)
mark (align (--ab onto --cd)) (on #[.c]) (between .a .m) (mountain)
```

### `on` widens `mark`'s layer slot

`BELOCH.md` types the `on` slot as flap, which is the three-form flap operand
(a point, a line, or `#[…]`), where the bare `#[…]` it replaces admitted only
the third form. `(on .c)` and `(on --d)` therefore parse and resolve through
the flap resolver every other flap slot uses. ADR 0016 §5 already fixes this:
a bare point or line in a flap-typed slot is sugar for a one-element
constraint list, so the layer slot was the one flap slot out of line with the
record. This is the only semantic change in the slice.

## Kernel design

The statement constructors of `Ast.stmt` keep their shape; two of them carry a
`construction` where they carried an `axiom`. `Flatten_solve`, `Spine`,
`Fold_emit` and `Ctx` are untouched, and `Resolve` changes only for the `on`
widening. The change is contained in the lexer, the parser, the AST, one new
module, and the recognition front of `Axiom` that ADR 0022 moves there.

### `lexer.ml`

Two tokens: `"align" -> ALIGN` and `"into" -> INTO`. No identifier in the
repository is `align` or `into`, and no `def` carries either name, so
promoting them to keywords breaks nothing. `AS` and `BANG` already exist, from
`export … as … !`. Every other head word is already a token: `MOVING`, `UP`,
`TO`, `MOUNTAIN`,
`VALLEY`, `OVER`, `UNDER`, `OUTSIDE`, `ON`, `BETWEEN`, `AT`, `STAYING`,
`TOWARD`, `ONTO`, `PERP`, `THROUGH`, `MAP`.

### `ast.ml`

Added, about 50 lines:

```ocaml
type align_object = AoPoint of point_operand | AoLine of line_operand

type alignment_kind =
  | AlOnto of align_object * align_object
  | AlThrough of point_operand
  | AlPerp of line_operand

type alignment = {
  al_fold_line : string option;   (* CREASE_NAME in front of the first object *)
  al_fold_line2 : string option;  (* CREASE_NAME in front of the second object *)
  al_kind : alignment_kind;
  al_span : Error.span;
}

(* One parenthesised argument of a write, classified by its head only. The
   verb decides what each head means; Items holds that table. *)
type raw_item =
  | RiConstruction of axiom * Error.span
  | RiLine of line_operand * mv_constraint * Error.span
  | RiMoving of flap_arg * Error.span
  | RiUpTo of flap_arg * Error.span
  | RiLetter of mv_constraint * Error.span     (* (mountain) / (valley) *)
  | RiPlace of place_dir * flap_arg * Error.span
  | RiOutside of Error.span
  | RiOn of flap_arg * Error.span
  | RiExtent of extent * Error.span            (* (between …) / (at …) *)
  | RiOrder of flap_arg * flap_arg * Error.span
  | RiStaying of flap_arg * Error.span
  | RiSelection of point_operand * Error.span
```

`RiConstruction of construction * Error.span` carries the record the
alignment production builds (ADR 0022); recognition runs later, in `Axiom`.
`alignment` and `construction` are in the AST because the parser builds them
and `Ast.stmt` retains them: `BindLine` and `MMotion` both carry a
`construction` where they carried an `axiom`, which is the whole of the
`ast.ml` change beyond the surface types.

The output clause is one type, carried by every write constructor in place of
the `string option` name they hold today:

```ocaml
type output =
  | Anonymous
  | Named of string * bool * Error.span   (* as --f, `true` for the ! rebind *)
  | Into of string * Error.span           (* into --l *)
```

`Mark`, `Fold`, `Reverse` and `Flatten` take an `output` where they took a
`string option`; `Flip` takes one so that a clause on `flip` reports rather
than failing to parse. `Mark`'s layer slot becomes `flap_arg option`, was
`flap_operand option`.

### `items.ml` / `items.mli` (new)

A leaf module over `Ast` and `Error`, called from the semantic actions of
`parser.mly`. No dependency on `Parser`, so the module graph stays acyclic:
`Error → Ast → Items → Parser`. It sits on the parse side and does not touch
the `Ctx → Resolve → { Axiom, Flatten_solve } → Eval` chain of ADR 0018.

```ocaml
val mark    : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val fold    : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val reverse : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val flatten : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val flip    : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
```

Each of the five walks the item list once, left to right, into the slots of
its verb, and builds the existing `Ast.stmt` constructor. Two shared helpers
carry every duplicate and every wrong-head message:

```ocaml
val slot : string -> string -> 'a option ref -> Error.span -> 'a -> unit
(** [slot verb head cell span v] fills [cell] or fails at [span] with
    "only one <head> item per <verb>". *)

val reject : string -> string -> Error.span -> 'a
(** "<verb> takes no (<head>) item". *)
```

`Items.flatten` absorbs today's `mk_flatten`, which lives in the header of
`parser.mly`, including its ordering of `elems`/`overs` by source position.

Size: `items.ml` about 240 lines, `items.mli` about 45.

### `parser.mly`

Removed: `markable`, `fold_clauses`, `reverse_clauses`, `mark_clauses`,
`place_opt`, `moving_opt`, `upto_opt`, `mountain_opt`, `extent_opt`,
`layer_opt`, `outside_opt`, `collapse_items`, `collapse_item`,
`collapse_item_inner`, `mv_opt` (kept, it is the ray letter), the
`collapse_item` type and `mk_flatten` from the header.

Added:

```
body_stmt:
  | MARK    items output { Items.mark    $2 $3 $loc }
  | FOLD_KW items output { Items.fold    $2 $3 $loc }
  | REVERSE items output { Items.reverse $2 $3 $loc }
  | FLATTEN items output { Items.flatten $2 $3 $loc }
  | FLIP    items output { Items.flip    $2 $3 $loc }
  | CREASE EQ LPAREN construction_body RPAREN { BindLine ($1, $4, $loc) }
  | CREASE EQ bundle_expr                     { BindBundle ($1, $3, $loc) }

output:
  |                   { Ast.Anonymous }
  | AS CREASE bang_opt { Ast.Named ($2, $3, $loc) }
  | INTO CREASE        { Ast.Into ($2, $loc) }

items:
  |            { [] }
  | item items { $1 :: $2 }

item:
  | LPAREN item_body RPAREN { $2 }

item_body:
  | construction_body                   { Ast.RiConstruction ($1, $loc) }
  | line_operand mv_opt                 { Ast.RiLine ($1, $2, $loc) }
  | MOVING flap_arg                     { Ast.RiMoving ($2, $loc) }
  | UP TO flap_arg                      { Ast.RiUpTo ($3, $loc) }
  | MOUNTAIN                            { Ast.RiLetter (MvMountain, $loc) }
  | VALLEY                              { Ast.RiLetter (MvValley, $loc) }
  | OVER flap_arg                       { Ast.RiPlace (PlaceOver, $2, $loc) }
  | UNDER flap_arg                      { Ast.RiPlace (PlaceUnder, $2, $loc) }
  | OUTSIDE                             { Ast.RiOutside $loc }
  | ON flap_arg                         { Ast.RiOn ($2, $loc) }
  | BETWEEN point_operand point_operand { Ast.RiExtent (Between ($2, $3), $loc) }
  | AT point_operand                    { Ast.RiExtent (At $2, $loc) }
  | STAYING flap_arg                    { Ast.RiStaying ($2, $loc) }
  | over_flap OVER over_flap            { Ast.RiOrder ($1, $3, $loc) }
  | TOWARD point_operand                { Ast.RiSelection ($2, $loc) }

construction_body:
  | ALIGN fold_line_names alignments toward_opt
      { { c_fold_lines = $2; c_alignments = $3; c_toward = $4; c_span = $loc } }
  | prose_axiom  { $1 }
```

plus `alignment`, `alignments`, `fold_line_names`, `align_object` and
`toward_opt`. `prose_axiom` is today's `axiom` rule, renamed.

`flip items` rather than `flip` alone: `flip (moving .a)` then reaches
`Items.flip`'s message instead of a syntax error at `(`.

**Conflicts.** Menhir already runs with `--explain`. The decisions the
automaton has to make at one token of lookahead:

- After a verb, `LPAREN` opens an item and `AS`/`INTO` open the output clause,
  so the empty `items` reduction and the empty `output` reduction are decided
  by one token. `LBRACE` reaches the parser only in `def` and `export`, which
  no item can follow.
- `AS` heads the output clause of a write and the rename of an `export_entry`.
  The two contexts are disjoint: an export entry lives inside `export { … }`,
  which contains no write.
- Inside an item, after a `point_operand`, `STAR` continues a join into a
  `line_operand` and `OVER` reduces to `over_flap`. Distinct lookaheads.
- Inside an item, after a `line_operand`, `MOUNTAIN`/`VALLEY` shift into
  `mv_opt` and `RPAREN` reduces it empty.
- Inside an alignment, after a `point_operand`, `ONTO` reduces it to
  `align_object` and `STAR` continues a join. Distinct lookaheads.
- `LPAREN` begins an item, an alignment (only after `ALIGN`), and a
  parenthesised meet `(--x * --y)` (only in operand position). The three
  contexts are disjoint.
- `AT` heads an extent item and `AT NUMBER` closes a `free on` point
  expression. Disjoint contexts.

Zero conflicts is an acceptance criterion, checked by the absence of
`parser.conflicts` in the build.

Size: `parser.mly` stays near 300 lines; the clause chains removed are close
in size to the item rules added.

### `axiom.ml`, `eval.ml`, `resolve.ml`

`axiom.ml` gains `classify`, `tag` and `implied_point` in front of `axis_of`,
about 90 lines, and its seven solver bodies are moved onto `classified`
without other change. It goes from 408 lines to about 500, which ADR 0018
places no ceiling on.

`eval.ml` loses the three-arm implied-anchor match to `Axiom.implied_point`
and gains the output clause, one function shared by the four scoring verbs:

```ocaml
val crease_id_for : Ctx.ctx -> Ast.output -> Error.span -> int * (int -> unit)
(** The crease id a write scores under, and the binding step to run once the
    write has succeeded. [Anonymous] and [Named _] give a fresh id;
    [Into name] gives the id already bound to [name]. *)
```

- `Anonymous`: `Fold_state.fresh_crease_id ()`, no binding.
- `Named (n, rebind, _)`: a fresh id, then `Ctx.bind_crease` with the rebind
  flag, which is today's binding path with `!` threaded through.
- `Into (n, _)`: the id of `n`'s existing binding. `Material (cid, _)` and
  `Mark (cid, _)` give `cid`; `Frozen`, `Bundle` and `Edge` are sort errors
  (below). Before the write runs, the axis is checked against the crease: it
  must coincide with the table line of some segment of `cid`. Afterwards the
  binding is promoted in place, `Mark (cid, l)` to `Material (cid, l)` when
  the write folded.

**`into` replaces the mark-superseding path.** `fold` along a name bound to a
`Mark` today materialises a fresh crease on the mark's line and relies on the
emitter to drop the coincident mark. With `into --d` the fold scores under the
mark's own id, so there is one crease in the state, one id in the output, and
nothing to supersede. The emitter's superseding rule stays for the anonymous
case, where a fold along a mark still scores a crease of its own.

The promotion `fold (--d)` performs today, repointing `--d` at the fresh
crease without being asked, goes: a write with no output clause binds nothing.
Programs that relied on it say `into --d`, which is the corpus rewrite rule
under Migration.

`eval.ml` nets out at about its current 881 lines and under the 900-line check
of ADR 0018: the implied-anchor match leaves, `crease_id_for` arrives, and the
per-verb name handling those four statement arms carry today collapses into
it. `BindLine`'s `axiom` becomes a `construction`, and the `Mark` layer slot's
type is a pattern variable.

`resolve.ml` takes two changes. `resolve_mark_flap` takes `Ast.flap_arg
option`: `Some (FlapSpec f)` keeps today's path and its two messages,
`Some (FlapPoint _ | FlapLine _)` delegates to `Resolve.resolve_flap_cluster`,
which already resolves all three forms to a coplanar cluster. And the sort
check arrives as `Resolve.crease_of`, which the four sites that report a
`Frozen` binding today call instead of raising their own message:

| site | message today | message after |
|---|---|---|
| `meet_source` (the meet `*` / `.[…]`) | `--l is not a physical crease, so it has no material mark to cross` | `--l is a line; the meet needs a crease` |
| `bundle_segments` (the filters) | `--l is not a physical crease, so it has no segments to select` | `--l is a line; the filter needs a crease` |
| the two flap-operand sites | `--l is not a physical crease, so it names no flap` | `--l is a line; a flap operand needs a crease` |

The `Bundle` messages at those sites stay as they are: a bundle is
crease-sorted and the complaint is about cardinality.

## Tooling

### tree-sitter (`packages/grammar`)

The grammar is a flat token classifier today: `source_file` is
`repeat(_token)` and there is no rule for any statement. It also carries two
keywords the lexer dropped (`collapse`, `standing`) and misses six it has
(`valley`, `reverse`, `outside`, `flatten`, `under`, `staying`).

The grammar gains structure for write statements and keeps the token soup for
everything else:

```js
source_file: $ => repeat(choice($.write_statement, $.construction, $._token)),

write_statement: $ => choice(
  seq('mark',    repeat($._axis_item), optional($.output_clause)),
  seq('fold',    repeat($._axis_item), optional($.output_clause)),
  seq('reverse', repeat($._axis_item), optional($.output_clause)),
  seq('flatten', repeat($._ray_item),  optional($.output_clause)),
  seq('flip',    repeat($._axis_item), optional($.output_clause))),

output_clause: $ => choice(
  seq('as', $.crease, optional('!')),
  seq('into', $.crease)),
```

`_axis_item` and `_ray_item` are the same union of heads and differ in one
alternative: the bare-line item is `axis_item` under the four axis verbs and
`flatten_element` under `flatten`. Every head is accepted under every verb, as
in the Menhir grammar, so a head that the verb rejects still parses into a
named node and the diagnostic comes from the kernel. That is what keeps a
wrong head from producing an `ERROR` node and what contains a malformed item
inside its own parentheses.

Named nodes, one per item type:

| node | source |
|---|---|
| `construction` | `(align …)`, `(map … onto …)`, `(through … …)`, `(perp … through …)` |
| `alignment` | `(.a onto .c)`, `(through .a)`, `(perp --l)` inside `align` |
| `axis_item` | `(--d)` under `mark`/`fold`/`reverse` |
| `flatten_element` | `(--l)`, `(--l mountain)` under `flatten` |
| `anchor_item` | `(moving …)` |
| `depth_item` | `(up to …)` |
| `placement_item` | `(over …)`, `(under …)` |
| `kind_item` | `(outside)` |
| `intent_item` | `(mountain)`, `(valley)` |
| `extent_item` | `(between … …)`, `(at …)` |
| `layer_item` | `(on …)` |
| `order_item` | `(.q over .r)` |
| `stayer_item` | `(staying …)` |
| `selection_item` | `(toward …)` |
| `output_clause` | `as --f`, `as --f!`, `into --l` |

Operands inside an item stay unstructured: a `_operand` is a run of the
existing token classes plus a parenthesised group, excluding the head keywords
and `over`. That is enough to separate `axis_item` from `order_item` (the run
stops at `over`) and from `placement_item` (which starts with it), and it
keeps this slice out of the business of writing a structural operand grammar.

The verb words move out of the `keyword` rule into `write_statement` as
anonymous tokens; `highlights.scm` matches them there. The stale entries go and
the six missing keywords are added for the token-soup path.

**Building and shipping.** `src/parser.c` and `tree-sitter-beloch.wasm` are
committed artifacts built by hand outside the repository, and the copies under
`packages/www/src/grammar/` and `packages/www/public/grammar/` are a
generation behind. The slice adds `tree-sitter` to the devshell in
`flake.nix`, a `generate` script in `packages/grammar/package.json`
(`tree-sitter generate && tree-sitter build --wasm`) and a copy step into
`packages/www/src/grammar/`, so that regenerating is one command and the
corpus test below runs against the artifact the site ships.

### Highlighting queries (`packages/www/src/grammar/highlights.scm`)

`highlight-bel.ts` maps a capture name to the CSS class `bel-<name>` and has
no rule for overlapping captures, so the queries capture each item's head
keyword rather than the whole node, leaving operands on their existing
`@point` / `@line` captures:

```scheme
(construction    ["align" "map" "through" "perp" "onto"] @construction)
(alignment       ["onto" "through" "perp"] @alignment)
(anchor_item     "moving" @anchor)
(depth_item      ["up" "to"] @depth)
(placement_item  ["over" "under"] @placement)
(kind_item       "outside" @kind)
(intent_item     ["mountain" "valley"] @intent)
(extent_item     ["between" "at"] @extent)
(layer_item      "on" @layer)
(flatten_element ["mountain" "valley"] @ray)
(order_item      "over" @order)
(stayer_item     "staying" @stayer)
(selection_item  "toward" @selection)
(output_clause   ["as" "into" "!"] @output)
```

`packages/www/src/styles/theme.css` gains the matching `.bel-anchor`,
`.bel-depth`, `.bel-placement`, `.bel-kind`, `.bel-intent`, `.bel-extent`,
`.bel-layer`, `.bel-ray`, `.bel-order`, `.bel-stayer`, `.bel-selection`,
`.bel-construction`, `.bel-alignment`, `.bel-output` classes, each in both
themes. The same
query file is copied to `packages/grammar/queries/highlights.scm`.

### Markdown rendering (`packages/www/src/lib/remark-bel.ts`)

`remarkBel` rewrites every fenced block whose language is `bel` or `beloch`
into highlighted HTML. It gains one rule: a block tagged `prelude` is removed
from the tree instead of rendered. `visit` already hands it the parent and the
index, so the prelude nodes are collected during the walk and spliced out
after it.

The pandoc path needs the same rule. `scripts/render-model.sh` renders
`spec/{MODEL,KERNEL,BELOCH,FOLD}.md` to PDF through
`scripts/model-blocks.lua`, so that filter drops a `CodeBlock` carrying the
`prelude` class as well. One clause, beside the clauses it already has for
fenced divs.

## The reference corpus test

The guard that holds the kernel and the tree-sitter grammar to `BELOCH.md`.
Every tagged block in the document is evaluated, the way
`scripts/render-figures.ts` evaluates every `::: {.figure}` body: a block that
does not fold is a block the document should not be showing.

### Marking the blocks

Fenced blocks in `spec/*.md` carry no info string today, and `remark-bel.ts`
highlights a block only when its language is `bel` or `beloch`. The example
blocks in `BELOCH.md` gain an info string; the grammar blocks stay unlabelled
and are skipped by the corpus test and by the site.

| info string | content | how it is checked |
|---|---|---|
| ```` ```bel ```` | a whole program, starting `paper square` | parses and evaluates |
| ```` ```bel prelude name=<id> ```` | a program fragment that sets up names for other blocks | parses and evaluates under its own prelude; never rendered |
| ```` ```bel frag [prelude=<id>] ```` | statements with no `paper square` of their own | the named prelude (default: `paper square`) is prepended, then parses and evaluates |
| ```` ```bel construction [prelude=<id>] ```` | one construction item per line, with a trailing comment | each line is wrapped as `mark <line>`, appended to the prelude, then parses and evaluates |

Any block of the three non-prelude kinds may carry the inline assertion lines
of the `.bel` corpus, unchanged in grammar and in meaning
(`docs/superpowers/specs/2026-07-14-beloch-inline-assertions-design.md`):

```
; assert faces = 3
; assert .ctr = (1/2, 1/2)
; assert --t is valley
; expect error "fold takes no (outside) item"
```

`; expect error` keeps its rule from the `.bel` corpus: at most one per block
and the only assertion in it, matched as a substring. That is how a negative
example is written now, and it is the same sentence a reader of
`packages/core/tests/cases/` already knows. A block with no assertion line
still has to evaluate.

### Hidden preludes

A fragment needs a program around it and a reader needs to see the fragment
alone. A `bel prelude` block carries that program: it stands in the document
where the fragments that use it begin, names itself with `name=<id>`, and is
removed before rendering, so it appears on the site and in the PDF nowhere.

- **Default.** A `frag` or `construction` block with no `prelude=` uses the
  implicit prelude `paper square`, which covers every block whose operands are
  the four corners `.a` to `.d` and the four edges.
- **Named.** `prelude=triangle` prepends the text of the block tagged
  `prelude name=triangle`. A prelude is defined before its first use in
  document order, so every runner resolves it in one pass over the file.
- **Composition.** A prelude is one block and does not itself carry a
  `prelude=`. Nesting would buy a shorter document and cost a resolution
  order that a reader of the raw markdown cannot follow.

Evaluation puts a real constraint on the author of a prelude, which is the
point of evaluating: the Constructions block needs a prelude that gives every
one of the seven examples a fold that lands on the paper, and where a
construction has more than one such fold its example carries the `toward` that
picks one. `spec/BELOCH.md` supplies those preludes; this design supplies the
mechanism.

A block's assertions belong to the block, and its prelude is invisible. The
runner evaluates prelude and body together, so a diagnostic can point into the
prelude; what is recorded for the reader is the message and, when the span
falls inside the block body, its line and column relative to that body. A span
inside the prelude is recorded as a message with no excerpt.

### The shared assertion module

`test_bel_assert.ml` holds the assertion grammar, its tokenizer and its
checker in 480 lines of test executable. The corpus runner and the build-side
capture both need them, so they move to `packages/core/tests/bel_assert.ml`
with an `.mli` exposing

```ocaml
type assertion
val extract : string -> (string * assertion) list   (* line text, parsed *)
val check : Eval.folded -> assertion -> unit        (* raises on failure *)
val expected_error : assertion list -> string option
```

`test_bel_assert.ml` keeps the corpus walk and calls into it, so the `.bel`
cases and the document blocks are checked by one implementation. The dune file
gains an explicit `(modules …)` field on every stanza in that directory, since
the shared module has to be claimed by the stanzas that use it rather than
by one of them.

### The three runners

**Kernel side.** `packages/core/tests/test_reference_corpus.ml`, an alcotest
suite declared in `packages/core/tests/dune` with
`(deps (source_tree ../../../spec))`, reading `$DUNE_SOURCEROOT/spec/BELOCH.md`
the way `test_bel_assert.ml` reads its corpora. It extracts the tagged blocks,
resolves preludes, runs
`Eval.eval_folded (Parse.parse ~filename:"BELOCH.md" src)` on each assembled
program, and applies `Bel_assert` to the result exactly as the `.bel` corpus
runner does. Calling the evaluator in process rather than shelling out to
`beloch fold` keeps the suite inside `dune runtest` and gives it the exception
rather than an exit code. About 140 lines, most of it the block extractor.

**Build side.** `packages/core/tools/blocks.ml`, a dune executable run from
`scripts/build-api-docs.sh` beside `scripts/render-figures.ts`. It evaluates
the same blocks by the same rule and writes `_build/spec/blocks.json`, one
entry per tagged block, keyed by document path and block index in document
order:

```json
{
  "spec/BELOCH.md": [
    { "index": 3, "status": "ok",
      "asserts": [{ "text": "assert faces = 3", "verified": true }] },
    { "index": 7, "status": "error",
      "message": "fold takes no (outside) item",
      "line": 2, "col": 22, "end_col": 31,
      "expected": true,
      "asserts": [] }
  ]
}
```

It is OCaml rather than an extension of `render-figures.ts` because both
things it has to produce live in OCaml: the assertion checker, now
`Bel_assert`, and the diagnostic the CLI prints, `Diagnostic.render`.
A TypeScript reimplementation of either is where the rendered hint would start
lying about what the kernel does. `_build/spec/blocks.json` sits beside
`_build/spec/figures/index.json` and has the same lifecycle: written by the
build, read by the site, absent until the build has run.

**tree-sitter side.** `packages/www/src/lib/reference-corpus.test.ts`, a
`bun test` file beside `highlight-bel.test.ts`, using the same
`web-tree-sitter` load path `highlight-bel.ts` uses. It stays parse-only: it
extracts the same blocks by the same rule, parses each block body on its own
without its prelude, and asserts `tree.rootNode.hasError === false`, for a
block carrying `; expect error` as well. A block whose program the wrong verb
rejects is well-formed item syntax, so tree-sitter must produce a clean tree
for it. That is the property that forces the union-of-heads shape into both
grammars. Prelude blocks are parsed too; they are Beloch like everything else.

The extractors are about 30 lines each in two languages, three copies in all.
To catch one drifting from the others, each asserts the block inventory it
found (a count per tag) against a constant at the top of the file, and the
constants are updated together when a block is added to `BELOCH.md`. A shared
manifest would remove the duplication and is not worth a generated file at
this size; the ceiling is noted at each constant.

### Rendering the outcome

`remark-bel.ts` reads `_build/spec/blocks.json`, with a path option beside the
one `remark-model-blocks.ts` takes for figures, and counts tagged blocks in
document order so its index matches the one the capture tool wrote. Under the
highlighted program it renders:

- for a block whose entry is `status: "error"` and `expected: true`, the
  diagnostic in the shape `Diagnostic.render` prints: an `error:` line, the
  arrow with line and column, the offending line and a caret. The renderer
  draws it from the recorded message and position against the block's own
  text, so the prelude stays out of sight.
- for each `; assert` line, the line itself marked as verified.

Three states the renderer has to handle, and all three are visible to a reader
of the site:

- no entry for the block, because `astro dev` is running ahead of the build
  script: the program alone, no hint. The site still builds.
- `status: "error"` with `expected: false`: the diagnostic, marked as a
  failure. The corpus test is what fails the build over it; the site shows
  what went wrong rather than hiding it.
- `status: "ok"` with an `expect error` assertion: the same, inverted, and the
  same division of labour.

`bun test` in `packages/www` runs in CI today. `dune runtest` does not: the
workflow builds `nix build .#beloch` and the OCaml tests run only under
`nix flake check`. The slice adds a `nix flake check` step to
`.github/workflows/deploy.yml`, so the kernel half of the corpus test runs on
every push alongside the tree-sitter half.

## Errors

Item classification, from `Items`, at parse time:

| situation | message |
|---|---|
| head the verb does not take | `` fold takes no (outside) item `` (verb and head substituted) |
| any item on `flip` | `` flip takes no items `` |
| a second item of one type | `` only one moving item per fold `` (head and verb substituted) |
| a second extent on `mark` | `` only one extent item per mark `` |
| a second selection item | `` only one toward item per flatten `` |
| a second `staying` | `` only one staying item per flatten `` |
| no axis item | `` fold needs an axis item: a construction or a crease `` (verb substituted) |
| no ray item on `flatten` | `` flatten needs at least one ray item `` |
| `mountain`/`valley` on an axis item | `` an axis item takes no mountain or valley; write (mountain) as its own item `` |
| `(mountain)` with `(over …)`/`(under …)` | `` a placed fold derives its direction; drop mountain `` (unchanged) |
| `(up to …)` with `(over …)`/`(under …)` | `` a placed fold moves the anchor flap only; up to is not supported here `` (unchanged) |
| a clause on `flip` | `` flip scores no crease, so it takes no as or into `` |

The output clause, from `Eval`:

| situation | message |
|---|---|
| `as --f` on a bound name | `` --f is bound; write as --f! to rebind `` |
| `as --f!` on a free name | `` nothing to rebind with --f!; drop the ! `` |
| `into --l` on a line | `` into needs a crease; --l is a line `` |
| `into --l` on a selection | `` into needs a crease of its own; --l is a selection from others `` |
| `into --ab` on a paper edge | `` into needs a scored crease; --ab is a paper edge `` |
| `into --l` on an unbound name | `` --l is not bound; write as --l to name a new crease `` |
| the scored material lies off `--l` | `` the material this scores lies on no segment of --l; name it with as instead `` |
| `into` on a `flatten` with an even ray count | `` flatten with an even ray count scores no new crease; drop into `` |

An even ray count closes the vertex with the given rays alone, so the write
scores no crease for `into` to add.

Sorts, from `Resolve.crease_of`, at the slot:

| situation | message |
|---|---|
| a line where a crease is wanted | `` --l is a line; the meet needs a crease `` (slot substituted: `the meet`, `the filter`, `the axis of fold`, `a flatten ray`, `free on`, `a flap operand`) |

Construction recognition, from `Axiom.classify`, at evaluation:

| situation | message |
|---|---|
| `align` alignments match no axiom | `` these alignments are not one of the seven axioms: point onto line, point onto line, through a point `` |
| `align` names fold lines | `` a construction over named fold lines is not evaluated yet `` |
| `toward` on a one-solution construction | `` this construction determines one line; drop toward `` |

Alignment kinds are rendered as `point onto point`, `point onto line`,
`line onto point`, `line onto line`, `through a point`, `perp to a line`, in
source order.

Two existing parse-time messages change wording so that every duplicate reads
the same way: `only one staying clause per flatten` becomes
`only one staying item per flatten`, and `only one {toward} per flatten`
becomes `only one toward item per flatten`. No `.bel` case asserts either
string; both appear in `SPECIFICATION.md` §4.9 and are updated there.

The four `is not a physical crease` messages are replaced by the sort error
above, which says the same thing in the language's own terms and says it at
the slot. Every other semantic message from `Eval`, `Resolve`, `Axiom`,
`Flatten_solve` and `Fold_state` is unchanged, including the ones that quote
prose syntax back at the reader (`map .c onto --ac through .a: no crease lands on the paper`,
`.p lies on a crease shared by 2 flaps; name the flap with #[...]`). An
`align` construction that fails at resolution therefore reports its prose
equivalent. Rewriting those messages around item syntax is a separate pass.

One exception: the flatten ambiguity message from `Flatten_solve` advises
`(toward .p)`.

## Acceptance

1. **Parser, one grammar.** `dune build` produces no `parser.conflicts`, so
   the union item grammar is conflict-free at one token of lookahead.
2. **Items in any order.** `test_parse` asserts that the six permutations of
   `fold (map .a onto .c) (moving .a) (mountain)` produce the same AST, and
   that `mark`, `reverse` and `flatten` accept their items in any order with
   `flatten`'s ray order preserved.
3. **Sugar is sugar.** Each of the seven axioms is written in both spellings,
   prose and `align`, with the alignments in every order, and the two agree by
   axis equality after evaluation: the same program folded through each
   spelling yields the same `Geom.line` and the same provenance tag. Axiom 7's
   two `point onto line` alignments keep source order, which is what fixes the
   implied anchor `Axiom.implied_point` returns.
4. **The align table is total.** Every alignment multiset of size one or two
   over the five kinds is either in the table or produces the "not one of the
   seven" message; the test enumerates them.
5. **Item errors.** One `.bel` case per row of the item-classification, output
   and sort error tables, under `packages/core/tests/cases/items/`, each with
   an `; expect error "…"` line.
6. **Output clause.** Cases for `as` on a free and on a bound name, `as --f!`
   on both, `into` on a `Mark`, on a `Material`, on a line, on a selection and
   on a paper edge, and `into` with an axis off every segment. The `into` case
   on a `Mark` asserts that the folded crease and the mark carry one id: the
   FOLD output holds one crease under that name and the emitter supersedes
   nothing.
7. **Sorts.** A case per slot row: a line in the meet, in a filter, in a
   `flatten` ray, as `fold`'s axis, in `free on`, in a flap operand, and in
   `into`, each asserting the sort message. And the mirror: a crease as a
   construction operand and as `mark`'s axis evaluates, since a crease
   projects to its table line.
8. **Reference corpus, kernel.** `test_reference_corpus` evaluates every
   tagged block in `BELOCH.md` under its prelude, applies `Bel_assert` to the
   result, and fails when a block does not fold, when an `; expect error`
   block succeeds or fails with the wrong message, when an `; assert` line
   does not hold, when a `prelude=` names no block, or when the block
   inventory does not match the constant.
9. **Reference corpus, tree-sitter.** `reference-corpus.test.ts` parses the
   same blocks with the shipped wasm and finds no `ERROR` node in any of them,
   `prelude` blocks and blocks carrying `; expect error` included.
10. **Blocks are captured and rendered.** `packages/core/tools/blocks.exe`
    writes an entry per tagged block into `_build/spec/blocks.json`, and
    `remark-bel`'s test asserts three renderings against a fixture: a block
    with a verified assert, a block with an expected error and its diagnostic,
    and a block with no entry, which renders as the program alone.
11. **Preludes are invisible.** A `bel prelude` block appears in neither the
    rendered site HTML nor the pandoc PDF, and no diagnostic rendered under a
    block quotes a prelude line. `remark-bel`'s test asserts the first; the
    second is checked by reading the built PDF once during the slice.
12. **Highlighting.** `highlight-bel.test.ts` gains a case asserting that
    `fold (map .a onto .c) (moving .a) (mountain)` yields a `bel-construction`
    span on `map`, a `bel-anchor` span on `moving` and a `bel-intent` span on
    `mountain`, and that `.a` still carries `data-bel-name="a"`.
13. **Geometry unchanged.** The normalised FOLD output of every `.bel` file
    under `examples/` and `packages/core/tests/cases/` is byte-identical
    before and after the rewrite (procedure under Migration), and every inline
    `; assert` and `; expect error` in those files passes unchanged except for
    the two flatten duplicate messages.
14. **Site.** `bun run build` in `packages/www` succeeds with the reduced
    content set: the four reference documents, the API docs and the landing
    page. `bun test` passes, including the landing test, which evaluates the
    bird base.
15. **Figures.** `scripts/render-figures.ts` renders all eleven `MODEL.md`
    figures with no `error` entry in `_build/spec/figures/index.json`.

## Non-goals

- Evaluating a construction over more than one fold line. `align` with named
  fold lines parses, keeps its alignments, and reports that the kernel does
  not solve it.
- `AL10` and alignments on virtual points. `BELOCH.md`'s
  `#open-multifold-syntax` stays open.
- A structural operand grammar in tree-sitter. Operands inside an item stay a
  token run; `--[…]`, `&`, `\`, `[…]` and `*` keep the colouring they have.
- Live highlighting in the playground editor. The CM6 editor has no Beloch
  language extension today and does not get one here.
- Migrating `SPECIFICATION.md` §4 into `BELOCH.md`. This slice edits the
  affected sections in place.
- Rewriting semantic error messages that quote prose construction syntax.
- The grammar-blocks documentation plugin and `remark-model-blocks.ts`.
- `packages/vscode`. The TextMate grammar targets a syntax generation that is
  already retired (`step`, `cross`, `@`, `--(`, `.(`) and its own fixtures
  assert scopes it cannot emit, so `bun run test:grammar` is red before this
  slice and stays red after it. The extension is not in CI and the site does
  not use it. Bringing it to the item syntax is its own slice, with the item
  scopes and the five fixtures in one change.
- `beloch check`, the pre-pass that would report sort and binding errors
  without running the kernel. The checks land in `Resolve` in this slice and
  the pre-pass is where they move when the scope machinery is worth lifting
  out of `Ctx`.
- Rewriting the tutorials. The five tutorial pages and the introduction are
  removed rather than carried forward (see Migration); a tutorial set written
  against the item syntax is a separate piece of work.
- Reviving `packages/core/tools/regen.ml`, which points at a deleted
  `tests/golden/` directory and a deleted `test_golden.ml`. It is dead code
  that predates the inline-assertion corpus; this slice leaves it alone.

## Migration

### Verifying that the geometry is unchanged

The repository has no golden files. The regression guards are the inline
`; assert` lines inside the `.bel` corpus, `test_eval`'s "all examples
evaluate without violations", and the `.fold` fixtures under
`packages/render-2d/*/test/fixtures/` and `packages/www/src/lib/fixtures/`,
which are checked-in inputs to render tests rather than snapshots.

The rewrite is verified by FOLD identity, not by the assertions alone:

1. `scripts/snapshot-fold.sh` gains a corpus argument, so that it covers
   `packages/core/tests/cases/` as well as `examples/`, and a normalisation
   step that removes the three source-position fields from the emitted JSON
   before writing it: the `"span"` strings under `beloch:creases` and
   `beloch:inspect`, the `"beloch:source_line"` integer per frame, and the
   `"source_line"` integer per statement. Everything else, including the
   `axiom` provenance tags and the `sources` name lists, is span-free and must
   match.
2. Run it on the tree before the rewrite into `before/`.
3. Run it after into `after/`, and require `diff -r before after` to be empty.

Pointwise comparison is not needed: the rewrite changes no geometry, no face
partition and no crease identity, so face-by-face identity is the right
assertion and the strongest one available.

The `.fold` fixtures under `packages/render-2d` and `packages/www/src/lib` are
not regenerated. They are inputs produced by hand and their content does not
depend on the surface syntax of the programs that once produced them.

### Rewriting the corpus

94 `.bel` files hold 231 write statements and 16 bare construction binds.
A hand rewrite of that many statements is where a geometry change would enter
unnoticed, so the rewrite is machine-made by `packages/core/tools/to_items.ml`,
which parses a file with the pre-change grammar and prints it back in the new
syntax, rewriting only the statement lines it recognises and leaving comments
where they are.

Four rewrite rules, three of them mechanical and one that needs the file's
bindings:

1. **Items.** `fold --d moving .b up to .c` becomes
   `fold (--d) (moving .b) (up to .c)`. One item per clause, the axis first,
   the order of the source preserved.
2. **The output clause.** `fold --f = <motion> <clauses>` becomes
   `fold <items> as --f`, and `--r = flatten <items>` becomes
   `flatten <items> as --r`. The name moves from in front of the items to
   behind them.
3. **`into` for a fold along a name.** A `fold` or `reverse` whose axis is a
   bare crease name gets `into --name`. Today such a statement repoints the
   name at the crease it scores, through `promote_crease`; an anonymous write
   binds nothing, so the clause is what preserves the meaning. Where the name
   is already `Material`, `into` names the id the fold would have used anyway
   and the collinearity check it adds is the check the bent-crease rule
   already makes, so the clause is inert there and can be dropped by hand
   afterwards.
4. **Line binds that are marked.** `--d = <construction>` followed by
   `mark --d …` collapses into one statement, `mark (<construction>) … as
   --d`. Under the two sorts a name bound by `=` stays a line and never gains
   material, so the two-statement form has no meaning left; today's
   `promote_crease` on `mark --d` is what it relied on. The tool tracks
   `=` binds per file and collapses the pair when the name is marked exactly
   once; a name marked twice keeps the first `as` and the later marks say
   `into --d`; a name never marked stays a line bind and is left alone. This
   is the one rule that reads more than one statement, and it is the one to
   read the diff for.

Then: swap the grammar, re-run the snapshot comparison above, and delete
`to_items.ml` in the same change, since it has no second use.

### Order of work

1. `lexer.ml`, `ast.ml`, `items.ml`/`items.mli`, `parser.mly`, `axiom.ml`
   and `axiom.mli` (`classify`, `tag`, `implied_point`),
   `resolve.ml`/`resolve.mli` (`crease_of`, the flap widening), `eval.ml`
   (`crease_id_for`, `into`). `dune build` green, `test_parse` rewritten onto
   alignment lists.
2. `to_items.ml`, corpus rewrite, snapshot comparison, `dune runtest` green.
3. `spec/BELOCH.md` (owner): the fence info strings, the hidden preludes and
   the inline assertions on the example blocks.
4. `bel_assert.ml`/`.mli` extracted from `test_bel_assert.ml` with the dune
   `(modules …)` fields, `test_reference_corpus.ml`, `tools/blocks.ml` and its
   step in `scripts/build-api-docs.sh`, and the error cases under
   `packages/core/tests/cases/items/`.
5. `packages/grammar`: `grammar.js`, regenerate `parser.c` and the wasm, copy
   into `packages/www/src/grammar/`, `tree-sitter` into the `flake.nix`
   devshell, the `generate` script in `package.json`.
6. `highlights.scm` in both copies, `theme.css`, `remark-bel.ts` with its
   prelude rule and its outcome rendering, `scripts/model-blocks.lua`'s
   matching prelude clause, `reference-corpus.test.ts`,
   `highlight-bel.test.ts`, `remark-bel`'s own test and its fixture.
7. Site content cut (below).
8. Documentation: `SPECIFICATION.md` Appendix A and the examples in §4.1 to
   §4.10, `MODEL.md`'s eleven figure programs, and the two snippets in
   `README.md`.
9. CI: `nix flake check` in `.github/workflows/deploy.yml`.

### Cutting the site down to the reference documents

The docs site keeps the four reference documents rendered from `spec/`
(`/model/`, `/kernel/`, `/language/`, `/output/`), the API docs under
`/api/`, and the landing page. Everything else under
`packages/www/src/content/docs` goes in this slice rather than being rewritten
into the item syntax:

- Delete `introduction.mdx` and the five files under `tutorials/`. Their ten
  `<Beloch>` bodies are evaluated by the Astro build, so leaving them in the
  old syntax would fail the build and rewriting them would be work on pages
  whose text is written against the old surface throughout.
- `astro.config.mjs`: the "Getting Started" and "Tutorials" sidebar groups go;
  "Reference" stays.
- The landing page shows the bird base and nothing else.
  `packages/www/src/lib/landing-examples.ts` keeps `HERO_SRC` and loses
  `FISH_BASE_SRC`, `KITE_SRC` and the `EXAMPLES` array; `index.astro` loses
  the example-button row. `HERO_SRC` reads
  `examples/bases/bird-base.bel` at build time through the existing
  `BELOCH_REPO_ROOT` anchor, so the landing program and the example file
  cannot drift and the `.bel` corpus already asserts on it.
- `landing-examples.test.ts` shrinks to one test: the hero evaluates and
  yields a non-empty `vertices_coords`.

`examples/bases/bird-base.bel` is rewritten to the item syntax with the rest
of the corpus, and its normalised FOLD output must match byte for byte, so the
landing page renders the same figure it renders today.

### Size of the change, in files

| package | files | of which mechanical rewrites |
|---|---|---|
| `packages/core` | 10 source, 5 test, 82 `.bel`, 2 tools (one deleted again) | 82 |
| `packages/grammar` | 3 source, 4 generated | 0 |
| `packages/www` | 5 source, 2 tests added, 1 test shrunk, 1 fixture, 1 wasm, 6 deleted pages | 0 |
| `spec` | 3 | 0 |
| `examples` | 6 | 6 |
| `scripts`, root | 5 | 0 |

About 125 files, of which about 90 are mechanical corpus rewrites produced by
`to_items.ml` and read as a diff, and six are page deletions.
