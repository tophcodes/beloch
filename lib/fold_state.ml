(** The folded state of the paper as a stack of flat faces. Each face is a
    convex CCW polygon in paper coordinates plus the isometry placing it on the
    table. [order] is a per-face partial order: order.(i).(j) says whether face
    i is Above/Below face j when folded, or Apart if they do not overlap on the
    table. Array index carries no z-meaning — all stacking lives in [order]. *)

type face = { paper : Geom.point array; iso : Isometry.t }
type rel = Above | Below | Apart
type t = { faces : face array; order : rel array array }
type assign = M | V | U

let negate = function Above -> Below | Below -> Above | Apart -> Apart

(* table-space polygon of a face *)
let table_poly_of (f : face) : Geom.point array =
  Array.map (Isometry.apply_point f.iso) f.paper

(* Build an n×n order matrix. [rel_of i j] is consulted only for i<j pairs whose
   table polygons overlap; everything else stays Apart. *)
let build_order (faces : face array) (rel_of : int -> int -> rel) : rel array array =
  let n = Array.length faces in
  let order = Array.make_matrix n n Apart in
  for i = 0 to n - 1 do
    for j = i + 1 to n - 1 do
      if Geom.convex_overlap (table_poly_of faces.(i)) (table_poly_of faces.(j))
      then begin
        let r = rel_of i j in
        order.(i).(j) <- r;
        order.(j).(i) <- negate r
      end
    done
  done;
  order

(* Acyclicity of the [Above] relation over overlapping faces, then a check that
   every overlapping pair is decided (tortilla-tortilla: two strictly-overlapping
   uncreased faces must have one entirely above the other). Returns the first
   violation as a message, or None. Taco-tortilla and taco-taco are deferred to
   the pocket slice (they need persistent crease-adjacency and cannot fire for
   simple folds). *)
let validity_error (st : t) : string option =
  let order = st.order in
  let n = Array.length order in
  let color = Array.make n 0 (* 0 white, 1 gray, 2 black *) in
  let cycle = ref None in
  let rec dfs i =
    color.(i) <- 1;
    for j = 0 to n - 1 do
      if order.(i).(j) = Above && !cycle = None then
        if color.(j) = 1 then
          cycle :=
            Some
              (Printf.sprintf
                 "layer ordering: stacking cycle through faces %d and %d (paper \
                  through paper)"
                 i j)
        else if color.(j) = 0 then dfs j
    done;
    color.(i) <- 2
  in
  for i = 0 to n - 1 do
    if color.(i) = 0 && !cycle = None then dfs i
  done;
  match !cycle with
  | Some _ as c -> c
  | None ->
      let bad = ref None in
      for i = 0 to n - 1 do
        for j = i + 1 to n - 1 do
          if
            !bad = None
            && Geom.convex_overlap (table_poly_of st.faces.(i))
                 (table_poly_of st.faces.(j))
            && order.(i).(j) = Apart
          then
            bad :=
              Some
                (Printf.sprintf
                   "layer ordering: faces %d and %d overlap but have no order \
                    (tortilla-tortilla)"
                   i j)
        done
      done;
      !bad

type crease_record = {
  ra : Geom.point;
  rb : Geom.point;
  assign : assign;
  prov : State.provenance option;
}

let init_square : t =
  let p x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  {
    faces =
      [| { paper = [| p 0 0; p 1 0; p 1 1; p 0 1 |]; iso = Isometry.identity } |];
    order = [| [| Apart |] |];
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
let subdivide (st : t) (axis : Geom.line) ~(prov : State.provenance option) :
    t * crease_record list =
  let out = ref [] (* (child_face, parent_index), accumulated via prepend *) in
  let recs = ref [] in
  Array.iteri
    (fun fi f ->
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
          | Some (a, b) -> recs := { ra = a; rb = b; assign = U; prov } :: !recs
          | None -> ())
      | _ -> ());
      List.iter
        (function Some fc -> out := (fc, fi) :: !out | None -> ())
        [ plus; minus ])
    st.faces;
  let arr = Array.of_list (List.rev !out) in
  let faces = Array.map fst arr in
  let parent = Array.map snd arr in
  let order =
    build_order faces (fun i j -> st.order.(parent.(i)).(parent.(j)))
  in
  ({ faces; order }, !recs)

(* Like [simple_fold] but also returns the crease records created, each with its
   derived mountain/valley from the orientation-parity rule. *)
let fold_with_records (st : t) ~(axis : Geom.line) ~(move_side : int)
    ~(valley : bool) ~(prov : State.provenance option) : t * crease_record list
    =
  let refl = Isometry.reflect_across_line axis in
  let stay = ref [] and mov = ref [] in
  (* each elt: (child_face, parent_index) *)
  let recs = ref [] in
  Array.iteri
    (fun fi f ->
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
              recs := { ra = a; rb = b; assign; prov } :: !recs
          | None -> ())
      | _ -> ());
      (match s with Some face -> stay := (face, fi) :: !stay | None -> ());
      match m with Some face -> mov := (face, fi) :: !mov | None -> ())
    st.faces;
  let stationary = List.rev !stay in
  let moved = !mov in
  (* keep the existing face-append order so fold_emit stays stable until Task 3 *)
  let ordered = if valley then stationary @ moved else moved @ stationary in
  let arr = Array.of_list ordered in
  let faces = Array.map fst arr in
  let parent = Array.map snd arr in
  (* a child is "moved" iff it came from the [mov] list; recover by membership *)
  let n_stay = List.length stationary in
  let moved_flag =
    if valley then Array.init (Array.length arr) (fun i -> i >= n_stay)
    else Array.init (Array.length arr) (fun i -> i < List.length moved)
  in
  let rel_of i j =
    let pi = parent.(i) and pj = parent.(j) in
    match (moved_flag.(i), moved_flag.(j)) with
    | false, false -> st.order.(pi).(pj) (* stationary vs stationary: preserved *)
    | true, true -> negate st.order.(pi).(pj) (* moved vs moved: reversed *)
    | true, false -> if valley then Above else Below (* moved i over/under stationary j *)
    | false, true -> if valley then Below else Above
  in
  let order = build_order faces rel_of in
  let st' = { faces; order } in
  (match validity_error st' with
  | Some msg ->
      let span =
        match prov with
        | Some p -> p.State.span
        | None -> (Lexing.dummy_pos, Lexing.dummy_pos)
      in
      Error.fail span msg
  | None -> ());
  (st', !recs)

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
  fst (fold_with_records st ~axis ~move_side ~valley ~prov:None)

(* Turn the whole sheet over. Reflect every face across the footprint's vertical
   centerline (x = (minX+maxX)/2 over all face table vertices) — an internal,
   cosmetic axis: which line is irrelevant to the user (named points), only the
   substantive effect matters. The reflection flips each face's det_sign
   (front<->back); reversing the face array turns the stack top<->bottom. *)
let flip (st : t) : t =
  let n = Array.length st.faces in
  if n = 0 then st
  else begin
    let p0 = (table_polygon st 0).(0) in
    let lo = ref p0.Geom.x and hi = ref p0.Geom.x in
    Array.iteri
      (fun i _ ->
        Array.iter
          (fun (q : Geom.point) ->
            if Num.compare q.Geom.x !lo < 0 then lo := q.Geom.x;
            if Num.compare q.Geom.x !hi > 0 then hi := q.Geom.x)
          (table_polygon st i))
      st.faces;
    let cx = Num.div (Num.add !lo !hi) (Num.of_int 2) in
    let axis = { Geom.a = Num.one; b = Num.zero; c = cx } in
    let refl = Isometry.reflect_across_line axis in
    let flipped =
      Array.map (fun f -> { f with iso = Isometry.compose refl f.iso }) st.faces
    in
    let rev = Array.init n (fun i -> flipped.(n - 1 - i)) in
    let order = Array.make_matrix n n Apart in
    for i = 0 to n - 1 do
      for j = 0 to n - 1 do
        order.(i).(j) <- negate st.order.(n - 1 - i).(n - 1 - j)
      done
    done;
    { faces = rev; order }
  end
