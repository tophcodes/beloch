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
  let folded =
    lazy
      (match Fold_state.reverse_fan ~cid g ~axis ~move_side ~tip ~prov with
      | Error v -> Error v
      | Ok fan -> (
          let scored = Fold_state.reverse_scored fan in
          let faces = Fold_state.faces scored in
          let nf = Array.length faces in
          let root = Fold_state.reverse_root fan in
          (* the cut hinges fold, a hinge already on the axis between the
             tip and a face that stays changes, and every other hinge keeps
             its angle, the spine included *)
          let role =
            Array.map
              (fun changes -> if changes then Collapse.Fold else Collapse.Keep)
              (Fold_state.reverse_changes fan)
          in
          match
            Collapse.geoms_of scored
              ~sec:(Array.init nf (fun i -> if i = root then 0 else 1))
              ~tip:(Fold_state.reverse_moved fan)
              ~names:(Array.make (Array.length role) None)
              ~role ~nelem:0
              ~side:(fun _ _ _ -> None)
              ~faces ~nf
          with
          | Ok (sg :: _) ->
              Result.map
                (fun geo -> (fan, geo, sg.Collapse.sg_flips))
                (Lazy.force sg.Collapse.sg_geometry)
          (* a reflection across one line closes every path, so the motion
             of the tip always exists *)
          | Ok [] | Error _ -> Error (Fold_state.Hinge_not_closed 0)))
  in
  let fold blocks =
    match Lazy.force folded with
    | Error v -> Error v
    | Ok (fan, geo, turned) -> Fold_state.fold_opening fan geo ~turned ~blocks
  in
  Fold_state.reverse_attempts ~cid g ~axis ~move_side ~tip ~inside ~fold

let reverse ~(cid : int) g ~axis ~move_side ~tip ~inside ~prov =
  Fold_state.reverse_of_attempts
    (attempts ~cid g ~axis ~move_side ~tip ~inside ~prov)
