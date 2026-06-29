%{
open Ast
%}

%token PAPER SQUARE THROUGH FOLD TO CROSS COLON EOF PERP
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
  | CREASE COLON axiom    { Crease (Some $1, $3, $loc) }
  | axiom                 { Crease (None, $1, $loc) }
  | POINT COLON point_expr { Point ($1, $3, $loc) }

axiom:
  | THROUGH point_ref point_ref  { Through ($2, $3) }
  | FOLD point_ref TO point_ref  { FoldOnto ($2, $4) }
  | PERP crease_ref THROUGH point_ref { Perp ($4, $2) }

point_ref:
  | POINT { { name = $1; span = $loc } }

point_expr:
  | CROSS crease_ref crease_ref { Cross ($2, $3) }

crease_ref:
  | CREASE { { cname = $1; cspan = $loc } }
