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

(* Operands are mutually recursive: a named leaf, or a selection over existing
   geometry. PSelect = meet (`--x * --y` / `.[l+]`), a point on the listed lines;
   LSelect = join/select (`--[c+]` / `.a * .b`), an existing crease/edge. A plain
   `.a` is PNamed; a plain `--l` is LNamed. *)
type point_operand =
  | PNamed of point_ref
  | PSelect of line_operand list * Error.span
    (* .[l+] and --x * --y: the point incident to all listed lines (n-ary
       meet; the lines must be concurrent) *)

and line_operand =
  | LNamed of crease_ref
  | LFilter of line_operand * filter_elt * Error.span
    (* bundle & sel (Keep) | bundle \ sel (Drop): the segments of the bundle
       incident / not incident to sel. Chains left-to-right. *)
  | LUnion of line_operand list * Error.span
    (* [a b …]: union of same-typed crease bundles *)
  | LSelect of selector list * Error.span
    (* --[c+] and .a * .b: the unique existing crease/edge incident to all
       constraints; errors on none or ambiguity (no sight-lines) *)

and filter_elt = Keep of selector | Drop of selector

and selector =
  | SelPoint of point_operand
  | SelLine of line_operand   (* grammar produces only LNamed here *)
  | SelFlap of flap_operand

and flap_operand = FByPoints of point_operand list * Error.span
  (* #(.a .b .c): the unique current flat flap containing all listed points *)

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

(* A flap-typed operand slot (ADR 0016). A point is sugar for "the flap
   carrying the point"; a line for "the flap hinged on the crease/segment"
   (usually a multi-match for `moving`, resolvable for `up to`); #(...) lists
   explicit incidence constraints. *)
type flap_arg =
  | FlapPoint of point_operand
  | FlapLine of line_operand
  | FlapSpec of flap_operand

type fold_spec = {
  moving : flap_arg option;
  up_to : flap_arg option;
  direction : direction;
}

(* A single crease in a `@collapse` statement, with its own fold direction
   (ADR pending: collapse = simultaneous multi-crease fold). *)
type collapse_elem = { cline : line_operand; cdir : direction }

type point_expr =
  | PsExpr of point_operand (* the `.name = …` binding RHS: a meet/select/named point *)

type stmt =
  | Crease of string option * axiom * fold_spec option * Error.span
  | BindBundle of string * line_operand * Error.span
      (* --x = <bundle expr>: name a crease bundle (union/filter of existing
         creases). Resolves lazily as its expression; slots coerce to one. *)
  | Point of string * point_expr * Error.span
  | Flip of Error.span
  | Def of string * param list * stmt list * Error.span
  | Apply of string option * string * arg list * Error.span
      (* Apply (Some "p1", "petal", args, span) = $p1 = apply petal(...)
         Apply (None, ...) = naked apply *)
  | Export of export_entry list option * string * Error.span
      (* None = export-all; the string is the instance name *)
  | StepMark of string * Error.span
  | FoldAlong of line_operand * fold_spec * Error.span
      (* @fold <crease> [moving f] [up to f] [mountain]: fold along existing
         material; the operand must resolve to a material crease *)
  | Collapse of collapse_elem list * (flap_arg * flap_arg) list
                * flap_arg option * Error.span
      (* @collapse <elements> [over-pairs] [standing]: simultaneous multi-
         crease fold. elements = the creases folded, each with its own
         direction; over-pairs = (upper flap, lower flap) layer-order
         constraints; standing = the flap that stays upright (unfolded). *)

type program = stmt list
