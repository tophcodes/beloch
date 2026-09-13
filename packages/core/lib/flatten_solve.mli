(** The `flatten` solver orchestration: single-vertex multi-crease fold, one
    solver pipeline (spec §4.9). *)

val run :
  Ctx.ctx ->
  into:(int * (Geom.line -> unit)) option ->
  bind_out:(Ctx.crease_val -> unit) ->
  elems:Ast.collapse_elem list ->
  overs:(Ast.flap_arg * Ast.flap_arg) list ->
  staying_opt:Ast.flap_arg option ->
  toward_opt:Ast.point_operand option ->
  Error.span ->
  unit

(** [into] carries the output clause's `into NAME`: the crease id the
    emergent crease is scored under, and the axis check the emergent line
    has to pass. [None] for `as NAME` and for an anonymous flatten, which
    let the solver mint an id of its own. *)
