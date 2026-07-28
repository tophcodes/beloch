(** Name resolution, the selector engine, flap resolution and mark resolution,
    lifted out of [Eval.eval_program]. Every stateful function takes
    [(ctx : Ctx.ctx)] as its first parameter. *)

val pstr : Ast.point_operand -> string
(** Render a point operand back to source text, for provenance and error
    messages. *)

val lstr : Ast.line_operand -> string
(** Render a line operand back to source text. *)

val fstr : Ast.flap_arg -> string
(** Render a flap argument back to source text. *)

val resolve_point : Ctx.ctx -> Ast.point_operand -> Geom.point
(** Resolve a point operand to its material PAPER coordinate. *)

val resolve_line : Ctx.ctx -> Ast.line_operand -> Geom.line
(** Resolve a line operand to its TABLE-space line (fold axes align current
    table positions). *)

val resolve_paper_line :
  Ctx.ctx -> Ast.line_operand -> Geom.line * (Geom.point * Geom.point) list option
(** Resolve a line operand to a PAPER-space line, plus the marks (chords) it
    carries if any. Used by `cross`: folding never moves a mark within the
    sheet, so the crossing is fold-state-independent. *)

val material_cid : Ctx.ctx -> Ast.crease_ref -> int
(** The crease id of a MATERIAL crease reference. A [Ctx.Mark] is
    materialized in place (subdivided along its line) on first use here,
    promoting its binding to [Ctx.Material] — see [Ctx.promote_crease]. *)

val table_of : Ctx.ctx -> Ast.point_operand -> Geom.point
(** [resolve_point], mapped through the current table placement. *)

val paper_line_of_crease :
  Ctx.ctx ->
  name:string ->
  Error.span ->
  Ctx.crease_val ->
  Geom.line * (Geom.point * Geom.point) list option
(** A crease value resolved to PAPER space: the one material line carrying
    the crease's marks, plus those marks' paper chords ([None] for a
    constructed line / boundary reference with no marks). *)

val bundle_segments :
  Ctx.ctx -> Ast.line_operand -> int option * Fold_state.crease_segment list
(** Every material segment a line operand names, plus the single crease id
    shared by all of them if there is one ([None] for a cross-crease union
    or a paper edge). *)

val resolve_flap_cluster : Ctx.ctx -> Ast.flap_arg -> Error.span -> int list
(** Resolve a flap operand to its unique current flap — a coplanar cluster of
    faces (ADR 0017: two faces joined only by a still-unfolded flat hinge are
    the same flap). Errors if the operand names more than one flap. *)

val resolve_sector_face : Ctx.ctx -> Ast.flap_arg -> Error.span -> int
(** Face-precise resolution for [collapse]'s `over`/`under`: a sector around
    a collapse vertex is always one FACE (ADR 0017 non-goal), unlike
    `moving`/`up to`'s flap operand. *)

val side_of_flap_arg_res :
  Ctx.ctx ->
  Geom.line ->
  Ast.flap_arg ->
  Error.span ->
  (int, [ `OnAxis | `Straddles ]) result
(** Which side of [axis] a flap anchor moves. Resolution failures (point off
    paper, ambiguous flap) raise WITHIN — only the on-axis / straddle
    verdicts are returned, so axiom-5 selection can reject a candidate
    without erroring. *)

val side_of_flap_arg : Ctx.ctx -> Geom.line -> Ast.flap_arg -> Error.span -> int
(** {!side_of_flap_arg_res}, raising a user-facing error on [`OnAxis] /
    [`Straddles] instead of returning it. *)

val anchor_faces : Ctx.ctx -> Ast.flap_arg -> Error.span -> int list
(** Default-scope anchor: the faces carrying the operand, as a UNION — a
    point on a crease shared by several flaps seeds all of them (design
    option (a)). *)

val default_move_side : Ctx.ctx -> Geom.line -> Ast.flap_arg -> Error.span -> int
(** Moving side for the default (no `up to`) branch. *)

val target_of : Ctx.ctx -> Ast.flap_arg -> Error.span -> Fold_state.scope_target
(** The endpoint of a scoped (`up to`) fold's moving range, derived from a
    flap argument. *)

val resolve_mark_extent :
  Ctx.ctx ->
  Geom.line ->
  Ast.extent ->
  Error.span ->
  [ `Full | `Partial of Fold_state.mark_geom * Geom.point * Geom.line ]
(** A mark's extent (spec §4), resolved to PAPER-space geometry and checked
    against the motion's TABLE-space [axis]. *)

val resolve_mark_flap :
  Ctx.ctx -> Ast.flap_operand option -> Geom.point -> Error.span -> int list
(** The flap (coplanar cluster) a partial mark's extent is written onto: an
    explicit `#[...]` wins; otherwise the carrying flap of the extent's
    representative paper point. *)
