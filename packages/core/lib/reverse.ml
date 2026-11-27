(** A reverse fold through the fan (spec layer-order,
    "A reverse fold gives three units per opening"): the fan cuts the tip
    along the axis and moves each piece by the creases on its paper path
    ([Collapse.geoms_of]; spec multifold,
    "A fan moves each piece by the changing hinges on its paper path"), and
    each opening of the tip (spec reverse-fold,
    "A reverse fold opens its tip at one opening") is a stacking of that one
    folded state, found by the layer search of the fan with the blocks as its
    units. *)

let attempts ~(cid : int) (g : Fold_state.t) ~(axis : Geom.line)
    ~(move_side : int) ~(tip : bool array) ~(inside : bool)
    ~(prov : State.provenance option) : Fold_state.spine_attempt list =
  (* the folded state, built when the first opening asks for it *)
  let folded = lazy (Axis_fan.make ~cid g ~axis ~move_side ~tip ~prov) in
  let fold blocks =
    match Lazy.force folded with
    | Error v -> Error v
    | Ok f -> Axis_fan.fold_opening f ~blocks
  in
  Fold_state.reverse_attempts ~cid g ~axis ~move_side ~tip ~inside ~fold

let reverse ~(cid : int) g ~axis ~move_side ~tip ~inside ~prov =
  Fold_state.reverse_of_attempts
    (attempts ~cid g ~axis ~move_side ~tip ~inside ~prov)
