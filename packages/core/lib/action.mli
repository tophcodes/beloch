(** The disposition verbs that write to the fold state: `mark`, `fold`,
    `unfold` and `reverse` (ADR 0011), plus the checked-fold primitive `fold` and
    `reverse` share. Every stateful function takes [(ctx : Ctx.ctx)] as its
    first parameter. *)

val crease_id_for :
  Ctx.ctx ->
  Ast.output ->
  fresh:(unit -> int) ->
  int * (Geom.line -> unit) * (Ctx.crease_val -> unit)
(** The crease id a write scores under, the check its axis has to pass
    before the write runs, and the binding step to run once the write has
    succeeded. [Anonymous] and [Named _] score a crease of their own, so
    they take [fresh ()]; `into` scores onto the crease its name is already
    bound to, so a fold along a mark keeps one id instead of minting a
    second, coincident crease for the emitter to supersede. *)

val eval_mark :
  Ctx.ctx ->
  Ast.output ->
  Ast.markable ->
  Ast.extent ->
  Ast.direction ->
  Ast.flap_arg option ->
  Ast.sides ->
  Error.span ->
  unit
(** Evaluate a `mark` statement: record a crease without moving paper
    (docs/reference/BELOCH-WRITES.md). *)

val eval_fold :
  Ctx.ctx -> Ast.output -> Ast.markable -> Ast.fold_spec -> Error.span -> unit
(** Evaluate a `fold` statement: reflect the moving flaps over the axis and
    advance the fold state (docs/reference/MODEL.md, def-fold). *)

val eval_unfold :
  Ctx.ctx -> Ast.line_operand -> Ast.fold_spec -> Error.span -> unit
(** Evaluate an `unfold` statement: turn the selected layers over a line
    that every one of them lies on one side of, opening the folded hinges on
    it between them and the layers that stay (docs/reference/MODEL.md, def-fold;
    ADR 0053). *)

val eval_reverse :
  Ctx.ctx ->
  Ast.output ->
  Ast.markable ->
  Ast.reverse_spec ->
  Error.span ->
  unit
(** Evaluate a `reverse` statement: fold a flap's tip back over the spine
    that joins it to the rest of the paper (docs/reference/MODEL.md, def-reverse). *)
