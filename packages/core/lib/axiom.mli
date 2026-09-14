(** Axiom construction: the seven Huzita-Justin axioms and the axiom-5
    bisector-selection path. Every stateful function takes
    [(ctx : Ctx.ctx)] as its first parameter. *)

type classified =
  | Ax1 of Ast.point_operand * Ast.point_operand
  | Ax2 of Ast.point_operand * Ast.point_operand
  | Ax3 of Ast.point_operand * Ast.line_operand
  | Ax4 of Ast.point_operand * Ast.line_operand * Ast.line_operand
  | Ax5 of Ast.line_operand * Ast.line_operand * Ast.point_operand option
  | Ax6 of
      Ast.point_operand * Ast.line_operand * Ast.point_operand
      * Ast.point_operand option
  | Ax7 of
      Ast.point_operand * Ast.line_operand * Ast.point_operand
      * Ast.line_operand * Ast.point_operand option
        (** A construction recognised as one of the seven axioms, carrying the
            operands in the roles its solver reads them (ADR 0022). *)

val classify : Ast.construction -> classified
(** Recognise the alignment set as one of the seven, by the multiset of its
    alignment kinds. Fails naming the alignments when the set matches none of
    them, and when the head names fold lines. Order-insensitive across kinds;
    where a kind repeats, source order fixes the operand roles. *)

val tag : classified -> string
(** The provenance tag, ["axiom1"] … ["axiom7"]. *)

val implied_point : classified -> Ast.point_operand option
(** The point a map construction moves, which a `fold` takes as its anchor
    when the program names no `moving`: the first operand of axioms 2, 6 and
    7, and [None] for the rest. Takes the classification {!axis_of} hands
    back, so a construction is recognised once per statement. *)

type ax5_pending
(** Axiom 5 (`map --l1 onto --l2`) needs its candidate bisectors selected
    against the current fold state (material of l1, paper incidence,
    `toward` direction), so {!axis_of} defers that choice: intersecting
    lines yield [Ax5], everything else a fully-resolved [Axis]. Opaque —
    only {!select_axiom5_bind}, {!select_axiom5_fold} and {!ax5_sources}
    read it. *)

type axis_result =
  | Axis of Geom.line * string * string list
  | Ax5 of ax5_pending

val axis_of : Ctx.ctx -> Error.span -> Ast.construction -> classified * axis_result
(** Axis line + provenance (axiom tag, source names), evaluated against the
    current table positions. Recognises the construction with {!classify}
    first, so the tag is {!tag}'s and the sources are the operands that
    recognition hands back; the classification comes back with the axis for
    callers that read the operands again ({!implied_point}). *)

val select_axiom5_bind : Ctx.ctx -> Error.span -> ax5_pending -> Geom.line
(** Resolve a deferred axiom-5 axis for a `bind`/`mark` (no fold spec to
    read a `moving` anchor from). *)

val select_axiom5_fold :
  Ctx.ctx -> Error.span -> ax5_pending -> fs:Ast.fold_spec -> Geom.line * int option
(** Resolve a deferred axiom-5 axis for a `fold`. Returns the chosen axis
    plus an optional move-side override (`Some` when the direction is
    derived, not read off an explicit `moving` anchor). *)

val ax5_sources : ax5_pending -> string list
(** Provenance source names, including `toward` when present. *)
