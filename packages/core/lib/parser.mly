%{
open Ast

(* A prose construction: the alignments its spelling fixes, in the order the
   spelling fixes them, over no named fold line (ADR 0031). An `align` writes
   its own order; the two agree as sets, which is what recognition reads. *)
let prose (span : Error.span) (kinds : (alignment_kind * Error.span) list) :
    construction =
  {
    c_fold_lines = [];
    c_alignments =
      List.map
        (fun (k, sp) ->
          { al_fold_line = None; al_fold_line2 = None; al_kind = k; al_span = sp })
        kinds;
    c_heading = None;
    c_heading_span = None;
    c_span = span;
  }

(* A part of an `align`: an alignment, or its `heading` *)
type align_part = Part_alignment of alignment | Part_heading of line_operand * Error.span

let align_body (span : Error.span) (heads : string list) (parts : align_part list)
    : construction =
  let heading = ref None in
  let alignments =
    List.filter_map
      (function
        | Part_alignment a -> Some a
        | Part_heading (l, sp) ->
            Items.slot "align" "heading" heading sp (l, sp);
            None)
      parts
  in
  if alignments = [] then Error.fail span "align needs at least one alignment";
  { c_fold_lines = heads; c_alignments = alignments;
    c_heading = Option.map fst !heading; c_heading_span = Option.map snd !heading;
    c_span = span }

(* An item of a shape body: a statement, the trim, or what a body may not
   hold, refused by name once the body is read *)
type shape_item =
  | Item_stmt of stmt
  | Item_trim of flap_arg * export_entry list option * Error.span
  | Item_annotation of Error.span
  | Item_def of Error.span

let misplaced_trim (span : Error.span) : 'a =
  Error.fail span "`trim to` is the last statement of a shape"

(* `shape name(params) { paper sheet items }`, read into its parts. The body
   ends with its trim and holds no other, no annotation and no def. *)
let shape_def ~(name : string) ~(name_span : Error.span)
    ~(params : (string * Error.span) list) ~(sheet : sheet)
    ~(items : shape_item list) ~(close : Error.span) (span : Error.span) :
    shape_def =
  let rec split acc = function
    | [] -> Error.fail close "a shape ends with `trim to`"
    | [ Item_trim (fa, ex, sp) ] -> (List.rev acc, (fa, sp), ex)
    | Item_trim (_, _, sp) :: _ -> misplaced_trim sp
    | Item_annotation sp :: _ ->
        Error.fail sp "a shape body holds no annotation"
    | Item_def sp :: _ -> Error.fail sp "a shape body holds no def"
    | Item_stmt st :: rest -> split (st :: acc) rest
  in
  let body, trim, exports = split [] items in
  Option.iter
    (List.iter (fun (e : export_entry) ->
         if e.eshadow then
           Error.fail e.espan
             "a trimmed sheet starts with no names, so a trim shadows none; drop the !"))
    exports;
  { sd_name = name; sd_name_span = name_span; sd_params = params;
    sd_sheet = sheet; sd_body = body; sd_trim = trim; sd_exports = exports;
    sd_span = span }

(* `staying` names points since ADR 0048; a flap names no sector *)
let staying_flap (span : Error.span) : 'a =
  Error.fail ~hint:"list the points: (staying .p .q)" span
    "staying takes points on the anchor, which name the sector that stays"

(* `toward` inside a construction, the spelling before ADR 0031 *)
let toward_inside (span : Error.span) : 'a =
  Error.fail ~hint:"write it as an item of the write: (toward .p)" span
    "toward selects the fold, not the line; it is an item of the write"
%}

%token PAPER SQUARE THROUGH MAP ONTO EQ EOF PERP TOWARD MOVING MOUNTAIN VALLEY FLIP RPAREN AND UP TO FOLD_KW
%token DEF APPLY EXPORT AS BANG LBRACE RBRACE LPAREN RBRACKET AMP BACKSLASH STAR LBRACKET FLAP_BRACKET
%token FLATTEN OVER STAYING MARK BETWEEN AT UNDER REVERSE OUTSIDE UNFOLD DOWN
%token FREE ON FROM ALIGN HEADING INTO
%token BY SHAPE TRIM UNIT
%token LINE_MEMBER_OPEN POINT_MEMBER_OPEN  (* --[ / .[ : the line/point select openers *)
%token <string> POINT
%token <string> CREASE
%token <string> INSTANCE
%token <string> IDENT
%token <Q.t> NUMBER
%token <string option * string> ANNOT  (* @key / @ns:key *)
%token <string> TEXT
%token NEWLINE                         (* the end of an annotation's line *)

%start <Ast.program> program
%start <Ast.annotation list * (string * Error.span) option * Ast.shape_def list> library

%%

(* The annotations at the head of a file, before `unit`, its shapes and
   `paper`, belong to the statement after them like any other; they lead
   [p_stmts]. *)
program:
  | head_annotations unit_decl shape_defs PAPER sheet stmts EOF
      { { p_unit = $2; p_shapes = $3; p_sheet = $5;
          p_stmts = List.map (fun a -> Annotation a) $1 @ $6 } }

(* a file of shapes alone, read as the shapes a program sees before its own *)
library:
  | head_annotations unit_decl shape_defs EOF { ($1, $2, $3) }

head_annotations:
  | { [] }
  | annotation head_annotations { $1 :: $2 }

unit_decl:
  |            { None }
  | UNIT IDENT { Some ($2, $loc($2)) }

shape_defs:
  | { [] }
  | shape_def shape_defs { $1 :: $2 }

shape_def:
  | SHAPE IDENT LPAREN shape_params RPAREN LBRACE PAPER sheet shape_items RBRACE
      { shape_def ~name:$2 ~name_span:$loc($2) ~params:$4 ~sheet:$8 ~items:$9
          ~close:$loc($10) $loc }

shape_params:
  | { [] }
  | IDENT shape_params { ($1, $loc($1)) :: $2 }

shape_items:
  | { [] }
  | shape_item shape_items { $1 :: $2 }

shape_item:
  | body_stmt                  { Item_stmt $1 }
  | TRIM TO flap_arg           { Item_trim ($3, None, $loc) }
  | TRIM TO flap_arg LBRACE export_entries RBRACE
                               { Item_trim ($3, Some $5, $loc) }
  | annotation                 { Item_annotation $1.a_span }
  | DEF IDENT LPAREN params RPAREN LBRACE body_stmts RBRACE { Item_def $loc }

sheet:
  | SQUARE              { SSquare (None, $loc) }
  | SQUARE number       { SSquare (Some $2, $loc) }
  | IDENT numbers       { SShape ($1, $2, $loc) }

numbers:
  | { [] }
  | number numbers { $1 :: $2 }

number:
  | NUMBER { NLit ($1, $loc) }
  | IDENT  { NParam ($1, $loc) }

(* `trim to` outside a shape body: refused where it stands *)
trim_elsewhere:
  | TRIM TO flap_arg { misplaced_trim $loc }
  | TRIM TO flap_arg LBRACE export_entries RBRACE { misplaced_trim $loc }

stmts:
  | { [] }
  | stmt stmts { $1 :: $2 }
  | annotation stmts { Annotation $1 :: $2 }
  | trim_elsewhere stmts { $1 :: $2 }

stmt:
  | body_stmt  { $1 }
  | DEF IDENT LPAREN params RPAREN LBRACE body_stmts RBRACE
      { Def ($2, $4, $7, $loc) }

body_stmts:
  | { [] }
  | body_stmt body_stmts { $1 :: $2 }
  | annotation body_stmts { Annotation $1 :: $2 }
  | trim_elsewhere body_stmts { $1 :: $2 }

(* docs/reference/BELOCH-ANNOTATIONS.md. Which key takes which arguments is checked
   after parsing (Annotation.check), so a key is a name the grammar does
   not reserve. *)
annotation:
  | ANNOT annot_args NEWLINE
      { let (ns, key) = $1 in
        { a_ns = ns; a_key = key; a_args = $2; a_span = $loc } }

annot_args:
  | { [] }
  | annot_arg annot_args { $1 :: $2 }

annot_arg:
  | point_operand                    { { av = AvPoint $1; av_span = $loc } }
  | line_operand                     { { av = AvLine $1; av_span = $loc } }
  | flap_operand                     { { av = AvFlap $1; av_span = $loc } }
  | LPAREN construction_body RPAREN  { { av = AvConstruction $2; av_span = $loc } }
  | TEXT                             { { av = AvText $1; av_span = $loc } }
  | NUMBER                           { { av = AvNumber $1; av_span = $loc } }
  | IDENT                            { { av = AvWord $1; av_span = $loc } }
  | UP                               { { av = AvWord "up"; av_span = $loc } }
  | DOWN                             { { av = AvWord "down"; av_span = $loc } }

body_stmt:
  (* value binding: pure geometry, no material *)
  | CREASE EQ LPAREN construction_body RPAREN items
      { Items.bind $1 $4 $6 $loc }
  (* a bind takes the line operands an item takes, parenthesized or not; the
     parentheses of the construction form are the construction's, not the
     binding's. *)
  | CREASE EQ line_operand                    { BindBundle ($1, $3, $loc) }
  (* the six writes: a verb, its items in any order, its output clause.
     Every verb takes the union of item bodies and Items classifies the list
     against the verb, so a head the verb does not take is reported by name
     at its own span. `flip items` for the same reason: `flip (moving .a)`
     reaches Items.flip's message instead of a syntax error at `(`. *)
  | MARK    items output { Items.mark    $2 $3 $loc }
  | FOLD_KW items output { Items.fold    $2 $3 $loc }
  | REVERSE items output { Items.reverse $2 $3 $loc }
  | UNFOLD  items output { Items.unfold  $2 $3 $loc }
  | FLATTEN items output { Items.flatten $2 $3 $loc }
  | FLIP    items output { Items.flip    $2 $3 $loc }
  | POINT EQ point_expr  { Point ($1, $3, $loc) }
  | INSTANCE EQ APPLY IDENT LPAREN args RPAREN { Apply (Some $1, $4, $6, $loc) }
  | APPLY IDENT LPAREN args RPAREN             { Apply (None, $2, $4, $loc) }
  | EXPORT LBRACE export_entries RBRACE INSTANCE { Export (Some $3, $5, $loc) }
  | EXPORT INSTANCE                              { Export (None, $2, $loc) }

(* the crease a write scores: bound to a new name, added to an existing
   crease, or left anonymous (BELOCH-WRITES.md) *)
output:
  |                    { Ast.Anonymous }
  | AS CREASE bang_opt { Ast.Named ($2, $3, $loc) }
  | INTO CREASE        { Ast.Into ($2, $loc) }

items:
  |            { [] }
  | item items { $1 :: $2 }

(* The parentheses around an item carry the grammar. Without them the item
   list's CREASE/POINT first-tokens collide with the first-tokens of the
   *next* statement (a bind `--l = ...` or a point binding `.p = ...`),
   which is a shift/reduce conflict at 1 token of lookahead. *)
item:
  | LPAREN item_body RPAREN { $2 }

(* the union of every verb's item bodies; Items holds the per-verb table *)
item_body:
  | construction_body                   { Ast.RiConstruction ($1, $loc) }
  | line_operand mv_opt                 { Ast.RiLine ($1, $2, $loc) }
  | MOVING flap_arg                     { Ast.RiMoving ($2, $loc) }
  | MOVING flap_arg UP                  { Ast.RiMovingDir ($2, true, $loc) }
  | MOVING flap_arg DOWN                { Ast.RiMovingDir ($2, false, $loc) }
  | UP TO flap_arg                      { Ast.RiUpTo ($3, $loc) }
  | MOUNTAIN                            { Ast.RiLetter (MvMountain, $loc) }
  | VALLEY                              { Ast.RiLetter (MvValley, $loc) }
  | OVER flap_arg                       { Ast.RiPlace (PlaceOver, $2, $loc) }
  | UNDER flap_arg                      { Ast.RiPlace (PlaceUnder, $2, $loc) }
  | OUTSIDE                             { Ast.RiOutside $loc }
  | ON flap_arg                         { Ast.RiOn ($2, $loc) }
  | BETWEEN point_operand point_operand { Ast.RiExtent (Between ($2, $3), $loc) }
  | AT point_operand                    { Ast.RiExtent (At $2, $loc) }
  | STAYING point_operand_list          { Ast.RiStaying ($2, $loc) }
  | STAYING flap_operand                { staying_flap $loc($2) }
  | over_flap OVER over_flap            { Ast.RiOrder ($1, $3, $loc) }
  | TOWARD toward_target                { Ast.RiSelection ({ target = $2; subject = None }, $loc) }
  | point_operand TOWARD toward_target
      { Ast.RiSelection ({ target = $3; subject = Some (AoPoint $1) }, $loc) }
  | line_operand TOWARD toward_target
      { Ast.RiSelection ({ target = $3; subject = Some (AoLine $1) }, $loc) }

(* what a `toward` names: a point, or a line whose side it lies on *)
toward_target:
  | point_operand { TowardPoint $1 }
  | line_operand  { TowardLine $1 }

params:
  | { [] }
  | param params { $1 :: $2 }

param:
  | POINT  { { pkind = `Point; pname = $1; pspan = $loc } }
  | CREASE { { pkind = `Line;  pname = $1; pspan = $loc } }

args:
  | { [] }
  | arg args { $1 :: $2 }

arg:
  | point_operand { APoint $1 }
  | line_operand  { ALine $1 }

flap_arg:
  | point_operand { FlapPoint $1 }
  | line_operand  { FlapLine $1 }
  | flap_operand  { FlapSpec $1 }

(* A construction: the canonical `align` over its parts, or one of the seven
   prose spellings, which desugar to the same record (ADR 0031). A `toward`
   in either place is the spelling before that record and is refused with
   its new place. *)
construction_body:
  | ALIGN fold_line_names align_parts { align_body $loc $2 $3 }
  | ALIGN fold_line_names align_parts TOWARD point_operand { toward_inside $loc($4) }
  | prose_axiom { $1 }
  | prose_axiom TOWARD point_operand { toward_inside $loc($2) }

fold_line_names:
  |                        { [] }
  | CREASE fold_line_names { $1 :: $2 }

align_parts:
  | align_part             { [ $1 ] }
  | align_part align_parts { $1 :: $2 }

align_part:
  | LPAREN alignment_body RPAREN
      { let (f1, f2, k) = $2 in
        Part_alignment
          { al_fold_line = f1; al_fold_line2 = f2; al_kind = k; al_span = $loc } }
  | LPAREN HEADING line_operand RPAREN { Part_heading ($3, ($startpos($2), $endpos($3))) }

(* The fold-line prefix is left-factored into every alternative: an object
   can itself begin with a crease name, so an optional leading CREASE would
   need two tokens of lookahead and is a shift/reduce conflict. `align_side`
   splits the objects into those that cannot begin with a crease name and
   those that do, and the decision falls to one token. *)
alignment_body:
  | THROUGH point_operand        { (None, None, AlThrough $2) }
  | PERP line_operand            { (None, None, AlPerp $2) }
  | CREASE THROUGH point_operand { (Some $1, None, AlThrough $3) }
  | CREASE PERP line_operand     { (Some $1, None, AlPerp $3) }
  | align_side ONTO align_side
      { let (f1, o1) = $1 and (f2, o2) = $3 in (f1, f2, AlOnto (o1, o2)) }

align_side:
  | align_object           { (None, $1) }
  | crease_object          { (None, AoLine $1) }
  | CREASE align_object    { (Some $1, $2) }
  | CREASE crease_object   { (Some $1, AoLine $2) }

(* an object whose first token is not a crease name *)
align_object:
  | point_operand { AoPoint $1 }
  | line_object   { AoLine $1 }

line_object:
  | LINE_MEMBER_OPEN select_constraints RBRACKET { LSelect ($2, $loc) }
  | point_operand STAR point_operand { LSelect ([ SelPoint $1; SelPoint $3 ], $loc) }
  | LBRACKET line_list RBRACKET      { LUnion ($2, $loc) }
  | line_object AMP selector         { LFilter ($1, Keep $3, $loc) }
  | line_object BACKSLASH selector   { LFilter ($1, Drop $3, $loc) }

(* a crease name, filtered or not *)
crease_object:
  | crease_ref                        { LNamed $1 }
  | crease_object AMP selector        { LFilter ($1, Keep $3, $loc) }
  | crease_object BACKSLASH selector  { LFilter ($1, Drop $3, $loc) }

(* the seven prose spellings, each fixing its own alignment order *)
prose_axiom:
  | THROUGH point_operand point_operand
      { prose $loc [ (AlThrough $2, $loc($2)); (AlThrough $3, $loc($3)) ] }
  | MAP point_operand ONTO point_operand
      { prose $loc [ (AlOnto (AoPoint $2, AoPoint $4), ($startpos($2), $endpos($4))) ] }
  | MAP point_operand ONTO line_operand PERP line_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), ($startpos($2), $endpos($4)));
            (AlPerp $6, ($startpos($5), $endpos($6))) ] }
  | MAP point_operand ONTO line_operand THROUGH point_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), ($startpos($2), $endpos($4)));
            (AlThrough $6, ($startpos($5), $endpos($6))) ] }
  | MAP point_operand ONTO line_operand AND point_operand ONTO line_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), ($startpos($2), $endpos($4)));
            (AlOnto (AoPoint $6, AoLine $8), ($startpos($6), $endpos($8))) ] }
  | PERP line_operand THROUGH point_operand
      { prose $loc
          [ (AlPerp $2, ($startpos($1), $endpos($2)));
            (AlThrough $4, ($startpos($3), $endpos($4))) ] }
  | MAP line_operand ONTO line_operand
      { prose $loc [ (AlOnto (AoLine $2, AoLine $4), ($startpos($2), $endpos($4))) ] }

point_ref:
  | POINT { { name = $1; span = $loc } }

point_expr:
  | line_operand STAR line_operand                { PsExpr (PSelect ([ $1; $3 ], $loc)) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET  { PsExpr (PSelect ($2, $loc)) }
  | FREE ON line_operand FROM point_operand at_frac_opt
      { PsFree { line = $3; anchor = $5; pos = $6; span = $loc } }

at_frac_opt:
  |           { None }
  | AT number { Some (FreeAt $2) }
  | BY number { Some (FreeBy $2) }

point_operand:
  | point_ref { PNamed $1 }
  | LPAREN line_operand STAR line_operand RPAREN { PSelect ([ $2; $4 ], $loc) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET { PSelect ($2, $loc) }
  | LPAREN point_operand RPAREN { $2 }

crease_ref:
  | CREASE { { cname = $1; cspan = $loc } }

line_operand:
  | crease_ref { LNamed $1 }
  | LPAREN line_operand RPAREN { $2 }
  | LINE_MEMBER_OPEN select_constraints RBRACKET { LSelect ($2, $loc) }
  | point_operand STAR point_operand { LSelect ([ SelPoint $1; SelPoint $3 ], $loc) }
  | line_operand AMP selector       { LFilter ($1, Keep $3, $loc) }
  | line_operand BACKSLASH selector { LFilter ($1, Drop $3, $loc) }
  | LBRACKET line_list RBRACKET     { LUnion ($2, $loc) }

line_list:
  | line_operand           { [ $1 ] }
  | line_operand line_list { $1 :: $2 }

select_constraints:
  | selector                    { [ $1 ] }
  | selector select_constraints { $1 :: $2 }

line_operand_list:
  | line_operand                   { [ $1 ] }
  | line_operand line_operand_list { $1 :: $2 }

selector:
  | point_operand { SelPoint $1 }
  | crease_ref    { SelLine (LNamed $1) }
  | flap_operand  { SelFlap $1 }

flap_operand:
  | FLAP_BRACKET point_operand_list RBRACKET { FByPoints ($2, $loc) }

point_operand_list:
  | point_operand                    { [ $1 ] }
  | point_operand point_operand_list { $1 :: $2 }

(* mv constraint marker: bare = solver-assigned (V2); mountain/valley pin it. *)
mv_opt:
  |          { MvFree }
  | MOUNTAIN { MvMountain }
  | VALLEY   { MvValley }

(* points and #(...) only — bare crease names would collide with elements *)
over_flap:
  | point_operand { FlapPoint $1 }
  | flap_operand  { FlapSpec $1 }

export_entries:
  | export_entry                { [ $1 ] }
  | export_entry export_entries { $1 :: $2 }

export_entry:
  | export_name bang_opt as_opt
      { let (k, n) = $1 in
        (match $3 with
         | Some (k', _) when k' <> k ->
             Error.fail $loc "export rename must keep the kind"
         | _ -> ());
        { ekind = k; esrc = n; eshadow = $2;
          erename = Option.map snd $3; espan = $loc } }

export_name:
  | POINT  { (`Point, $1) }
  | CREASE { (`Line, $1) }

bang_opt:
  |      { false }
  | BANG { true }

as_opt:
  |                { None }
  | AS export_name { Some $2 }
