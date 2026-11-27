(** The fan at the point at infinity of an axis (spec multifold, "A fold is
    the fan at the point at infinity of its axis"): it cuts the tip along the
    axis and moves each piece by the changing hinges on its paper path
    ([Collapse.geoms_of]; spec multifold, "A fan moves each piece by the
    changing hinges on its paper path"). `fold`, `unfold` and `reverse` fold
    through it. *)

type t = {
  fan : Fold_state.reverse_fan;
  geo : Fold_state.geometry;
  turned : bool array;
}

let make ~(cid : int) (g : Fold_state.t) ~(axis : Geom.line) ~(move_side : int)
    ~(tip : bool array) ~(prov : State.provenance option) :
    (t, Fold_state.violation) result =
  match Fold_state.reverse_fan ~cid g ~axis ~move_side ~tip ~prov with
  | Error v -> Error v
  | Ok fan -> (
      let scored = Fold_state.reverse_scored fan in
      let faces = Fold_state.faces scored in
      let nf = Array.length faces in
      let root = Fold_state.reverse_root fan in
      (* the cut hinges fold, a hinge already on the axis between the tip
         and a face that stays changes, and every other hinge keeps its
         angle *)
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
            (fun geo -> { fan; geo; turned = sg.Collapse.sg_flips })
            (Lazy.force sg.Collapse.sg_geometry)
      (* a reflection across one line closes every path, so the motion of
         the tip always exists *)
      | Ok [] | Error _ -> Error (Fold_state.Hinge_not_closed 0))

let fold_opening (f : t) ~(blocks : (bool array * Fold_state.placement) list) =
  Fold_state.fold_opening f.fan f.geo ~turned:f.turned ~blocks

let fold_blocks_all ?crease_id ~(blocks : (bool array * Fold_state.placement) list)
    (g : Fold_state.t) ~(axis : Geom.line) ~(move_side : int)
    ~(prov : State.provenance option) : (Fold_state.t list, Fold_state.violation) result =
  let cid = match crease_id with Some c -> c | None -> Fold_state.fresh_crease_id () in
  let tip =
    Array.init (Array.length (Fold_state.faces g)) (fun i ->
        List.exists (fun (mask, _) -> mask.(i)) blocks)
  in
  match make ~cid g ~axis ~move_side ~tip ~prov with
  | Error v -> Error v
  | Ok f -> fold_opening f ~blocks

let fold_blocks ?crease_id ~blocks g ~axis ~move_side ~prov =
  match fold_blocks_all ?crease_id ~blocks g ~axis ~move_side ~prov with
  | Ok [ g' ] -> Ok g'
  | Ok gs -> Error (Fold_state.Several_stackings (List.length gs))
  | Error v -> Error v

let fold ?crease_id ?moving_parents (g : Fold_state.t) ~(axis : Geom.line)
    ~(move_side : int) ~(valley : bool) ~(prov : State.provenance option) :
    Fold_state.t =
  let mask =
    match moving_parents with
    | Some m -> m
    | None -> Array.make (Array.length (Fold_state.faces g)) true
  in
  match
    fold_blocks ?crease_id
      ~blocks:[ (mask, if valley then Fold_state.Top else Fold_state.Bottom) ]
      g ~axis ~move_side ~prov
  with
  | Ok g' -> g'
  | Error v -> Fold_state.fail_of_violation prov v

let simple_fold (g : Fold_state.t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) : Fold_state.t =
  fold g ~axis ~move_side ~valley ~prov:None
