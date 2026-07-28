(** The `flatten` solver orchestration, lifted out of [Eval.eval_program]'s
    [Ast.Flatten] arm: single-vertex multi-crease fold, one solver pipeline
    (spec §4.9). *)

val run :
  Ctx.ctx ->
  name_opt:string option ->
  elems:Ast.collapse_elem list ->
  overs:(Ast.flap_arg * Ast.flap_arg) list ->
  staying_opt:Ast.flap_arg option ->
  toward_opt:Ast.point_operand option ->
  Error.span ->
  unit
