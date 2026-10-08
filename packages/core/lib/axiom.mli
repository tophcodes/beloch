(** Axiom construction: the seven Huzita-Justin axioms and the selection
    among their candidates (ADR 0031). Every stateful function takes
    [(ctx : Ctx.ctx)] as its first parameter. *)

type classified =
  | Ax1 of Ast.point_operand * Ast.point_operand
  | Ax2 of Ast.point_operand * Ast.point_operand
  | Ax3 of Ast.point_operand * Ast.line_operand
  | Ax4 of Ast.point_operand * Ast.line_operand * Ast.line_operand
  | Ax5 of Ast.line_operand * Ast.line_operand
  | Ax6 of Ast.point_operand * Ast.line_operand * Ast.point_operand
  | Ax7 of
      Ast.point_operand * Ast.line_operand * Ast.point_operand * Ast.line_operand
        (** A construction recognized as one of the seven axioms, carrying the
            operands in the roles its solver reads them (ADR 0031). *)

val classify : Ast.construction -> classified
(** Recognize the alignment set as one of the seven, by the multiset of its
    alignment kinds. Fails naming the alignments when the set matches none of
    them, when the head names fold lines, and when a construction that
    determines one line names an `heading`. Order-insensitive across kinds;
    where a kind repeats, source order fixes the operand roles. *)

val tag : classified -> string
(** The [provenance] tag, ["axiom1"] … ["axiom7"]. *)

val implied_point : classified -> Ast.point_operand option
(** The point a map construction moves, which a `fold` takes as its anchor
    when the program names no `moving`: the first operand of axioms 2, 6 and
    7, and [None] for the rest. Takes the classification {!axis_of} hands
    back, so a construction is recognized once per statement. *)

type pending
(** A construction's candidates in the current state, with what it moves,
    waiting for the side items of the statement that reads it. *)

val axis_of :
  ?trace:bool -> Ctx.ctx -> Error.span -> Ast.construction -> classified * pending
(** Recognize the construction with {!classify} and solve it against the
    current table positions. Fails where no candidate exists at all. *)

type chosen = {
  line : Geom.line;
  fold_side : int option;
      (** the sign of the side that folds over, when `toward` or a moved
          line fixes it; [None] leaves the side to the anchor *)
  sources : string list;  (** [provenance] *)
}

val select :
  ?trace:bool -> Ctx.ctx -> Error.span -> pending -> fold:bool -> Ast.sides -> chosen
(** Keep one candidate (docs/reference/MODEL.md, def-selection): those that cross the
    paper, those nearest in direction to the `heading`, those whose fold
    carries out every alignment with the side that stays named by `toward`
    or the side that folds over named by `moving`, and among several the
    one that lands the objects of its alignments nearest the `toward`. Fails naming the
    stage that left none or several, and where `toward` and `moving` name
    the same side. [fold] asks for a side the fold can take, which a moved
    line lying across the fold line does not give. Records the candidates in
    the trace unless [trace] is [false]. *)

val fold_side_of_line : Ctx.ctx -> Error.span -> Geom.line -> Ast.sides -> int option
(** The side that folds over along an axis that is no construction: the one
    opposite the `toward`, checked against `moving` when both are given. *)
