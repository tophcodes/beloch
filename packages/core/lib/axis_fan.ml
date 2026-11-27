(** The fan at the point at infinity of an axis (spec multifold, "A fold is
    the fan at the point at infinity of its axis"): it cuts the tip along the
    axis and hands the cut state to [Fan.make], which moves each piece by the
    changing hinges on its paper path, and the blocks of each opening to
    [Fan.stackings]. `fold`, `unfold` and `reverse` fold through it. *)

type t = { cut : Fold_state.reverse_fan; fan : Fan.t }

let make ~(cid : int) (g : Fold_state.t) ~(axis : Geom.line) ~(move_side : int)
    ~(tip : bool array) ~(prov : State.provenance option) :
    (t, Fold_state.violation) result =
  match Fold_state.reverse_fan ~cid g ~axis ~move_side ~tip ~prov with
  | Error v -> Error v
  | Ok cut -> (
      let scored = Fold_state.reverse_scored cut in
      (* the cut hinges fold, a hinge already on the axis between the tip
         and a face that stays changes, and every other hinge keeps its
         angle *)
      let role =
        Array.map
          (fun changes -> if changes then Fan.Fold else Fan.Keep)
          (Fold_state.reverse_changes cut)
      in
      match
        Fan.make scored ~root:(Fold_state.reverse_root cut)
          ~tip:(Fold_state.reverse_moved cut)
          ~names:(Array.make (Array.length role) None)
          ~role ~nelem:0
          ~side:(fun _ _ _ -> None)
      with
      | Some (fan :: _) ->
          Result.map (fun _ -> { cut; fan }) (Fan.geometry fan)
      (* a reflection across one line closes every path, so the motion of
         the tip always exists *)
      | Some [] | None -> Error (Fold_state.Hinge_not_closed 0))

let fold_opening (f : t) ~(blocks : (bool array * Fold_state.placement) list) =
  Fan.stackings f.fan (Fan.Opening (f.cut, blocks))

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
