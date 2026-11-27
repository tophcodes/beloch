(** The fan ({!Fan}) at the point at infinity of an axis (spec multifold,
    "A fold is the fan at the point at infinity of its axis"): one line, the
    two half-planes as its sectors, every layer the axis crosses under the
    vertex. This module hands {!Fan.make} the cut state and the roles of its
    hinges, and {!Fan.stackings} the blocks of an opening. `fold`, `unfold`
    and `reverse` fold through it. *)

type t
(** The folded state of the fan before any layer order: the tip cut along
    the axis, each piece moved by the changing hinges on its paper path
    ({!Fan.make}). *)

val make :
  cid:int ->
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  tip:bool array ->
  prov:State.provenance option ->
  (t, Fold_state.violation) result
(** The fan of the material [tip] (a mask over PARENT faces) across the
    TABLE-space [axis] ({!Fold_state.reverse_fan}): a cut hinge folds, a
    hinge on the axis between the tip and a face that stays changes, every
    other hinge keeps its angle. *)

val fold_opening :
  t ->
  blocks:(bool array * Fold_state.placement) list ->
  (Fold_state.t list, Fold_state.violation) result
(** The stackings of the fan with [blocks] placed ({!Fan.stackings} with
    {!Fan.Opening}). *)

val fold_blocks_all :
  ?crease_id:int ->
  blocks:(bool array * Fold_state.placement) list ->
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  prov:State.provenance option ->
  (Fold_state.t list, Fold_state.violation) result
(** [fold_blocks] with every stacking the fold has. When every block lies
    [Fold_state.Over] or [Fold_state.Under] a face, the fold decides on which side of the block
    each stationary face it lands on lies: from the placement, from the
    anchor where the face, the anchor and the block share a region, and
    from the faces over the creases of either. The sides nothing decides
    are searched, and each combination that satisfies the non-crossing
    conditions is one stacking. The list is not empty. [Error v] is a
    [Fold_state.Taco_tortilla] or a [Fold_state.Layer_cycle] where the conditions put a face on
    both sides, or the violation of the first
    combination tried when none passes. *)

val fold_blocks :
  ?crease_id:int ->
  blocks:(bool array * Fold_state.placement) list ->
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  prov:State.provenance option ->
  (Fold_state.t, Fold_state.violation) result
(** The general simple fold: every block's parents are cut by the TABLE-space
    [axis] and their [move_side] pieces reflected across it through the fan
    ({!make}): one new angle-1 hinge per cut parent, carried hinges
    re-attached, on-axis hinges with exactly one moving side toggled. Layer
    order: two stationary faces that overlap lie as their parents did, and
    two faces of one block the other way round, since a half-turn reverses
    a stack. A block placed [Fold_state.Top] lies above every stationary face it lands
    on and every block listed before it, a block placed [Fold_state.Bottom] below
    them; where every block lies [Fold_state.Over] or [Fold_state.Under] faces, the stacking is
    the one {!fold_blocks_all} finds. A block
    mask marks PARENT faces; a parent in no block is stationary even where
    it crosses the axis. Block masks must be disjoint: a parent claimed by
    several blocks goes to the first. [Error v] is the resulting state's invariant
    violation ([Fold_state.Taco_taco]/[Fold_state.Taco_tortilla] reject an impossible insertion),
    or [Fold_state.Several_stackings] where {!fold_blocks_all} finds several,
    or [Fold_state.Disconnected 0] where every face moves and none stays.
    [Invalid_argument] if an [Fold_state.Over]/[Fold_state.Under] face has no stationary child
    (a block parent lying entirely on the moving side), or if the fold
    places one block outside the stack and another on faces. A block parent cut
    by the axis keeps its stationary remainder as that child, so a flap can
    be tucked under its own hinge layer. *)

val fold :
  ?crease_id:int ->
  ?moving_parents:bool array ->
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  valley:bool ->
  prov:State.provenance option ->
  Fold_state.t
(** [fold_blocks] with one block: [moving_parents] (default every face)
    placed [Fold_state.Top] for a valley fold, [Fold_state.Bottom] for a mountain fold; raises
    {!Error.fail} at [prov]'s span on a violation. Faces on [move_side] of
    the TABLE-space [axis] (restricted to [moving_parents]) are cut and
    hinged to their stationary counterpart with a new angle-1 hinge; any
    old hinge lying entirely on [axis] with exactly one moving side toggles
    (a flat precrease upgrades to folded and keeps its [crease_id]; a folded
    hinge with no cut counterpart on the axis physically unfolds back to
    angle 0). Stationary faces keep their order, movers reverse theirs, and
    a mover lies above every stationary face it lands on for a valley fold,
    below for a mountain fold. The
    root and [base] are a stationary child and its parent's placement. *)

val simple_fold : Fold_state.t -> axis:Geom.line -> move_side:int -> valley:bool -> Fold_state.t
(** [fold] with no [crease_id]/[moving_parents] override and no [provenance]. *)

