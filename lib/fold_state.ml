(** The folded state of the paper as a stack of flat faces. Each face is a
    convex CCW polygon in paper coordinates plus the isometry placing it on the
    table; [layers] orders the face indices bottom→top. Flat folds keep
    everything in the table plane, so the only "3D" is this stacking order. *)

type face = { paper : Geom.point array; iso : Isometry.t }
type t = { faces : face array; layers : int array }

let init_square : t =
  let p x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  {
    faces =
      [|
        { paper = [| p 0 0; p 1 0; p 1 1; p 0 1 |]; iso = Isometry.identity };
      |];
    layers = [| 0 |];
  }

let table_polygon (st : t) (i : int) : Geom.point array =
  Array.map (Isometry.apply_point st.faces.(i).iso) st.faces.(i).paper

(* current table position of a material paper point: find the face whose paper
   polygon contains it, apply that face's isometry. Faces partition the paper,
   and isometries agree on shared crease edges, so any containing face works. *)
let table_position (st : t) (paper : Geom.point) : Geom.point =
  let n = Array.length st.faces in
  let rec find i =
    if i >= n then invalid_arg "Fold_state.table_position: point in no face"
    else if Geom.in_convex_polygon st.faces.(i).paper paper then
      Isometry.apply_point st.faces.(i).iso paper
    else find (i + 1)
  in
  find 0

(* simple flat fold: reflect every layer-part on [move_side] of [axis] across it,
   then restack. valley → moved parts (reversed) on top; mountain → underneath. *)
let simple_fold (st : t) ~(axis : Geom.line) ~(move_side : int) ~(valley : bool)
    : t =
  let refl = Isometry.reflect_across_line axis in
  let stay =
    ref []
    (* accumulates top→bottom via prepend *)
  in
  let mov =
    ref []
    (* accumulates top→bottom via prepend = reversed order *)
  in
  Array.iter
    (fun fi ->
      let f = st.faces.(fi) in
      let table = table_polygon st fi in
      let inv = Isometry.inverse f.iso in
      let part keep =
        let sub = Geom.clip_convex_halfplane axis keep table in
        if Array.length sub >= 3 then
          Some (Array.map (Isometry.apply_point inv) sub)
        else None
      in
      (match part (-move_side) with
      | Some paper -> stay := { paper; iso = f.iso } :: !stay
      | None -> ());
      match part move_side with
      | Some paper ->
          mov := { paper; iso = Isometry.compose refl f.iso } :: !mov
      | None -> ())
    st.layers;
  let stationary =
    List.rev !stay
    (* bottom→top *)
  in
  let moved =
    !mov
    (* already reversed: top→bottom of original = wrap order *)
  in
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let faces = Array.of_list ordered in
  { faces; layers = Array.init (Array.length faces) (fun i -> i) }
