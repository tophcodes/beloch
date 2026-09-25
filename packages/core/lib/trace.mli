(** What a selection chose from: every candidate of a construction and the
    rule that removed each one it did not keep (spec/FOLD.md, "The trace").
    Recorded on every evaluation and written only on request. *)

type removal =
  | By_paper   (** creases no face of the state *)
  | By_toward  (** ruled out by the `toward` point *)
  | By_moving  (** ruled out by the anchor of a `fold` *)

type candidate = {
  line : Geom.line;  (** in table coordinates *)
  removed_by : removal option;
  selected : bool;
}

type conic = { focus : Geom.point; directrix : Geom.line }
(** A parabola whose tangents the candidates are (axioms 6 and 7). *)

type entry = {
  statement : int;  (** index into the statement log *)
  frame : int;
      (** the frame the construction read, as an index into the frames: the
          state before the fold when the statement folds *)
  axiom : string;   (** the provenance tag, ["axiom1"] … ["axiom7"] *)
  toward : Geom.point option;
  candidates : candidate list;
  conics : conic list;
}

val to_json : entry -> Yojson.Safe.t
