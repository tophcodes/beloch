(** What a selection chose from: every candidate of a construction or a write
    and the rule that removed each one it did not keep (spec/FOLD.md, "The
    trace"). Recorded on every evaluation and written only on request. *)

type removal =
  | By_paper   (** creases no face of the state *)
  | By_toward  (** ruled out by the `toward` point *)
  | By_moving  (** ruled out by the anchor of a `fold` *)
  | By_halves  (** the hinge does not cut the tip into two halves *)
  | By_bodies  (** a half of the tip has no body *)
  | By_interleaved  (** the bodies of the two halves are not separated *)
  | By_crossing  (** the reflection violates a non-crossing condition *)
  | By_opposite
      (** an emergent ray on a given ray's line, while one on a new line
          closes the vertex *)
  | By_mountains  (** more mountains on the given rays than another state *)
  | By_top  (** less of the material toward the point on top *)

type candidate = {
  line : Geom.line;  (** in table coordinates *)
  removed_by : removal option;
  selected : bool;
  landing : Geom.point option;
      (** where the fold moves the point a `toward` compares, for axioms 6
          and 7 *)
}

type conic = { focus : Geom.point; directrix : Geom.line }
(** A parabola whose tangents the candidates are (axioms 6 and 7). *)

type region = Geom.point array list
(** Paper as it lies on the table, one polygon per face. *)

type segment = Geom.point * Geom.point

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

and body =
  | Construction of {
      axiom : string;  (** the provenance tag, ["axiom1"] … ["axiom7"] *)
      toward : Geom.point option;
      candidates : candidate list;
      conics : conic list;
    }
  | Write of { terms : terms; states : state_candidate list }

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
