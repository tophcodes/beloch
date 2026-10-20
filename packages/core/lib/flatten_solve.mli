(** The fan: the solver `flatten` and `squash` share, and the resolution of
    `flatten`'s items in front of it (docs/reference/KERNEL.md, Fan). *)

type elem_cand = int * Geom.point * Geom.point * Ast.mv_constraint
(** A candidate segment of one element of a fan: its crease id, its table
    endpoints and the letter the program fixed for it. *)

val vertex_of : Ctx.ctx -> elem_cands:elem_cand list list -> Error.span -> Geom.point
(** The table point every element has a candidate segment ending at, off the
    sheet's raw edge on the paper; fails with [Collapse.e_no_vertex]. *)

val solve :
  Ctx.ctx ->
  into:(int * (Geom.line -> unit)) option ->
  verb:string ->
  elem_cands:elem_cand list list ->
  o:Geom.point ->
  elem_names:string list ->
  over:(int * int) list ->
  anchor:Geom.point array list option ->
  staying:Collapse.stayer option ->
  toward:Geom.point option ->
  Error.span ->
  (int * Geom.line) option
(** The fan at [o] on resolved operands: one candidate list per element,
    the `over` constraints as face pairs, the anchor flap as paper polygons
    ([None]: the topmost flap under [o]), the stayer ([None]: the wedge
    between the first two elements) and the `toward` point, a paper point.
    [verb] names the write in messages and crease records, [elem_names] the
    elements as the program wrote them. Leaves the chosen state in the
    context and records the trace; returns the emergent crease where one
    was scored. The caller binds the output clause and pushes the frame. *)

val run :
  Ctx.ctx ->
  into:(int * (Geom.line -> unit)) option ->
  (** [into] carries the output clause's `into NAME`: the crease id the
      emergent crease is scored under, and the axis check the emergent line
      has to pass. [None] for `as NAME` and for an anonymous flatten, which
      let the solver mint an id of its own. *)
  bind_out:(Ctx.crease_val -> unit) ->
  elems:Ast.collapse_elem list ->
  overs:(Ast.flap_arg * Ast.flap_arg) list ->
  staying_opt:Ast.point_operand list option ->
  on_opt:Ast.flap_arg option ->
  (** [on_opt] names the anchor flap, whose tip the flatten moves; [None]
      takes the topmost flap under the vertex (ADR 0040). *)
  toward_opt:Ast.point_operand option ->
  Error.span ->
  unit
(** A `flatten` statement: resolves its items and runs [solve]. *)
