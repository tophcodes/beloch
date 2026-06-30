(** Abstract syntax for Beloch. Spans point into the source for diagnostics. *)

type point_ref = { name : string; span : Error.span }
type crease_ref = { cname : string; cspan : Error.span }

(* Operands are mutually recursive: a named leaf, or an inline construction.
   PCross = inline `cross` (point at two creases); LThrough = inline `through`
   (line through two points). A plain `.a` is PNamed; a plain `--l` is LNamed. *)
type point_operand =
  | PNamed of point_ref
  | PCross of line_operand * line_operand * Error.span

and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span

type axiom =
  | Through of point_operand * point_operand (* axiom 1 *)
  | MapPoints of point_operand * point_operand (* axiom 2 *)
  | Perp of point_operand * line_operand (* axiom 3: through .p, perp to --l *)
  | MapOntoLine of point_operand * line_operand * line_operand (* axiom 4 *)
  | MapLines of line_operand * line_operand * point_operand option (* axiom 5 *)
  | MapThrough of
      point_operand * line_operand * point_operand * point_operand option
    (* axiom 6: fold .p onto --d, crease through .p', optional `toward` selector *)
  | MapBoth of
      point_operand * line_operand * point_operand * line_operand * point_operand option
    (* axiom 7: fold .p onto --d AND .q onto --e simultaneously, optional toward *)

type direction = Valley | Mountain
type fold_spec = { moving : point_operand option; direction : direction }

type point_expr =
  | Cross of line_operand * line_operand (* the `.name:` binding RHS *)

type stmt =
  | Crease of string option * axiom * fold_spec option * Error.span
  | Point of string * point_expr * Error.span
  | Flip of Error.span

type program = stmt list
