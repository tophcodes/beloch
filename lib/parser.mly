%{
open Ast
%}

%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD AT MOVING MOUNTAIN
%token <string> POINT
%token <string> CREASE

%start <Ast.program> program

%%

program:
  | PAPER SQUARE stmts EOF { $3 }

stmts:
  | { [] }
  | stmt stmts { $1 :: $2 }

stmt:
  | CREASE COLON axiom_stmt { let (a, fs) = $3 in Crease (Some $1, a, fs, $loc) }
  | axiom_stmt             { let (a, fs) = $1 in Crease (None, a, fs, $loc) }
  | POINT COLON point_expr { Point ($1, $3, $loc) }

axiom_stmt:
  | axiom                 { ($1, None) }
  | AT axiom fold_clauses { ($2, Some $3) }

fold_clauses:
  |                           { { moving = None; direction = Valley } }
  | MOVING point_ref          { { moving = Some $2; direction = Valley } }
  | MOUNTAIN                  { { moving = None; direction = Mountain } }
  | MOVING point_ref MOUNTAIN { { moving = Some $2; direction = Mountain } }

axiom:
  | THROUGH point_ref point_ref       { Through ($2, $3) }
  | MAP point_ref ONTO point_ref      { MapPoints ($2, $4) }
  | PERP crease_ref THROUGH point_ref { Perp ($4, $2) }
  | MAP crease_ref ONTO crease_ref                  { MapLines ($2, $4, None) }
  | MAP crease_ref ONTO crease_ref TOWARD point_ref { MapLines ($2, $4, Some $6) }

point_ref:
  | POINT { { name = $1; span = $loc } }

point_expr:
  | CROSS crease_ref crease_ref { Cross ($2, $3) }

crease_ref:
  | CREASE { { cname = $1; cspan = $loc } }
