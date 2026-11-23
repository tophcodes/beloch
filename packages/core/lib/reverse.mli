(** A reverse fold through the fan (spec layer-order,
    "A reverse fold gives three units per opening"). *)

val attempts :
  cid:int ->
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  tip:bool array ->
  inside:bool ->
  prov:State.provenance option ->
  Fold_state.spine_attempt list
(** Every opening of the reverse fold of the material [tip] (a mask over
    PARENT faces) across the TABLE-space [axis], with what became of it
    ({!Fold_state.reverse_attempts}). The fan cuts the tip along the axis
    with crease [cid], folds the cut hinges, opens a hinge on the axis that
    the tip leaves, and keeps every other hinge; each piece of the tip moves
    by the creases on its paper path. Each opening is a stacking of that
    folded state, the stationary faces and the two blocks the units of the
    layer search. *)

val reverse :
  cid:int ->
  Fold_state.t ->
  axis:Geom.line ->
  move_side:int ->
  tip:bool array ->
  inside:bool ->
  prov:State.provenance option ->
  (Fold_state.t, Fold_state.reverse_failure) result
(** {!Fold_state.reverse_of_attempts} of {!attempts}. *)
