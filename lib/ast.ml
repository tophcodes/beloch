(** Abstract syntax for Beloch. Spans point into the source for diagnostics. *)

type point_ref = { name : string; span : Error.span }
type crease_ref = { cname : string; cspan : Error.span }

type param = { pkind : [ `Point | `Line ]; pname : string; pspan : Error.span }

type export_entry = {
  ekind : [ `Point | `Line ];
  esrc : string;            (* member name in the instance *)
  eshadow : bool;           (* ! present *)
  erename : string option;  (* as-target, sans sigil *)
  espan : Error.span;
}

(* Operands are mutually recursive: a named leaf, or an inline construction.
   PCross = inline `cross` (point at two creases); LThrough = inline `through`
   (line through two points). A plain `.a` is PNamed; a plain `--l` is LNamed. *)
type point_operand =
  | PNamed of point_ref
  | PCross of line_operand * line_operand * Error.span
  | PMember of string * string * Error.span  (* instance, member *)

and line_operand =
  | LNamed of crease_ref
  | LThrough of point_operand * point_operand * Error.span
  | LMember of string * string * Error.span  (* instance, member *)

type arg = APoint of point_operand | ALine of line_operand

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
  | Def of string * param list * stmt list * Error.span
  | Apply of string option * string * arg list * Error.span
      (* Apply (Some "p1", "petal", args, span) = $p1 = apply petal(...)
         Apply (None, ...) = naked apply *)
  | Export of export_entry list option * string * Error.span
      (* None = export-all; the string is the instance name *)
  | StepMark of string * Error.span

type program = stmt list
