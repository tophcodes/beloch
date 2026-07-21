%{
open Ast

(* collapse: one flat parenthesised-juxtaposition chain; the statement action
   partitions it. Every item is `( ... )`-wrapped — required, not stylistic:
   a bare (unparenthesised) item would make the item-list's CREASE/POINT
   first-tokens collide with the first-tokens of the *next* statement (a
   bind `--l = ...` or point binding `.p = ...`), which is a genuine
   shift/reduce conflict at 1 token of lookahead, not just a style choice. *)
type collapse_item =
  | CElem of collapse_elem
  | COver of flap_arg * flap_arg
  | CStaying of flap_arg * Error.span
  | CToward of point_operand * Error.span

(* shared by the bound (`--r = flatten ...`) and unbound (`flatten ...`)
   productions: partitions the item list and reports a duplicate `staying`
   (or duplicate `{toward}`) at its own (second-occurrence) span, not the
   first's. elems/overs are accumulated reversed and restored with List.rev
   to keep source order. [toward] now comes from the `{toward .p}` item
   (flatten V2 surface, spec 2026-07-16-flatten-derive-v2-design.md): any
   position, at most one — the old trailing `toward` is gone. *)
let mk_flatten (name : string option) (items : collapse_item list)
    (span : Error.span) : stmt =
  let elems_rev, overs_rev, staying, toward =
    List.fold_left
      (fun (es, os, st, tw) item ->
        match item with
        | CElem e -> (e :: es, os, st, tw)
        | COver (u, l) -> (es, (u, l) :: os, st, tw)
        | CStaying (f, sp) -> (
            match st with
            | Some _ -> Error.fail sp "only one staying clause per flatten"
            | None -> (es, os, Some f, tw))
        | CToward (p, sp) -> (
            match tw with
            | Some _ -> Error.fail sp "only one {toward} per flatten"
            | None -> (es, os, st, Some p)))
      ([], [], None, None) items
  in
  Flatten (name, List.rev elems_rev, List.rev overs_rev, staying, toward, span)
%}

%token PAPER SQUARE THROUGH MAP ONTO EQ EOF PERP TOWARD MOVING MOUNTAIN VALLEY FLIP RPAREN AND UP TO FOLD_KW
%token DEF APPLY EXPORT AS BANG LBRACE RBRACE LPAREN RBRACKET AMP BACKSLASH STAR LBRACKET FLAP_BRACKET
%token FLATTEN OVER STAYING MARK BETWEEN AT
%token LINE_MEMBER_OPEN POINT_MEMBER_OPEN  (* --[ / .[ : the line/point select openers *)
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

body_stmts:
  | { [] }
  | body_stmt body_stmts { $1 :: $2 }

body_stmt:
  (* value binding: pure geometry, no material *)
  | CREASE EQ axiom      { BindLine ($1, $3, $loc) }
  | CREASE EQ bundle_expr { BindBundle ($1, $3, $loc) }
  (* mark: flat crease; Full subdivides, partial extent may record *)
  | MARK markable mark_clauses
      { let (ext, dir, lay) = $3 in Mark (None, $2, ext, dir, lay, $loc) }
  | MARK CREASE EQ axiom mark_clauses
      { let (ext, dir, lay) = $5 in Mark (Some $2, MMotion $4, ext, dir, lay, $loc) }
  (* fold: motion-fold or fold-along an existing material crease *)
  | FOLD_KW markable fold_clauses        { Fold (None, $2, $3, $loc) }
  | FOLD_KW CREASE EQ axiom fold_clauses { Fold (Some $2, MMotion $4, $5, $loc) }
  | POINT EQ point_expr  { Point ($1, $3, $loc) }
  | FLIP                 { Flip $loc }
  | INSTANCE EQ APPLY IDENT LPAREN args RPAREN { Apply (Some $1, $4, $6, $loc) }
  | APPLY IDENT LPAREN args RPAREN             { Apply (None, $2, $4, $loc) }
  | EXPORT LBRACE export_entries RBRACE INSTANCE { Export (Some $3, $5, $loc) }
  | EXPORT INSTANCE                              { Export (None, $2, $loc) }
  | FLATTEN collapse_items
      { mk_flatten None $2 $loc }
  | CREASE EQ FLATTEN collapse_items
      { mk_flatten (Some $1) $4 $loc }

markable:
  | axiom               { MMotion $1 }
  | LPAREN axiom RPAREN { MMotion $2 }  (* parens purely syntactic grouping *)
  | line_operand        { MLine $1 }

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

mark_clauses:
  | extent_opt mountain_opt layer_opt
      { ($1, (if $2 then Mountain else Valley), $3) }

extent_opt:
  |                                     { Full }
  | BETWEEN point_operand point_operand { Between ($2, $3) }
  | AT point_operand                    { At $2 }

layer_opt:
  |              { None }
  | flap_operand { Some $1 }

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
  | line_operand STAR line_operand                { PsExpr (PSelect ([ $1; $3 ], $loc)) }
  | POINT_MEMBER_OPEN line_operand_list RBRACKET  { PsExpr (PSelect ($2, $loc)) }

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

collapse_items:
  | collapse_item                { [ $1 ] }
  | collapse_item collapse_items { $1 :: $2 }

(* mv constraint marker: bare = solver-assigned (V2); mountain/valley pin it. *)
mv_opt:
  |          { MvFree }
  | MOUNTAIN { MvMountain }
  | VALLEY   { MvValley }

collapse_item:
  | LPAREN collapse_item_inner RPAREN  { $2 }
  | LBRACE TOWARD point_operand RBRACE { CToward ($3, $loc) }
      (* `{toward .p}`: any item position, at most one (mk_flatten rejects a
         second occurrence). Present = derive mode: the items are an odd set
         of given rays and this names which side of the emergent crease to
         keep. *)

collapse_item_inner:
  | line_operand mv_opt
      { CElem { cline = $1; cdir = $2 } }
  | over_flap OVER over_flap { COver ($1, $3) }
  | STAYING flap_arg         { CStaying ($2, $loc) }

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
