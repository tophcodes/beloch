%{
open Ast

(* @collapse: one flat `and`-separated chain; the statement action partitions
   it. over_flap is restricted to point/flap operands so the first token of
   each item is unambiguous: elements are `--`/`--(`/`(`-first, over pairs
   `.`/`.(`/`#(`-first, standing keyword-first. *)
type collapse_item =
  | CElem of collapse_elem
  | COver of flap_arg * flap_arg
  | CStanding of flap_arg * Error.span
%}

%token PAPER SQUARE THROUGH MAP ONTO CROSS EQ EOF PERP TOWARD AT MOVING MOUNTAIN FLIP LINE_OPEN POINT_OPEN FLAP_OPEN RPAREN AND AT_KW UP TO FOLD_KW
%token DEF APPLY EXPORT STEP AS BANG LBRACE RBRACE LPAREN RBRACKET AMP BACKSLASH STAR LBRACKET FLAP_BRACKET
%token COLLAPSE OVER STANDING
%token LINE_MEMBER_OPEN POINT_MEMBER_OPEN
%token <string> POINT
%token <string> CREASE
%token <string> INSTANCE
%token <string> IDENT

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
  | STEP IDENT { StepMark ($2, $loc) }

body_stmts:
  | { [] }
  | body_stmt body_stmts { $1 :: $2 }

body_stmt:
  | CREASE EQ LINE_OPEN point_operand point_operand RPAREN
      { Crease (Some $1, Ast.Through ($4, $5), None, $loc) }
  | CREASE EQ axiom_stmt { let (a, fs) = $3 in Crease (Some $1, a, fs, $loc) }
  | axiom_stmt           { let (a, fs) = $1 in Crease (None, a, fs, $loc) }
  | POINT EQ point_expr  { Point ($1, $3, $loc) }
  | FLIP                 { Flip $loc }
  | INSTANCE EQ APPLY IDENT LPAREN args RPAREN { Apply (Some $1, $4, $6, $loc) }
  | APPLY IDENT LPAREN args RPAREN             { Apply (None, $2, $4, $loc) }
  | EXPORT LBRACE export_entries RBRACE INSTANCE { Export (Some $3, $5, $loc) }
  | EXPORT INSTANCE                              { Export (None, $2, $loc) }
  | AT FOLD_KW line_operand fold_clauses         { FoldAlong ($3, $4, $loc) }
  | AT COLLAPSE collapse_items
      { (* fold_left over source order so a duplicate `standing` is detected
           at its own (second-occurrence) span, not the first's; elems/overs
           are accumulated reversed and restored with List.rev to keep their
           original source order. *)
        let elems_rev, overs_rev, standing =
          List.fold_left
            (fun (es, os, st) item ->
              match item with
              | CElem e -> (e :: es, os, st)
              | COver (u, l) -> (es, (u, l) :: os, st)
              | CStanding (f, sp) -> (
                  match st with
                  | Some _ ->
                      Error.fail sp "only one standing clause per @collapse"
                  | None -> (es, os, Some f)))
            ([], [], None) $3
        in
        Collapse (List.rev elems_rev, List.rev overs_rev, standing, $loc) }

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

axiom_stmt:
  | axiom                 { ($1, None) }
  | AT axiom fold_clauses { ($2, Some $3) }

fold_clauses:
  | moving_opt upto_opt mountain_opt
      { { moving = $1; up_to = $2;
          direction = (if $3 then Mountain else Valley) } }

moving_opt:
  |                 { None }
  | MOVING flap_arg { Some $2 }

upto_opt:
  |                { None }
  | UP TO flap_arg { Some $3 }

mountain_opt:
  |          { false }
  | MOUNTAIN { true }

flap_arg:
  | point_operand { FlapPoint $1 }
  | line_operand  { FlapLine $1 }
  | flap_operand  { FlapSpec $1 }

axiom:
  | THROUGH point_operand point_operand       { Through ($2, $3) }
  | MAP point_operand ONTO point_operand      { MapPoints ($2, $4) }
  | MAP point_operand ONTO line_operand PERP line_operand   { MapOntoLine ($2, $4, $6) }
  | MAP point_operand ONTO line_operand THROUGH point_operand
      { MapThrough ($2, $4, $6, None) }
  | MAP point_operand ONTO line_operand THROUGH point_operand TOWARD point_operand
      { MapThrough ($2, $4, $6, Some $8) }
  | MAP point_operand ONTO line_operand AND point_operand ONTO line_operand
      { MapBoth ($2, $4, $6, $8, None) }
  | MAP point_operand ONTO line_operand AND point_operand ONTO line_operand TOWARD point_operand
      { MapBoth ($2, $4, $6, $8, Some $10) }
  | PERP line_operand THROUGH point_operand   { Perp ($4, $2) }
  | MAP line_operand ONTO line_operand                  { MapLines ($2, $4, None) }
  | MAP line_operand ONTO line_operand TOWARD point_operand { MapLines ($2, $4, Some $6) }

point_ref:
  | POINT { { name = $1; span = $loc } }

point_expr:
  | CROSS line_operand line_operand               { Cross ($2, $3) }
  | POINT_OPEN line_operand line_operand RPAREN   { Cross ($2, $3) }
  | line_operand STAR line_operand                { Cross ($1, $3) }

point_operand:
  | point_ref { PNamed $1 }
  | POINT_OPEN line_operand line_operand RPAREN { PCross ($2, $3, $loc) }
  | LPAREN line_operand STAR line_operand RPAREN { PCross ($2, $4, $loc) }
  | POINT_MEMBER_OPEN INSTANCE IDENT RBRACKET   { PMember ($2, $3, $loc) }

crease_ref:
  | CREASE { { cname = $1; cspan = $loc } }

line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
  | crease_ref AT_KW selector { LAt ($1, [ $3 ], $loc) }
  | crease_ref AT_KW LPAREN selector AND selector RPAREN { LAt ($1, [ $4; $6 ], $loc) }
  | LINE_MEMBER_OPEN INSTANCE IDENT RBRACKET     { LMember ($2, $3, $loc) }

selector:
  | point_operand { SelPoint $1 }
  | crease_ref    { SelLine (LNamed $1) }
  | LINE_OPEN point_operand point_operand RPAREN { SelLine (LThrough ($2, $3, $loc)) }
  | flap_operand  { SelFlap $1 }

flap_operand:
  | FLAP_OPEN point_operand_list RPAREN { FByPoints ($2, $loc) }

point_operand_list:
  | point_operand                    { [ $1 ] }
  | point_operand point_operand_list { $1 :: $2 }

collapse_items:
  | collapse_item                     { [ $1 ] }
  | collapse_item AND collapse_items  { $1 :: $3 }

collapse_item:
  | collapse_elem            { CElem $1 }
  | over_flap OVER over_flap { COver ($1, $3) }
  | STANDING flap_arg        { CStanding ($2, $loc) }

collapse_elem:
  | LPAREN collapse_elem RPAREN { $2 }
  | line_operand mountain_opt
      { { cline = $1; cdir = (if $2 then Mountain else Valley) } }

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
