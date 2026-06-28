(** Serialize a crease pattern to FOLD (https://github.com/edemaine/fold). *)

let q_to_json (q : Q.t) : Yojson.Safe.t = `Float (Q.to_float q)

let to_json (st : State.t) (faces : int array list) : Yojson.Safe.t =
  let verts =
    Dynarray.to_list st.State.verts
    |> List.map (fun (p : Geom.point) ->
           `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
  in
  let edges = Dynarray.to_list st.State.edges in
  let edges_vertices =
    List.map (fun e -> `List [ `Int e.State.v0; `Int e.State.v1 ]) edges
  in
  let edges_assignment =
    List.map
      (fun e ->
        match e.State.assign with
        | State.Boundary -> `String "B"
        | State.Crease -> `String "U")
      edges
  in
  let faces_vertices =
    List.map
      (fun f -> `List (Array.to_list (Array.map (fun i -> `Int i) f)))
      faces
  in
  let beloch_edges =
    List.map
      (fun e ->
        match e.State.prov with
        | None -> `Null
        | Some pr ->
            `Assoc
              [ ("axiom", `String pr.State.axiom);
                ("sources", `List (List.map (fun s -> `String s) pr.State.sources));
                ("span", `String (Error.span_to_string pr.State.span)) ])
      edges
  in
  `Assoc
    [ ("file_spec", `Float 1.1);
      (* literal, NOT Beloch.version: fold_emit is re-exported by the beloch.ml
         facade, so referencing Beloch here would be a module cycle. Keep in
         sync with Beloch.version. *)
      ("file_creator", `String "beloch 0.1.0-dev");
      ("frame_classes", `List [ `String "creasePattern" ]);
      ("vertices_coords", `List verts);
      ("edges_vertices", `List edges_vertices);
      ("edges_assignment", `List edges_assignment);
      ("faces_vertices", `List faces_vertices);
      ("beloch:edges", `List beloch_edges) ]
