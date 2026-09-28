(** What a selection chose from: every candidate of a construction or a write
    and the rule that removed each one it did not keep (spec/FOLD.md, "The
    trace"). Recorded on every evaluation and written only on request. *)

type removal =
  | By_paper   (** creases no face of the state *)
  | By_toward  (** ruled out by the `toward` point *)
  | By_moving  (** ruled out by the anchor of a `fold` *)
  | By_heading  (** a direction farther from the `heading` line than another *)
  | By_moved
      (** its fold cannot move everything the construction moves at once *)
  | By_halves  (** the hinge does not cut the tip into two halves *)
  | By_bodies  (** a half of the tip has no body *)
  | By_interleaved  (** the bodies of the two halves are not separated *)
  | By_crossing  (** the reflection violates a non-crossing condition *)
  | By_opposite
      (** an emergent ray on a given ray's line, while one on a new line
          closes the vertex *)
  | By_mountains  (** more mountains on the given rays than another state *)
  | By_top  (** less of the material toward the point on top *)

type segment = Geom.point * Geom.point

(** The stage of the selection that removed a candidate (spec/MODEL.md,
    def-selection); [removal] says which item or rule did it. *)
type stage = Paper | Heading | Side | Moved | Landing

(** Where the side that folds over came from. *)
type side_from =
  | From_toward  (** opposite the side the `toward` names *)
  | From_moving  (** the side the `moving` names *)
  | Alone  (** without side items, the only side that carries out the alignments *)
  | First
      (** without side items, both sides carry them out and the first object
          of the first alignment decides *)

(** How a fold with one folding side meets one alignment. *)
type meets =
  | Moves of int  (** that object of the alignment, 0 or 1, folds onto the other *)
  | Already  (** a point on the fold line lies on its target line *)
  | Misses

type motion = { source : segment list; image : segment list }
(** What a fold moves to carry out one alignment, and where it lands: a
    point, the place of a line that lands on a point, or the part of a line
    that folds over onto a line. A point is a segment of length zero. *)

type attempt = {
  fold_side : int;
  meets : meets list;  (** one per alignment *)
  motions : motion option list;  (** one per alignment, where an object moves *)
}
(** A folding side the moved-material stage tried. *)

type candidate = {
  line : Geom.line;  (** in table coordinates *)
  removed_by : removal option;
  removed_at : stage option;
  selected : bool;
  landing : Geom.point option;
      (** where the fold moves the point of the first alignment *)
  angle : float option;  (** degrees to the `heading` line, on reaching that stage *)
  side : int option;  (** the side that folds over, where one is fixed *)
  side_from : side_from option;
  attempts : attempt list;  (** the sides the moved-material stage tried *)
  subject_folds : bool option;
      (** whether the fold folds the subject of `(x toward …)` over *)
  landed : segment list option;
      (** the material the landing stage measured, where it reached it *)
  distance : float option;  (** from [landed] to the `toward` *)
  nearest : (Geom.point * Geom.point) option;
      (** the point of [landed] and the point of the `toward` that [distance]
          lies between *)
  suggestion : string option;
      (** where several candidates remain, the item that keeps this one *)
}

type conic = { focus : Geom.point; directrix : Geom.line }
(** A parabola whose tangents the candidates are (axioms 6 and 7). *)

type region = Geom.point array list
(** Paper as it lies on the table, one polygon per face. *)

type placement = Top | Bottom | Over of region | Under of region

type terms =
  | Fold of {
      axis : Geom.line;
      side : int;  (** the sign of [a·x + b·y - c] on the moving side *)
      moving : region;
      placement : placement;
    }
  | Reverse of { axis : Geom.line; side : int; inside : bool; tip : region }
  | Flatten of { point : Geom.point }

type detail =
  | Spine of {
      spine : segment;
      halves : (region * region) option;
      bodies : (region * region) option;  (** the lower body first *)
    }
  | Fan of {
      rays : segment list;  (** the rays the program gave *)
      emergent : segment option;
      stayer : Geom.point * Geom.point;
          (** the ends of the rays that bound the stayer, counter-clockwise *)
    }

type state_candidate = {
  state : Fold_state.t option;
  detail : detail;
  removed : removal option;
  chosen : bool;
}

type entry = {
  statement : int;  (** index into the statement log *)
  frame : int;
      (** the frame the entry read, as an index into the frames: the state
          before the statement when it moves paper *)
  body : body;
}

and body = Construction of construction | Write of { terms : terms; states : state_candidate list }

(** An object of an `onto` alignment: a point, or a line's material. *)
and obj = { name : string; point : Geom.point option; segments : segment list }

and alignment = { objects : obj * obj; span : Error.span option }

and construction = {
  axiom : string;  (** the provenance tag, ["axiom1"] … ["axiom7"] *)
  toward : Geom.point option;
  toward_segments : segment list;  (** the material of a `toward` line *)
  toward_name : string option;
  subject : string option;  (** the [x] of `(x toward …)` *)
  moving_name : string option;
  moving_point : Geom.point option;
      (** where the anchor of `moving` lies, when it names a point *)
  operands : obj list;
      (** the points and lines the construction is built from, where they lie
          in the state it read *)
  heading_line : Geom.line option;
  heading_name : string option;
  alignments : alignment list;
      (** the `onto` alignments, in the order [attempts] indexes them *)
  spans : spans;
  candidates : candidate list;
  conics : conic list;
  circle : (Geom.point * Geom.point) option;
      (** axiom 6: the centre on the crease, and the point that moves *)
}

and spans = {
  alignment_spans : Error.span list;  (** every alignment, `onto` or not *)
  heading : Error.span option;
  toward_span : Error.span option;
  moving_span : Error.span option;
}

val construction : axiom:string -> conics:conic list -> construction
(** An entry with no candidates and no side items. *)

val faces_region : Fold_state.t -> ?clip:Geom.line * int -> (int -> bool) -> region
(** The table polygons of the faces the predicate holds for, each clipped to
    the given side of the line when [clip] is given; a face with no area on
    that side is left out. *)

val to_json : frame:(Fold_state.t -> Yojson.Safe.t) -> entry -> Yojson.Safe.t
(** [frame] writes a candidate state as a [foldedForm] frame. *)

val fold_terms :
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  moving:bool array ->
  Fold_state.placement ->
  terms
(** The terms of a fold that reflects the parents in [moving] across [axis]
    in the state it reads. *)

val reverse_write :
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  tip:bool array ->
  inside:bool ->
  Fold_state.spine_attempt list ->
  terms * state_candidate list
(** The terms of a reverse fold and one candidate per spine it tried. *)

val fan :
  pre:Fold_state.t ->
  post:Fold_state.t ->
  point:Geom.point ->
  rays:segment list ->
  emergent:segment option ->
  detail
(** The fan of a flatten candidate: its rays from [point] and the sector
    whose paper lies in [post] where it lay in [pre]. *)
