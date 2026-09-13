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
- **Open, and the one decision here worth a record of its own:** an `align`
  construction is recognised into `Ast.axiom` at parse time, so the AST keeps
  the seven-constructor form and the alignment set is a surface object. The
  alternative, carrying the alignment set into the AST and recognising it in
  `Axiom`, is weighed under Constructions below. Whichever way it goes, the
  reasoning is worth writing down before the two-fold constructions arrive and
  find the answer already made.

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
              | "{" "toward" point_operand "}"

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

bind_stmt    := CREASE_NAME "=" "(" construction_body ")"
              | CREASE_NAME "=" bundle_expr
```

`item_body` is one nonterminal, the union of every verb's item bodies. The
parser accepts any head after any verb and a second pass classifies the list
against the verb's signature. Three reasons to parse the union rather than a
per-verb item set:

- A head that does not belong to the verb gets a message naming the verb and
  the head, at the item's span, instead of `syntax error` at whatever token
  the LR automaton died on.
- The same shape can be implemented in tree-sitter and in TextMate, neither of
  which should carry the per-verb signature. One grammar, three
  implementations, and the reference corpus test (below) holds them together.
- The per-verb table then exists in exactly one place, `Items`, and a new verb
  or a new slot is an entry in it.

### Which items each verb takes

| verb | required | optional |
|---|---|---|
| `mark` | one axis item | one layer item (`on`), one extent item (`between` or `at`), one intent item (`mountain`/`valley`) |
| `fold` | one axis item | one anchor item (`moving`), one depth item (`up to`), one placement item (`mountain`, `over`, `under`) |
| `reverse` | one axis item | one anchor item (`moving`), one kind item (`outside`) |
| `flatten` | one or more ray items | order items (`over`, any number), one stayer item (`staying`), one selection item (`{toward}`) |
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

| alignment kinds | axiom | operands |
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
(`"axiom1"` … `"axiom7"`).

The kinds are a multiset, so alignment order is free. Where one kind occurs
twice, axioms 1 and 7, source order fixes the operand order: the first
`point onto line` of an axiom-7 construction is `p`, which is also the point
`Eval` reads as the implied anchor of a map fold. `toward` is accepted on
axioms 5, 6 and 7, which are the constructions with more than one candidate,
and rejected on the other four.

An alignment whose two objects have kinds outside the table, `(--l onto .p)`
for instance, produces no match and reaches the same "not one of the seven"
message as any other unrecognised set.

**Where recognition runs: at parse time, into `Ast.axiom`.** Both surfaces
produce the identical AST node, so a test can parse the two spellings of each
of the seven and compare the trees; the sugar claim is checked rather than
asserted.
`Axiom.axis_of`, the provenance record, the implied-anchor derivation and the
axiom-5 deferral are untouched. The reference corpus test (below) parses every
example in `BELOCH.md` without evaluating it, so parse-time recognition puts
the whole `align` table under that test.

The alternative, carrying the alignment set into the AST and recognising it in
`Axiom`, was rejected: it widens `Ast.axiom` to a second representation of the
same seven facts, every consumer of `Ast.axiom` has to handle both, and the
recognition error moves behind evaluation where a parse-only corpus test
cannot see it.

The cost of recognising at parse time: the alignment set is not retained, so a
formatter could not print `align` back from a tree parsed from prose. No
formatter exists and `BELOCH.md` fixes the canonical form for readers rather
than for a printer.

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
flatten (--h & --bc) (--v & --cd) (.q over .r) (staying .a) {toward .q}
flatten --ear = (--ea) (--ec) (--eb) {toward .a}
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

The statement constructors of `Ast.stmt` keep their shape. `Eval`, `Resolve`
(apart from the `on` widening), `Axiom`, `Flatten_solve`, `Spine` and
`Fold_emit` are untouched. The change is contained in the lexer, the parser,
the AST's surface types and one new module.

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

`RiConstruction` carries `axiom` because recognition has already run in the
alignment production. `alignment` is in the AST because the parser builds it,
even though no `stmt` retains one.

Changed, two lines: `Mark`'s layer slot becomes `flap_arg option`, was
`flap_operand option`.

### `items.ml` / `items.mli` (new)

A leaf module over `Ast` and `Error`, called from the semantic actions of
`parser.mly`. No dependency on `Parser`, so the module graph stays acyclic:
`Error → Ast → Items → Parser`. It sits on the parse side and does not touch
the `Ctx → Resolve → { Axiom, Flatten_solve } → Eval` chain of ADR 0018.

```ocaml
val construction :
  string list -> Ast.alignment list -> Ast.point_operand option ->
  Error.span -> Ast.axiom
(** Recognise an `align` head as one of the seven axioms. *)

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
  | LPAREN item_body RPAREN            { $2 }
  | LBRACE TOWARD point_operand RBRACE { Ast.RiSelection ($3, $loc) }

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

construction_body:
  | ALIGN fold_line_names alignments toward_opt { Items.construction $2 $3 $4 $loc }
  | prose_axiom                                 { $1 }
```

plus `alignment`, `alignments`, `fold_line_names`, `align_object` and
`toward_opt`. `prose_axiom` is today's `axiom` rule, renamed.

`flip items` rather than `flip` alone: `flip (moving .a)` then reaches
`Items.flip`'s message instead of a syntax error at `(`.

**Conflicts.** Menhir already runs with `--explain`. The decisions the
automaton has to make at one token of lookahead:

- After a verb, `CREASE` means a binding and `LPAREN`/`LBRACE` an item. No
  item body starts with `CREASE`, so there is no choice to make.
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

### `eval.ml`, `resolve.ml`

`eval.ml` is unchanged except for the `Mark` layer slot's type, which is a
pattern variable. It stays at its current 881 lines, under the 900-line check
of ADR 0018.

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
| `selection_item` | `{toward …}` |

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

### TextMate (`packages/vscode/syntaxes/beloch.tmLanguage.json`)

The grammar targets a retired syntax generation (`step`, `cross`, `@`, `--(`,
`.(`, `._temp` points) and covers none of the current verbs. It is rewritten
around begin/end patterns on `(` plus a lookahead for the head keyword, each
including `$self` so operands keep their own scopes:

| pattern begins | scope |
|---|---|
| `\((?=\s*align\b)` and `\((?=\s*(map\|through\|perp)\b)` | `meta.item.construction.beloch` |
| `\((?=\s*moving\b)` | `meta.item.anchor.beloch` |
| `\((?=\s*up\s+to\b)` | `meta.item.depth.beloch` |
| `\((?=\s*(over\|under)\b)` | `meta.item.placement.beloch` |
| `\((?=\s*outside\s*\))` | `meta.item.kind.beloch` |
| `\((?=\s*(mountain\|valley)\s*\))` | `meta.item.intent.beloch` |
| `\((?=\s*(between\|at)\b)` | `meta.item.extent.beloch` |
| `\((?=\s*on\b)` | `meta.item.layer.beloch` |
| `\((?=\s*staying\b)` | `meta.item.stayer.beloch` |
| `\((?=[^)]*\bover\b)` | `meta.item.order.beloch` |
| `\{(?=\s*toward\b)` | `meta.item.selection.beloch` |
| `\(` (last, the catch-all) | `meta.item.axis.beloch` |

Order is load-bearing: the order-item lookahead must come after the
placement lookahead (which starts with `over`) and before the catch-all. Each
pattern's `beginCaptures`/`endCaptures` carry
`punctuation.section.item.begin.beloch` / `.end.beloch`.

The keyword patterns gain `mark|fold|flatten|reverse|flip` as
`keyword.control.verb.beloch` and `align|onto|toward|moving|up|to|over|under|
outside|on|between|at|staying|valley|mountain|perp|through|map` in their
existing role scopes, and lose `cross`, `@`, `--(`, `.(`.
`language-configuration.json` gains `{}` to its bracket pairs, since
`{toward .p}` is live syntax.

**Tests.** `packages/vscode` runs `vscode-tmgrammar-test` over five fixtures
under `test/grammar/`, which assert scopes the current grammar cannot emit
(`entity.name.section.beloch`, `storage.type.beloch` for `step`), so the suite
is red before this slice touches it. All five fixtures are rewritten to the
item syntax with assertions for the new `meta.item.*` scopes, `keywords.bel`
gains the verb and head words, and `contextual.bel` loses the `step` and `@`
assertions. `packages/vscode` is not in CI; adding `bun run test:grammar` to
the workflow is one line and is listed under Acceptance.

## The reference corpus test

The guard that holds both parsers to `BELOCH.md`.

### Marking the blocks

Fenced blocks in `spec/*.md` carry no info string today, and `remark-bel.ts`
highlights a block only when its language is `bel` or `beloch`. The example
blocks in `BELOCH.md` gain an info string; the grammar blocks stay unlabelled
and are skipped by both the corpus test and the site.

| info string | content | how it is checked |
|---|---|---|
| ```` ```bel ```` | a whole program, starting `paper square` | must parse |
| ```` ```bel frag ```` | statements with no prelude | `paper square\n` is prepended, then must parse |
| ```` ```bel construction ```` | one construction item per line, with a trailing comment | each line is wrapped as `mark <line>` under the prelude, then must parse |
| ```` ```bel reject ```` | one statement per line, each with a trailing `; error: <text>` | each line must fail with a message containing `<text>` |

`bel reject` reuses the comment-assertion idea of the `.bel` corpus, where
`; expect error "<substring>"` matches by substring. It is per line because a
negative example is one statement long and a block-level tag would need one
block per message.

Parsing rather than evaluating is enough for every item error and for the
whole `align` table, because head classification, duplicate detection, slot
conflicts and axiom recognition all run inside the parse. A `bel reject` block
therefore needs no paper, no names and no geometry.

### The two runners

**Menhir side.** `packages/core/tests/test_reference_corpus.ml`, an alcotest
suite declared in `packages/core/tests/dune` with
`(deps (source_tree ../../../spec))`, reading `$DUNE_SOURCEROOT/spec/BELOCH.md`
the way `test_bel_assert.ml` reads its corpora. It extracts the tagged blocks,
calls `Parse.parse ~filename:"BELOCH.md"` on each, and for a `bel reject` line
asserts `Error.Beloch_error` with the named substring. About 120 lines,
half of it the block extractor.

**tree-sitter side.** `packages/www/src/lib/reference-corpus.test.ts`, a
`bun test` file beside `highlight-bel.test.ts`, using the same
`web-tree-sitter` load path `highlight-bel.ts` uses. It extracts the same
blocks by the same rule, parses each with the shipped wasm, and asserts
`tree.rootNode.hasError === false`, for the `bel reject` blocks as well:
a rejected program is well-formed item syntax that the wrong verb takes, so
tree-sitter must produce a clean tree for it. This is the property that forces
the union-of-heads shape in both grammars.

The two extractors are 20 lines each in two languages. To catch one drifting
from the other, each asserts the block inventory it found (a count per tag)
against a constant at the top of the file, and the two constants are updated
together when a block is added to `BELOCH.md`. A shared manifest would remove
the duplication and is not worth a generated file at this size; the ceiling is
noted at both constants.

`bun test` in `packages/www` runs in CI today. `dune runtest` does not: the
workflow builds `nix build .#beloch` and the OCaml tests run only under
`nix flake check`. The slice adds a `nix flake check` step to
`.github/workflows/deploy.yml`, so the Menhir half of the corpus test runs on
every push alongside the tree-sitter half.

## Errors

Parse-time, from `Items`:

| situation | message |
|---|---|
| head the verb does not take | `` fold takes no (outside) item `` (verb and head substituted) |
| any item on `flip` | `` flip takes no items `` |
| a second item of one type | `` only one moving item per fold `` (head and verb substituted) |
| a second extent on `mark` | `` only one extent item per mark `` |
| a second `{toward}` | `` only one {toward} item per flatten `` |
| a second `staying` | `` only one staying item per flatten `` |
| no axis item | `` fold needs an axis item: a construction or a crease `` (verb substituted) |
| no ray item on `flatten` | `` flatten needs at least one ray item `` |
| `mountain`/`valley` on an axis item | `` an axis item takes no mountain or valley; write (mountain) as its own item `` |
| `(mountain)` with `(over …)`/`(under …)` | `` a placed fold derives its direction; drop mountain `` (unchanged) |
| `(up to …)` with `(over …)`/`(under …)` | `` a placed fold moves the anchor flap only; up to is not supported here `` (unchanged) |
| `align` alignments match no axiom | `` these alignments are not one of the seven axioms: point onto line, point onto line, through a point `` |
| `align` names fold lines | `` a construction over named fold lines is not evaluated yet `` |
| `toward` on a one-solution construction | `` this construction determines one line; drop toward `` |

Alignment kinds are rendered as `point onto point`, `point onto line`,
`line onto point`, `line onto line`, `through a point`, `perp to a line`, in
source order.

Two existing parse-time messages change wording so that every duplicate reads
the same way: `only one staying clause per flatten` becomes
`only one staying item per flatten`, and `only one {toward} per flatten`
becomes `only one {toward} item per flatten`. No `.bel` case asserts either
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
3. **Sugar is sugar.** `test_parse` parses each of the seven axioms in both
   spellings, prose and `align`, with the alignments in every order, and
   asserts the resulting `Ast.axiom` values are equal. Axiom 7's two
   `point onto line` alignments are asserted to keep source order, which is
   what fixes the implied anchor.
4. **The align table is total.** Every alignment multiset of size one or two
   over the five kinds is either in the table or produces the "not one of the
   seven" message; the test enumerates them.
5. **Item errors.** One `.bel` case per row of the parse-time errors table
   under `packages/core/tests/cases/items/`, each with an
   `; expect error "…"` line, plus the same rows as a `bel reject` block in
   `BELOCH.md`.
6. **Reference corpus, Menhir.** `test_reference_corpus` parses every tagged
   block in `BELOCH.md` and fails when a block is malformed, when a `bel
   reject` line parses, or when the block inventory does not match the
   constant.
7. **Reference corpus, tree-sitter.** `reference-corpus.test.ts` parses the
   same blocks with the shipped wasm and finds no `ERROR` node in any of them,
   `bel reject` blocks included.
8. **Highlighting.** `highlight-bel.test.ts` gains a case asserting that
   `fold (map .a onto .c) (moving .a) (mountain)` yields a `bel-construction`
   span on `map`, a `bel-anchor` span on `moving` and a `bel-intent` span on
   `mountain`, and that `.a` still carries `data-bel-name="a"`.
9. **TextMate.** `bun run test:grammar` in `packages/vscode` is green on the
   five rewritten fixtures, and the workflow runs it.
10. **Geometry unchanged.** The normalised FOLD output of every `.bel` file
    under `examples/` and `packages/core/tests/cases/` is byte-identical
    before and after the rewrite (procedure under Migration), and every inline
    `; assert` and `; expect error` in those files passes unchanged except for
    the two flatten duplicate messages.
11. **Site.** `bun run build` in `packages/www` succeeds, which evaluates the
    ten `<Beloch>` bodies in the tutorials, and `bun test` passes, which
    evaluates the three landing examples.
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
2. Run it over all 94 files and over the snippets embedded in markdown and
   TypeScript, and read the diff.
3. Swap the grammar.
4. Re-run the snapshot comparison above.
5. Delete `to_items.ml` in the same change; it has no second use.

### Order of work

1. `lexer.ml`, `ast.ml`, `items.ml`/`items.mli`, `parser.mly`,
   `resolve.ml`/`resolve.mli`, `eval.ml`. `dune build` green, parser tests
   updated.
2. `to_items.ml`, corpus rewrite, snapshot comparison, `dune runtest` green.
3. `spec/BELOCH.md`: the `write_stmt` production corrected to
   `verb [ CREASE_NAME "=" ] item*`, the `flatten` binding example, the fence
   info strings, and the `bel reject` block.
4. `test_reference_corpus.ml` and the `bel reject` cases under
   `packages/core/tests/cases/items/`.
5. `packages/grammar`: `grammar.js`, regenerate `parser.c` and the wasm, copy
   into `packages/www/src/grammar/`, `flake.nix` devshell, the `generate`
   script.
6. `highlights.scm` in both copies, `theme.css`,
   `reference-corpus.test.ts`, `highlight-bel.test.ts`.
7. `packages/vscode`: the TextMate grammar, `language-configuration.json`,
   the five fixtures.
8. Documentation: `SPECIFICATION.md` Appendix A and the examples in §4.1 to
   §4.10, `MODEL.md`'s eleven figure programs,
   `packages/www/src/lib/landing-examples.ts`, the ten `<Beloch>` bodies in
   `packages/www/src/content/docs/**/*.mdx`, and the two snippets in
   `README.md`.
9. CI: `nix flake check` and `bun run test:grammar` in
   `.github/workflows/deploy.yml`.

The `.mdx` tutorial bodies and `README.md` are in the rewrite because the
Astro build evaluates the former and fails on a parse error, and because
`README.md` is the first Beloch a reader sees.

### Size of the change, in files

| package | files | of which mechanical rewrites |
|---|---|---|
| `packages/core` | 8 source, 3 test, 82 `.bel`, 1 tool (added and deleted) | 82 |
| `packages/grammar` | 3 source, 4 generated | 0 |
| `packages/www` | 3 source, 1 test added, 1 wasm, 5 `.mdx` | 5 |
| `packages/vscode` | 2 source, 5 fixtures | 5 |
| `spec` | 3 | 0 |
| `examples` | 6 | 6 |
| `scripts`, root | 4 | 0 |

About 130 files, of which about 100 are mechanical corpus rewrites produced by
`to_items.ml` and read as a diff.
