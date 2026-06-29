(** Abstract syntax for Beloch. Spans point into the source for diagnostics. *)

type point_ref = { name : string; span : Error.span }
type crease_ref = { cname : string; cspan : Error.span }

type axiom =
  | Through of point_ref * point_ref (* axiom 1: line through two points *)
  | MapPoints of
      point_ref * point_ref (* axiom 2: place point .x onto point .y *)
  | Perp of
      point_ref * crease_ref (* axiom 3: through .p, perpendicular to --l *)
  | MapLines of
      crease_ref * crease_ref * point_ref option (* axiom 5: line onto line *)

type direction = Valley | Mountain

(* present iff the statement was prefixed with `@` (perform the fold, keep folded) *)
type fold_spec = { moving : point_ref option; direction : direction }

type point_expr =
  | Cross of crease_ref * crease_ref (* intersection of two creases *)

type stmt =
  | Crease of string option * axiom * fold_spec option * Error.span
  | Point of string * point_expr * Error.span

type program = stmt list
