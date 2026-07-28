(** Axiom construction: the seven Huzita-Justin axioms and the axiom-5
    bisector-selection path. Every stateful function takes
    [(ctx : Ctx.ctx)] as its first parameter. *)

type ax5_pending = {
  la : Geom.line;
  lb : Geom.line;
  cands : Geom.line * Geom.line;  (** angle bisectors of [la], [lb] *)
  toward : Geom.point option;  (** table space, already checked off [la] *)
  l1_op : Ast.line_operand;  (** for the l1-material lookup *)
  l1_str : string;
  l2_str : string;
  toward_str : string option;
  sources : string list;  (** provenance, includes toward when present *)
}
(** Axiom 5 (`map --l1 onto --l2`) needs its candidate bisectors selected
    against the current fold state (material of l1, paper incidence,
    `toward` direction), so {!axis_of} defers that choice: intersecting
    lines yield [Ax5], everything else a fully-resolved [Axis]. *)

type axis_result =
  | Axis of Geom.line * string * string list
  | Ax5 of ax5_pending

val axis_of : Ctx.ctx -> Error.span -> Ast.axiom -> axis_result
(** Axis line + provenance (axiom tag, source names), evaluated against the
    current table positions. *)

val select_axiom5_bind : Ctx.ctx -> Error.span -> ax5_pending -> Geom.line
(** Resolve a deferred axiom-5 axis for a `bind`/`mark` (no fold spec to
    read a `moving` anchor from). *)

val select_axiom5_fold :
  Ctx.ctx -> Error.span -> ax5_pending -> fs:Ast.fold_spec -> Geom.line * int option
(** Resolve a deferred axiom-5 axis for a `fold`. Returns the chosen axis
    plus an optional move-side override (`Some` when the direction is
    derived, not read off an explicit `moving` anchor). *)
