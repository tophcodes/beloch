%{
open Ast
%}

%token PAPER SQUARE THROUGH MAP ONTO CROSS COLON EOF PERP TOWARD AT MOVING MOUNTAIN FLIP LINE_OPEN POINT_OPEN RPAREN
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
  | FLIP { Flip $loc }

axiom_stmt:
  | axiom                 { ($1, None) }
  | AT axiom fold_clauses { ($2, Some $3) }

fold_clauses:
  |                               { { moving = None; direction = Valley } }
  | MOVING point_operand          { { moving = Some $2; direction = Valley } }
  | MOUNTAIN                      { { moving = None; direction = Mountain } }
  | MOVING point_operand MOUNTAIN { { moving = Some $2; direction = Mountain } }

axiom:
  | THROUGH point_operand point_operand       { Through ($2, $3) }
  | MAP point_operand ONTO point_operand      { MapPoints ($2, $4) }
  | MAP point_operand ONTO line_operand PERP line_operand   { MapOntoLine ($2, $4, $6) }
  | PERP line_operand THROUGH point_operand   { Perp ($4, $2) }
  | MAP line_operand ONTO line_operand                  { MapLines ($2, $4, None) }
  | MAP line_operand ONTO line_operand TOWARD point_operand { MapLines ($2, $4, Some $6) }

point_ref:
  | POINT { { name = $1; span = $loc } }

point_expr:
  | CROSS line_operand line_operand { Cross ($2, $3) }

point_operand:
  | point_ref { PNamed $1 }
  | POINT_OPEN line_operand line_operand RPAREN { PCross ($2, $3, $loc) }

crease_ref:
  | CREASE { { cname = $1; cspan = $loc } }

line_operand:
  | crease_ref { LNamed $1 }
  | LINE_OPEN point_operand point_operand RPAREN { LThrough ($2, $3, $loc) }
