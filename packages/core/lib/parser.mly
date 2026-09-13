%{
open Ast

(* A prose construction: the alignments its spelling fixes, in the order the
   spelling fixes them, over no named fold line (ADR 0022). An `align` writes
   its own order; the two agree as sets, which is what recognition reads. *)
let prose (span : Error.span) (kinds : (alignment_kind * Error.span) list)
    (toward : point_operand option) : construction =
  {
    c_fold_lines = [];
    c_alignments =
      List.map
        (fun (k, sp) ->
          { al_fold_line = None; al_fold_line2 = None; al_kind = k; al_span = sp })
        kinds;
    c_toward = toward;
    c_span = span;
  }
%}

%token PAPER SQUARE THROUGH MAP ONTO EQ EOF PERP TOWARD MOVING MOUNTAIN VALLEY FLIP RPAREN AND UP TO FOLD_KW
%token DEF APPLY EXPORT AS BANG LBRACE RBRACE LPAREN RBRACKET AMP BACKSLASH STAR LBRACKET FLAP_BRACKET
%token FLATTEN OVER STAYING MARK BETWEEN AT UNDER REVERSE OUTSIDE
%token FREE ON FROM ALIGN INTO
%token LINE_MEMBER_OPEN POINT_MEMBER_OPEN  (* --[ / .[ : the line/point select openers *)
%token <string> POINT
%token <string> CREASE
%token <string> INSTANCE
%token <string> IDENT
%token <Q.t> NUMBER

%start <Ast.program> program

%%

program:
  | PAPER SQUARE stmts EOF { $3 }

stmts:
  | { [] }
  | stmt stmts { $1 :: $2 }

stmt:
  | body_stmt  { $1 }
  | DEF IDENT LPAREN params RPAREN LBRACE body_stmts RBRACE
      { Def ($2, $4, $7, $loc) }

body_stmts:
  | { [] }
  | body_stmt body_stmts { $1 :: $2 }

body_stmt:
  (* value binding: pure geometry, no material *)
  | CREASE EQ LPAREN construction_body RPAREN { BindLine ($1, $4, $loc) }
  | CREASE EQ bundle_expr                     { BindBundle ($1, $3, $loc) }
  (* the five writes: a verb, its items in any order, its output clause.
     Every verb takes the union of item bodies and Items classifies the list
     against the verb, so a head the verb does not take is reported by name
     at its own span. `flip items` for the same reason: `flip (moving .a)`
     reaches Items.flip's message instead of a syntax error at `(`. *)
  | MARK    items output { Items.mark    $2 $3 $loc }
  | FOLD_KW items output { Items.fold    $2 $3 $loc }
  | REVERSE items output { Items.reverse $2 $3 $loc }
  | FLATTEN items output { Items.flatten $2 $3 $loc }
  | FLIP    items output { Items.flip    $2 $3 $loc }
  | POINT EQ point_expr  { Point ($1, $3, $loc) }
  | INSTANCE EQ APPLY IDENT LPAREN args RPAREN { Apply (Some $1, $4, $6, $loc) }
  | APPLY IDENT LPAREN args RPAREN             { Apply (None, $2, $4, $loc) }
  | EXPORT LBRACE export_entries RBRACE INSTANCE { Export (Some $3, $5, $loc) }
  | EXPORT INSTANCE                              { Export (None, $2, $loc) }

(* the crease a write scores: bound to a new name, added to an existing
   crease, or left anonymous (BELOCH.md, Write statements) *)
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

(* A construction: the canonical `align` over its alignments, or one of the
   seven prose spellings, which desugar to the same record (ADR 0022). *)
construction_body:
  | ALIGN fold_line_names alignments toward_opt
      { { c_fold_lines = $2; c_alignments = $3; c_toward = $4; c_span = $loc } }
  | prose_axiom { $1 }

fold_line_names:
  |                        { [] }
  | CREASE fold_line_names { $1 :: $2 }

alignments:
  | alignment            { [ $1 ] }
  | alignment alignments { $1 :: $2 }

alignment:
  | LPAREN alignment_body RPAREN
      { let (f1, f2, k) = $2 in
        { al_fold_line = f1; al_fold_line2 = f2; al_kind = k; al_span = $loc } }

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

toward_opt:
  |                      { None }
  | TOWARD point_operand { Some $2 }

(* the seven prose spellings, each fixing its own alignment order *)
prose_axiom:
  | THROUGH point_operand point_operand
      { prose $loc [ (AlThrough $2, $loc($2)); (AlThrough $3, $loc($3)) ] None }
  | MAP point_operand ONTO point_operand
      { prose $loc [ (AlOnto (AoPoint $2, AoPoint $4), $loc) ] None }
  | MAP point_operand ONTO line_operand PERP line_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), $loc($2)); (AlPerp $6, $loc($6)) ]
          None }
  | MAP point_operand ONTO line_operand THROUGH point_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), $loc($2)); (AlThrough $6, $loc($6)) ]
          None }
  | MAP point_operand ONTO line_operand THROUGH point_operand TOWARD point_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), $loc($2)); (AlThrough $6, $loc($6)) ]
          (Some $8) }
  | MAP point_operand ONTO line_operand AND point_operand ONTO line_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), $loc($2));
            (AlOnto (AoPoint $6, AoLine $8), $loc($6)) ]
          None }
  | MAP point_operand ONTO line_operand AND point_operand ONTO line_operand TOWARD point_operand
      { prose $loc
          [ (AlOnto (AoPoint $2, AoLine $4), $loc($2));
            (AlOnto (AoPoint $6, AoLine $8), $loc($6)) ]
          (Some $10) }
  | PERP line_operand THROUGH point_operand
      { prose $loc [ (AlPerp $2, $loc($2)); (AlThrough $4, $loc($4)) ] None }
  | MAP line_operand ONTO line_operand
      { prose $loc [ (AlOnto (AoLine $2, AoLine $4), $loc) ] None }
  | MAP line_operand ONTO line_operand TOWARD point_operand
      { prose $loc [ (AlOnto (AoLine $2, AoLine $4), $loc) ] (Some $6) }

point_ref:
  | POINT { { name = $1; span = $loc } }

point_expr:
  | line_operand STAR line_operand                { PsExpr (PSelect ([ $1; $3 ], $loc)) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET  { PsExpr (PSelect ($2, $loc)) }
  | FREE ON line_operand FROM point_operand at_frac_opt
      { PsFree { line = $3; anchor = $5; t = $6; span = $loc } }

at_frac_opt:
  |           { None }
  | AT NUMBER { Some (Num.of_q $2) }

point_operand:
  | point_ref { PNamed $1 }
  | LPAREN line_operand STAR line_operand RPAREN { PSelect ([ $2; $4 ], $loc) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET { PSelect ($2, $loc) }

crease_ref:
  | CREASE { { cname = $1; cspan = $loc } }

line_operand:
  | crease_ref { LNamed $1 }
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

(* the RHS of a bundle binding: a named crease, a union, or either filtered.
   Excludes bare axioms (those are Crease binds) so `--x = …` stays unambiguous. *)
bundle_expr:
  | crease_ref { LNamed $1 }
  | LBRACKET line_list RBRACKET     { LUnion ($2, $loc) }
  | bundle_expr AMP selector        { LFilter ($1, Keep $3, $loc) }
  | bundle_expr BACKSLASH selector  { LFilter ($1, Drop $3, $loc) }

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
