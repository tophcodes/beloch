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
- Hard cut. The bare-keyword argument forms are removed with no compatibility
  period, every `.bel` file in the repository is rewritten, and the folded
  geometry of every example and case is unchanged.

Two places where the fixed documents disagree with each other or with the
code, resolved here and listed again under Migration:

1. `spec/BELOCH.md` states `write_stmt := [ CREASE_NAME "=" ] verb item*`
   (name before the verb) and one paragraph later gives the binding form as
   `fold --f = (map .a onto .c) (moving .a)` (name after the verb). The code
   has both: `mark`/`fold`/`reverse` bind after the verb, `flatten` binds
   before it (`--r = flatten …`). This design takes the explicit binding form,
   `verb [ CREASE_NAME "=" ] item*`, for all five verbs. `flatten`'s binding
   moves to `flatten --r = …` and the grammar line in `BELOCH.md` is
   corrected.
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
write_stmt   := verb [ CREASE_NAME "=" ] item*
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

bind_stmt    := CREASE_NAME "=" "(" construction_body ")"
              | CREASE_NAME "=" bundle_expr
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
fold    (--d) (moving .b) (up to .c)
fold    --f = (map .a onto .c) (moving .a)
reverse (map .b onto .c) (outside)
mark    (through .a .c)
mark    (map --ab onto --cd) (on #[.c]) (between .a .m) (mountain)
mark    --p = (map .a onto .c) (between .a .m)
flatten (--h & --bc) (--v & --cd) (.q over .r) (staying .a) (toward .q)
flatten --ear = (--ea) (--ec) (--eb) (toward .a)
flip
--l = (map --a onto --b toward .p)
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

One token: `"align" -> ALIGN`. No identifier in the repository is `align`, and
no `def` is named `align`, so promoting it to a keyword breaks nothing. Every
other head word is already a token: `MOVING`, `UP`, `TO`, `MOUNTAIN`,
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

Changed, two lines: `Mark`'s layer slot becomes `flap_arg option`, was
`flap_operand option`.

### `items.ml` / `items.mli` (new)

A leaf module over `Ast` and `Error`, called from the semantic actions of
`parser.mly`. No dependency on `Parser`, so the module graph stays acyclic:
`Error → Ast → Items → Parser`. It sits on the parse side and does not touch
the `Ctx → Resolve → { Axiom, Flatten_solve } → Eval` chain of ADR 0018.

```ocaml
val mark    : string option -> Ast.raw_item list -> Error.span -> Ast.stmt
val fold    : string option -> Ast.raw_item list -> Error.span -> Ast.stmt
val reverse : string option -> Ast.raw_item list -> Error.span -> Ast.stmt
val flatten : string option -> Ast.raw_item list -> Error.span -> Ast.stmt
val flip    : Ast.raw_item list -> Error.span -> Ast.stmt
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
  | MARK    bind_opt items { Items.mark    $2 $3 $loc }
  | FOLD_KW bind_opt items { Items.fold    $2 $3 $loc }
  | REVERSE bind_opt items { Items.reverse $2 $3 $loc }
  | FLATTEN bind_opt items { Items.flatten $2 $3 $loc }
  | FLIP    items          { Items.flip    $2 $loc }
  | CREASE EQ LPAREN construction_body RPAREN { BindLine ($1, $4, $loc) }
  | CREASE EQ bundle_expr                     { BindBundle ($1, $3, $loc) }

bind_opt:
  |            { None }
  | CREASE EQ  { Some $1 }

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

- After a verb, `CREASE` means a binding and `LPAREN` an item. No item body
  starts with `CREASE`, so there is no choice to make. `LBRACE` reaches the
  parser only in `def` and `export`, which no item can follow.
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

`eval.ml` loses the three-arm implied-anchor match to
`Axiom.implied_point` and gains nothing, so it stays under its current 881
lines and under the 900-line check of ADR 0018. The other two changes there
are pattern types: `BindLine`'s `axiom` becomes a `construction`, and the
`Mark` layer slot's type is a pattern variable.

`Resolve.resolve_mark_flap` takes `Ast.flap_arg option`. `Some (FlapSpec f)`
keeps today's path and its two messages; `Some (FlapPoint _ | FlapLine _)`
delegates to `Resolve.resolve_flap_cluster`, which already resolves all three
forms to a coplanar cluster. About five lines, plus the signature in
`resolve.mli`.

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
  seq('mark',    optional($._bind), repeat($._axis_item)),
  seq('fold',    optional($._bind), repeat($._axis_item)),
  seq('reverse', optional($._bind), repeat($._axis_item)),
  seq('flatten', optional($._bind), repeat($._ray_item)),
  seq('flip',                       repeat($._axis_item))),

_bind: $ => seq($.crease, '='),
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
```

`packages/www/src/styles/theme.css` gains the matching `.bel-anchor`,
`.bel-depth`, `.bel-placement`, `.bel-kind`, `.bel-intent`, `.bel-extent`,
`.bel-layer`, `.bel-ray`, `.bel-order`, `.bel-stayer`, `.bel-selection`,
`.bel-construction`, `.bel-alignment` classes, each in both themes. The same
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
| ```` ```bel reject [prelude=<id>] ```` | one statement per line, each with a trailing `; error: <text>` | each line, under the prelude, fails with a message containing `<text>`, at parse or at evaluation |

### Hidden preludes

A fragment needs a program around it and a reader needs to see the fragment
alone. A `bel prelude` block carries that program: it stands in the document
where the fragments that use it begin, names itself with `name=<id>`, and is
removed before rendering, so it appears on the site and in the PDF nowhere.

- **Default.** A `frag`, `construction` or `reject` block with no `prelude=`
  uses the implicit prelude `paper square`, which covers every block whose
  operands are the four corners `.a` to `.d` and the four edges.
- **Named.** `prelude=triangle` prepends the text of the block tagged
  `prelude name=triangle`. A prelude is defined before its first use in
  document order, so both runners resolve it in one pass over the file.
- **Composition.** A prelude is one block and does not itself carry a
  `prelude=`. Nesting would buy a shorter document and cost a resolution
  order that a reader of the raw markdown cannot follow.

Evaluation puts a real constraint on the author of a prelude, which is the
point of evaluating: the Constructions block needs a prelude that gives every
one of the seven examples a fold that lands on the paper, and where a
construction has more than one such fold its example carries the `toward` that
picks one. `spec/BELOCH.md` supplies those preludes; this design supplies the
mechanism.

### The two runners

**Kernel side.** `packages/core/tests/test_reference_corpus.ml`, an alcotest
suite declared in `packages/core/tests/dune` with
`(deps (source_tree ../../../spec))`, reading `$DUNE_SOURCEROOT/spec/BELOCH.md`
the way `test_bel_assert.ml` reads its corpora. It extracts the tagged blocks,
resolves preludes, and runs
`Eval.eval_folded (Parse.parse ~filename:"BELOCH.md" src)` on each assembled
program, which is the entry point `test_bel_assert.ml` uses. A `bel reject`
line must raise `Error.Beloch_error` with the named substring, from the parse
or from the evaluation; the runner does not care which, because the reader
does not. Calling the evaluator in process rather than shelling out to
`beloch fold` keeps the suite inside `dune runtest` and gives it the exception
rather than an exit code. About 160 lines, half of it the block extractor.

**tree-sitter side.** `packages/www/src/lib/reference-corpus.test.ts`, a
`bun test` file beside `highlight-bel.test.ts`, using the same
`web-tree-sitter` load path `highlight-bel.ts` uses. It stays parse-only: it
extracts the same blocks by the same rule, parses each block body on its own
without its prelude, and asserts `tree.rootNode.hasError === false`, for
`bel reject` blocks as well. A rejected program is well-formed item syntax
that the wrong verb takes, so tree-sitter must produce a clean tree for it.
That is the property that forces the union-of-heads shape into both grammars.
Prelude blocks are parsed too; they are Beloch like everything else.

The two extractors are about 30 lines each in two languages. To catch one
drifting from the other, each asserts the block inventory it found (a count
per tag) against a constant at the top of the file, and the two constants are
updated together when a block is added to `BELOCH.md`. A shared manifest would
remove the duplication and is not worth a generated file at this size; the
ceiling is noted at both constants.

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

Every semantic message from `Eval`, `Resolve`, `Axiom`, `Flatten_solve` and
`Fold_state` is unchanged, including the ones that quote prose syntax back at
the reader (`map .c onto --ac through .a: no crease lands on the paper`,
`.p lies on a crease shared by 2 flaps; name the flap with #[...]`). An
`align` construction that fails at resolution therefore reports its prose
equivalent. Rewriting those messages around item syntax is a separate pass.

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
5. **Item errors.** One `.bel` case per row of the item-classification errors
   table under `packages/core/tests/cases/items/`, each with an
   `; expect error "…"` line, plus the same rows as a `bel reject` block in
   `BELOCH.md`.
6. **Reference corpus, kernel.** `test_reference_corpus` evaluates every
   tagged block in `BELOCH.md` under its prelude and fails when a block does
   not fold, when a `bel reject` line succeeds or fails with the wrong
   message, when a `prelude=` names no block, or when the block inventory does
   not match the constant.
7. **Reference corpus, tree-sitter.** `reference-corpus.test.ts` parses the
   same blocks with the shipped wasm and finds no `ERROR` node in any of them,
   `bel reject` and `prelude` blocks included.
8. **Preludes are invisible.** A `bel prelude` block appears in neither the
   rendered site HTML nor the pandoc PDF. `remark-bel`'s test asserts the
   first; the second is checked by reading the built PDF once during the
   slice.
9. **Highlighting.** `highlight-bel.test.ts` gains a case asserting that
   `fold (map .a onto .c) (moving .a) (mountain)` yields a `bel-construction`
   span on `map`, a `bel-anchor` span on `moving` and a `bel-intent` span on
   `mountain`, and that `.a` still carries `data-bel-name="a"`.
10. **Geometry unchanged.** The normalised FOLD output of every `.bel` file
    under `examples/` and `packages/core/tests/cases/` is byte-identical
    before and after the rewrite (procedure under Migration), and every inline
    `; assert` and `; expect error` in those files passes unchanged except for
    the two flatten duplicate messages.
11. **Site.** `bun run build` in `packages/www` succeeds with the reduced
    content set: the four reference documents, the API docs and the landing
    page. `bun test` passes, including the landing test, which evaluates the
    bird base.
12. **Figures.** `scripts/render-figures.ts` renders all eleven `MODEL.md`
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
unnoticed, so the rewrite is machine-made:

1. Add a printer, `packages/core/tools/to_items.ml`, that parses a file with
   the pre-change grammar and prints the program back in item syntax,
   preserving comments by rewriting only the statement lines it recognises.
2. Run it over all 94 files and over the Beloch embedded in markdown
   (`MODEL.md`'s figure bodies, `README.md`), and read the diff.
3. Swap the grammar.
4. Re-run the snapshot comparison above.
5. Delete `to_items.ml` in the same change; it has no second use.

### Order of work

1. `lexer.ml`, `ast.ml`, `items.ml`/`items.mli`, `parser.mly`, `axiom.ml`
   and `axiom.mli` (`classify`, `tag`, `implied_point`),
   `resolve.ml`/`resolve.mli`, `eval.ml`. `dune build` green, `test_parse`
   rewritten onto alignment lists.
2. `to_items.ml`, corpus rewrite, snapshot comparison, `dune runtest` green.
3. `spec/BELOCH.md` (owner): the `write_stmt` production, the `flatten`
   binding example, `(toward …)` in place of `{toward …}`, the fence info
   strings, the hidden preludes and the `bel reject` block.
4. `test_reference_corpus.ml` and the item-error cases under
   `packages/core/tests/cases/items/`.
5. `packages/grammar`: `grammar.js`, regenerate `parser.c` and the wasm, copy
   into `packages/www/src/grammar/`, `tree-sitter` into the `flake.nix`
   devshell, the `generate` script in `package.json`.
6. `highlights.scm` in both copies, `theme.css`, `remark-bel.ts` and its
   prelude rule, `scripts/model-blocks.lua`'s matching clause,
   `reference-corpus.test.ts`, `highlight-bel.test.ts`.
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
| `packages/core` | 10 source, 3 test, 82 `.bel`, 1 tool (added and deleted) | 82 |
| `packages/grammar` | 3 source, 4 generated | 0 |
| `packages/www` | 5 source, 1 test added, 1 test shrunk, 1 wasm, 6 deleted pages | 0 |
| `spec` | 3 | 0 |
| `examples` | 6 | 6 |
| `scripts`, root | 5 | 0 |

About 125 files, of which about 90 are mechanical corpus rewrites produced by
`to_items.ml` and read as a diff, and six are page deletions.
