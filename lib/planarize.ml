(** Build a planar crease pattern: boundary edges, plus each crease clipped to
    the square and split at every on-paper crease-crease intersection. *)

let corner (n : string) : Geom.point = List.assoc n Eval.corners

let dedup_points (ps : Geom.point list) : Geom.point list =
  List.fold_left
    (fun acc p -> if List.exists (Geom.point_equal p) acc then acc else p :: acc)
    [] ps

let run (creases : Eval.crease list) : State.t =
  let st = State.create () in
  (* boundary, counter-clockwise *)
  let a = corner "a" and b = corner "b"
  and c = corner "c" and d = corner "d" in
  let ia = State.add_vertex st a and ib = State.add_vertex st b in
  let ic = State.add_vertex st c and id = State.add_vertex st d in
  let boundary v0 v1 =
    State.add_edge st { State.v0; v1; assign = State.Boundary; prov = None }
  in
  boundary ia ib; boundary ib ic; boundary ic id; boundary id ia;
  (* clip each crease to a segment, dropping any that miss the paper *)
  let segs =
    List.filter_map
      (fun (cr : Eval.crease) ->
        match Geom.clip_to_unit_square cr.line with
        | Some s -> Some (s, cr.prov)
        | None -> None)
      creases
  in
  (* split each segment at intersections with the others, then add sub-edges *)
  List.iter
    (fun (seg, prov) ->
      let p, q = seg in
      let pts = ref [ p; q ] in
      List.iter
        (fun (other, _) ->
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
            State.add_edge st
              { State.v0 = ix; v1 = iy; assign = State.Crease; prov = Some prov };
            link rest
        | _ -> ()
      in
      link sorted)
    segs;
  st
