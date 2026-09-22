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

(* A construction, the read of sort line a write's axis comes from: the set
   of alignments that together determine the fold line (ADR 0022). The seven
   prose spellings desugar to this record at parse time; [Axiom.classify]
   recognises the alignment set as one of the seven axioms where a solver is
   needed. *)
type align_object = AoPoint of point_operand | AoLine of line_operand

and alignment_kind =
  | AlOnto of align_object * align_object   (* an object onto an object *)
  | AlThrough of point_operand              (* the fold line through a point *)
  | AlPerp of line_operand                  (* the fold line perp to a line *)

and alignment = {
  al_fold_line : string option;   (* CREASE_NAME in front of the first object *)
  al_fold_line2 : string option;  (* CREASE_NAME in front of the second object *)
  al_kind : alignment_kind;
  al_span : Error.span;
}

and construction = {
  c_fold_lines : string list;     (* CREASE_NAME* in the align head *)
  c_alignments : alignment list;  (* source order, one entry per alignment *)
  c_toward : point_operand option;
  c_span : Error.span;
}

type direction = Valley | Mountain

(* mark extent (spec §4). Full = the motion's whole chord (subdivides as before);
   Between/At are partial — record iff they end mid-face. *)
type extent =
  | Full
  | Between of point_operand * point_operand
  | At of point_operand

(* A flap-typed operand slot (ADR 0016). A point is sugar for "the flap
   carrying the point"; a line for "the flap hinged on the crease/segment"
   (usually a multi-match for `moving`, resolvable for `up to`); #(...) lists
   explicit incidence constraints. *)
type flap_arg =
  | FlapPoint of point_operand
  | FlapLine of line_operand
  | FlapSpec of flap_operand

(* where a placed fold's moved block lands: immediately over or under the
   target flap *)
type place_dir = PlaceOver | PlaceUnder

type fold_spec = {
  moving : flap_arg option;
  up_to : flap_arg option;
  direction : direction;
  place : (place_dir * flap_arg) option;
      (* Some: `over`/`under` given; direction is then derived and [direction]
         is ignored; the parser rejects `mountain` and `up to` beside it *)
}

(* reverse <markable> [moving <flap>] [outside]: the tip beyond the line is
   cut in two at its spine, both halves reflected, each placed next to its
   own hinge layer (inside) or on the far outside (outside). *)
type reverse_spec = { rmoving : flap_arg option; outside : bool }

(* A collapse element's M/V constraint: a bare element is
   unconstrained — the solver assigns its M/V. `mountain`/`valley`
   pin it explicitly. Distinct from [direction] (Mark/Fold's own two-state
   fold direction), which stays two-state. *)
type mv_constraint = MvFree | MvMountain | MvValley

(* A single crease in a `collapse` statement, with its own M/V constraint
   (ADR pending: collapse = simultaneous multi-crease fold). *)
type collapse_elem = { cline : line_operand; cdir : mv_constraint }

type point_expr =
  | PsExpr of point_operand (* the `.name = …` binding RHS: a meet/select/named point *)
  | PsFree of {
      line : line_operand;
      anchor : point_operand;
      t : Num.t option;
      span : Error.span;
    }
    (* `free on --l from .x [at <frac>]`: a point at fractional distance t
       (default 1/2) along the line's material chord, measured from the
       anchor endpoint. *)

(* a thing that can be creased/folded: a fresh motion, or an existing line *)
type markable =
  | MMotion of construction   (* a construction: a fresh crease line *)
  | MLine of line_operand     (* an existing material crease or bound value *)

(* The clause after a write's items, naming what becomes of the one crease
   the write scores (BELOCH.md, Write statements). *)
type output =
  | Anonymous
  | Named of string * bool * Error.span   (* as --f, [true] for the ! rebind *)
  | Into of string * Error.span           (* into --l *)

(* One parenthesised argument of a write, classified by its head only. The
   verb decides what each head means; Items holds that table. *)
type raw_item =
  | RiConstruction of construction * Error.span
  | RiLine of line_operand * mv_constraint * Error.span
  | RiMoving of flap_arg * Error.span
  | RiUpTo of flap_arg * Error.span
  | RiLetter of mv_constraint * Error.span     (* (mountain) / (valley) *)
  | RiPlace of place_dir * flap_arg * Error.span
  | RiOutside of Error.span
  | RiOn of flap_arg * Error.span
  | RiExtent of extent * Error.span            (* (between …) / (at …) *)
  | RiOrder of flap_arg * flap_arg * Error.span
  | RiStaying of flap_arg * Error.span
  | RiSelection of point_operand * Error.span

type stmt =
  | BindLine of string * construction * Error.span
      (* --l = (map .a onto .b) : bind a pure line VALUE; no material effect *)
  | Mark of output * markable * extent * direction * flap_arg option * Error.span
      (* mark (<construction>|(--l)) [(between .a .b) | (at .p)] [(mountain)]
         [(on <flap>)] [as --n | into --n]; flat crease. Full extent
         subdivides (emits F); a mid-face extent records (no subdivide). *)
  | Fold of output * markable * fold_spec * Error.span
      (* fold (<construction>|(--l)) [(moving …)][(up to …)][(mountain)] : on
         a construction, subdivide+fold; on an existing --l, fold along it. *)
  | Reverse of output * markable * reverse_spec * Error.span
      (* reverse (<construction>|(--l)) [(moving …)][(outside)]: inside/outside
         reverse fold of the tip beyond the line *)
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
  | Flatten of output * collapse_elem list * (flap_arg * flap_arg) list
                * flap_arg option * point_operand option * Error.span
      (* flatten <items>: single-vertex multi-crease fold, ONE solver
         pipeline (spec §4.9). elements = the given rays, each with an
         mv_constraint (MvFree = solver-assigned; mountain/valley = hard
         pin); over-pairs = (upper flap, lower flap) stacking constraints;
         staying = the staying flap. An odd ray count
         makes the emergent completing ray part of the solution space
         (Flatten.candidates). The realization space (candidate × Maekawa
         M/V pattern × stacking, via Collapse.collapse_all) is filtered by
         the hard constraints; the `(toward .p)` item (the point_operand
         option) selects among survivors by the three-stage rule (position
         class, min-mountain canon, centered-rank dipole). an `as` output
         binds the name to the emergent crease (when one was materialized) or the
         given-ray bundle. *)

type program = stmt list
