(** Abstract syntax for Beloch v0.0. Spans point into the source for diagnostics. *)

type point_ref = { name : string; span : Error.span }
type crease_ref = { cname : string; cspan : Error.span }

type axiom =
  | Through of point_ref * point_ref   (* axiom 1: line through two points *)
  | FoldOnto of point_ref * point_ref  (* axiom 2: place .x onto .y *)
  | Perp of point_ref * crease_ref     (* axiom 3: through .p, perpendicular to --l *)

type point_expr = Cross of crease_ref * crease_ref  (* intersection of two creases *)

type stmt =
  | Crease of string option * axiom * Error.span  (* optional name *)
  | Point of string * point_expr * Error.span

type program = stmt list
