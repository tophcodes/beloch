(** Serialize a folded state to FOLD (https://github.com/edemaine/fold). *)

let q_to_json (x : Num.t) : Yojson.Safe.t = `Float (Num.to_float x)

let to_json_folded (fd : Eval.folded) : Yojson.Safe.t =
  let faces = fd.Eval.state.Fold_state.faces in
  let creases = fd.Eval.creases in
  (* dedup vertices by paper coord; remember paper + table coords per vertex.
     INVARIANT: a paper vertex shared by several faces gets its table coord from
     whichever face introduces it first. This is consistent only because every
     flat fold cuts each face along its full chord, so shared paper vertices lie
     on a shared crease where the adjacent faces' isometries agree. Partial or
     non-flat folds (a later slice) would break this — re-key per (face,vertex)
     or assert agreement then. *)
  let vpaper = Dynarray.create () and vtable = Dynarray.create () in
  let vindex (f : Fold_state.face) (p : Geom.point) : int =
    let n = Dynarray.length vpaper in
    let rec find i =
      if i >= n then -1
      else if Geom.point_equal p (Dynarray.get vpaper i) then i
      else find (i + 1)
    in
    let i = find 0 in
    if i >= 0 then i
    else begin
      Dynarray.add_last vpaper p;
      Dynarray.add_last vtable (Isometry.apply_point f.Fold_state.iso p);
      n
    end
  in
  let face_idx =
    Array.map (fun f -> Array.map (vindex f) f.Fold_state.paper) faces
  in
  (* edge classification *)
  let on_unit_boundary (a : Geom.point) (b : Geom.point) : bool =
    let z = Num.zero and o = Num.one in
    (Num.equal a.Geom.x z && Num.equal b.Geom.x z)
    || (Num.equal a.Geom.x o && Num.equal b.Geom.x o)
    || (Num.equal a.Geom.y z && Num.equal b.Geom.y z)
    || (Num.equal a.Geom.y o && Num.equal b.Geom.y o)
  in
  let record_of (a : Geom.point) (b : Geom.point) :
      Fold_state.crease_record option =
    List.find_opt
      (fun (r : Fold_state.crease_record) ->
        Geom.on_segment (r.Fold_state.ra, r.Fold_state.rb) a
        && Geom.on_segment (r.Fold_state.ra, r.Fold_state.rb) b)
      creases
  in
  (* collect unique edges with (assignment string, provenance) *)
  let edge_tbl = Hashtbl.create 64 in
  let edges = ref [] in
  Array.iteri
    (fun fi f ->
      let idxs = face_idx.(fi) in
      let m = Array.length idxs in
      for k = 0 to m - 1 do
        let ia = idxs.(k) and ib = idxs.((k + 1) mod m) in
        let key = (min ia ib, max ia ib) in
        if not (Hashtbl.mem edge_tbl key) then begin
          Hashtbl.replace edge_tbl key ();
          let pa = f.Fold_state.paper.(k)
          and pb = f.Fold_state.paper.((k + 1) mod m) in
          let assign, prov =
            if on_unit_boundary pa pb then ("B", None)
            else
              match record_of pa pb with
              | Some r ->
                  let a =
                    match r.Fold_state.assign with
                    | Fold_state.M -> "M"
                    | Fold_state.V -> "V"
                    | Fold_state.U -> "U"
                  in
                  (a, r.Fold_state.prov)
              | None -> ("U", None)
          in
          edges := (ia, ib, assign, prov) :: !edges
        end
      done)
    faces;
  let edges = List.rev !edges in
  let verts_paper =
    Dynarray.to_list vpaper
    |> List.map (fun (p : Geom.point) ->
        `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
  in
  let verts_table =
    Dynarray.to_list vtable
    |> List.map (fun (p : Geom.point) ->
        `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
  in
  let edges_vertices =
    List.map (fun (a, b, _, _) -> `List [ `Int a; `Int b ]) edges
  in
  let edges_assignment = List.map (fun (_, _, a, _) -> `String a) edges in
  let edges_fold_angle =
    List.map
      (fun (_, _, a, _) ->
        match a with
        | "V" -> `Float 180.0
        | "M" -> `Float (-180.0)
        | _ -> `Float 0.0)
      edges
  in
  let faces_vertices =
    Array.to_list face_idx
    |> List.map (fun idxs ->
        `List (Array.to_list (Array.map (fun i -> `Int i) idxs)))
  in
  let beloch_edges =
    List.map
      (fun (_, _, _, prov) ->
        match prov with
        | None -> `Null
        | Some (pr : State.provenance) ->
            `Assoc
              [
                ("axiom", `String pr.State.axiom);
                ( "sources",
                  `List (List.map (fun s -> `String s) pr.State.sources) );
                ("span", `String (Error.span_to_string pr.State.span));
                ( "name",
                  match pr.State.name with Some n -> `String n | None -> `Null
                );
              ])
      edges
  in
  (* faceOrders for overlapping face pairs; faces array index = layer (bottom->top) *)
  let table_poly i =
    Array.map
      (Isometry.apply_point faces.(i).Fold_state.iso)
      faces.(i).Fold_state.paper
  in
  let nf = Array.length faces in
  let face_orders = ref [] in
  for fi = 0 to nf - 1 do
    for gi = fi + 1 to nf - 1 do
      if Geom.convex_overlap (table_poly fi) (table_poly gi) then begin
        let g_up = Isometry.det_sign faces.(gi).Fold_state.iso > 0 in
        let s = if fi > gi = g_up then 1 else -1 in
        face_orders := `List [ `Int fi; `Int gi; `Int s ] :: !face_orders
      end
    done
  done;
  let folded_frame =
    `Assoc
      [
        ("frame_classes", `List [ `String "foldedForm" ]);
        ("frame_parent", `Int 0);
        ("frame_inherit", `Bool true);
        ("vertices_coords", `List verts_table);
        ("edges_foldAngle", `List edges_fold_angle);
        ("faceOrders", `List (List.rev !face_orders));
      ]
  in
  `Assoc
    [
      ("file_spec", `Float 1.1);
      ("file_creator", `String "beloch 0.3.0-dev");
      ("frame_classes", `List [ `String "creasePattern" ]);
      ("vertices_coords", `List verts_paper);
      ("edges_vertices", `List edges_vertices);
      ("edges_assignment", `List edges_assignment);
      ("faces_vertices", `List faces_vertices);
      ("beloch:edges", `List beloch_edges);
      ("file_frames", `List [ folded_frame ]);
    ]
