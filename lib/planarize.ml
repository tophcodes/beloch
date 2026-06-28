(** Build a planar crease pattern: boundary edges, plus each crease clipped to
    the square and split at every on-paper crease-crease intersection. *)

let corner (n : string) : Geom.point = List.assoc n Eval.corners

let dedup_points (ps : Geom.point list) : Geom.point list =
  List.fold_left
    (fun acc p -> if List.exists (Geom.point_equal p) acc then acc else p :: acc)
    [] ps

let run (creases : Eval.crease list) : State.t =
  let st = State.create () in
  let a = corner "a" and b = corner "b" and c = corner "c" and d = corner "d" in
  (* every segment to planarize: 4 boundary edges + clipped creases *)
  let boundary =
    [ ((a, b), State.Boundary, None);
      ((b, c), State.Boundary, None);
      ((c, d), State.Boundary, None);
      ((d, a), State.Boundary, None) ]
  in
  let crease_segs =
    List.filter_map
      (fun (cr : Eval.crease) ->
        match Geom.clip_to_unit_square cr.line with
        | Some s -> Some (s, State.Crease, Some cr.prov)
        | None -> None)
      creases
  in
  let segs = boundary @ crease_segs in
  (* split each segment at intersections with every other; dedup edges by index pair *)
  let seen = Hashtbl.create 64 in
  List.iter
    (fun (seg, assign, prov) ->
      let p, q = seg in
      let pts = ref [ p; q ] in
      List.iter
        (fun (other, _, _) ->
          (* physical inequality: skip self-comparison while catching equal-valued siblings;
             coincident lines yield no intersection (det=0), so no spurious splits *)
          if other != seg then
            match Geom.segment_intersection seg other with
            | Some r -> pts := r :: !pts
            | None -> ())
        segs;
      let sorted =
        dedup_points !pts
        |> List.sort (fun r1 r2 ->
               Q.compare (Geom.seg_param seg r1) (Geom.seg_param seg r2))
      in
      let rec link = function
        | x :: (y :: _ as rest) ->
            let ix = State.add_vertex st x and iy = State.add_vertex st y in
            let key = (min ix iy, max ix iy) in
            if not (Hashtbl.mem seen key) then begin
              Hashtbl.replace seen key ();
              State.add_edge st { State.v0 = ix; v1 = iy; assign; prov }
            end;
            link rest
        | _ -> ()
      in
      link sorted)
    segs;
  st
