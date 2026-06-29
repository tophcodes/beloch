(** The folded state of the paper as a stack of flat faces. Each face is a
    convex CCW polygon in paper coordinates plus the isometry placing it on the
    table; [layers] orders the face indices bottom→top. Flat folds keep
    everything in the table plane, so the only "3D" is this stacking order. *)

type face = { paper : Geom.point array; iso : Isometry.t }
type t = { faces : face array; layers : int array }
type assign = M | V | U
type crease_record = { ra : Geom.point; rb : Geom.point; assign : assign }

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

(* The segment where the table-space line [axis] crosses face [f]'s interior,
   returned in [f]'s paper coordinates. None if the axis misses the interior
   (touches at most one boundary point). *)
let axis_segment_in_face (f : face) (axis : Geom.line) :
    (Geom.point * Geom.point) option =
  let table = Array.map (Isometry.apply_point f.iso) f.paper in
  let n = Array.length table in
  let pts = ref [] in
  let add p =
    if not (List.exists (Geom.point_equal p) !pts) then pts := p :: !pts
  in
  for i = 0 to n - 1 do
    let a = table.(i) and b = table.((i + 1) mod n) in
    let sa = Geom.side_of_line axis a and sb = Geom.side_of_line axis b in
    if sa = 0 then add a
    else if sb <> 0 && sa <> sb then
      match Geom.intersection axis (Geom.line_through a b) with
      | Some r -> add r
      | None -> ()
  done;
  match !pts with
  | [ p; q ] ->
      let inv = Isometry.inverse f.iso in
      Some (Isometry.apply_point inv p, Isometry.apply_point inv q)
  | _ -> None

(* Split every face crossing [axis] into its two halves (both keep their
   isometry; nothing moves). Returns the new state and one U crease record per
   face actually cut. *)
let subdivide (st : t) (axis : Geom.line) : t * crease_record list =
  let out =
    ref []
    (* faces, accumulated top->bottom via prepend *)
  in
  let recs = ref [] in
  Array.iter
    (fun fi ->
      let f = st.faces.(fi) in
      let table = Array.map (Isometry.apply_point f.iso) f.paper in
      let inv = Isometry.inverse f.iso in
      let part keep =
        let sub = Geom.clip_convex_halfplane axis keep table in
        if Array.length sub >= 3 then
          Some { paper = Array.map (Isometry.apply_point inv) sub; iso = f.iso }
        else None
      in
      let plus = part 1 and minus = part (-1) in
      (match (plus, minus) with
      | Some _, Some _ -> (
          match axis_segment_in_face f axis with
          | Some (a, b) -> recs := { ra = a; rb = b; assign = U } :: !recs
          | None -> ())
      | _ -> ());
      List.iter
        (function Some face -> out := face :: !out | None -> ())
        [ plus; minus ])
    st.layers;
  let faces = Array.of_list (List.rev !out) in
  ({ faces; layers = Array.init (Array.length faces) (fun i -> i) }, !recs)

(* Like [simple_fold] but also returns the crease records created, each with its
   derived mountain/valley from the orientation-parity rule. *)
let fold_with_records (st : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) : t * crease_record list =
  let refl = Isometry.reflect_across_line axis in
  let stay = ref [] and mov = ref [] in
  let recs = ref [] in
  Array.iter
    (fun fi ->
      let f = st.faces.(fi) in
      let table = Array.map (Isometry.apply_point f.iso) f.paper in
      let inv = Isometry.inverse f.iso in
      let part keep iso =
        let sub = Geom.clip_convex_halfplane axis keep table in
        if Array.length sub >= 3 then
          Some { paper = Array.map (Isometry.apply_point inv) sub; iso }
        else None
      in
      let s = part (-move_side) f.iso in
      let m = part move_side (Isometry.compose refl f.iso) in
      (match (s, m) with
      | Some _, Some _ -> (
          match axis_segment_in_face f axis with
          | Some (a, b) ->
              let assign =
                if valley <> (Isometry.det_sign f.iso < 0) then V else M
              in
              recs := { ra = a; rb = b; assign } :: !recs
          | None -> ())
      | _ -> ());
      (match s with Some face -> stay := face :: !stay | None -> ());
      match m with Some face -> mov := face :: !mov | None -> ())
    st.layers;
  let stationary = List.rev !stay in
  let moved = !mov in
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let faces = Array.of_list ordered in
  ({ faces; layers = Array.init (Array.length faces) (fun i -> i) }, !recs)

(* Distinct paper coordinates whose current table position is [tp] (one per
   overlapping layer covering that table point). *)
let paper_preimages (st : t) (tp : Geom.point) : Geom.point list =
  let acc = ref [] in
  Array.iter
    (fun f ->
      let pp = Isometry.apply_point (Isometry.inverse f.iso) tp in
      if
        Geom.in_convex_polygon f.paper pp
        && not (List.exists (Geom.point_equal pp) !acc)
      then acc := pp :: !acc)
    st.faces;
  List.rev !acc

(* simple flat fold: reflect every layer-part on [move_side] of [axis] across it,
   then restack. valley → moved parts (reversed) on top; mountain → underneath. *)
let simple_fold (st : t) ~(axis : Geom.line) ~(move_side : int) ~(valley : bool)
    : t =
  fst (fold_with_records st ~axis ~move_side ~valley)
