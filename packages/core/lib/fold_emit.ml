(** Serialize a folded state to FOLD (https://github.com/edemaine/fold). *)

let q_to_json (x : Num.t) : Yojson.Safe.t = `Float (Num.to_float x)

let mark_assign_str = function
  | Fold_state.M -> "M"
  | Fold_state.V -> "V"
  | Fold_state.F -> "F"

(* One `beloch:marks`-shaped entry — shared by the global (final-state) list
   and each statement-log entry's embedded as-recorded mark. *)
let mark_json (m : Fold_state.mark) : Yojson.Safe.t =
  let line =
    let l = m.Fold_state.mline in
    `List [ q_to_json l.Geom.a; q_to_json l.Geom.b; q_to_json l.Geom.c ]
  in
  let common =
    [
      ("line", line);
      ("intent", `String (mark_assign_str m.Fold_state.mintent));
      ("crease_id", `Int m.Fold_state.mcrease_id);
    ]
  in
  match m.Fold_state.mgeom with
  | Fold_state.MSeg (a, b) ->
      `Assoc
        (("kind", `String "seg")
        :: ("a", `List [ q_to_json a.Geom.x; q_to_json a.Geom.y ])
        :: ("b", `List [ q_to_json b.Geom.x; q_to_json b.Geom.y ])
        :: common)
  | Fold_state.MPoint p ->
      `Assoc
        (("kind", `String "point")
        :: ("p", `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
        :: common)

(* name for each vertex, by exact paper-coord match against named points *)
let vertices_names_json (vpaper : Geom.point Dynarray.t)
    (named_points : (string * Geom.point) list) : Yojson.Safe.t =
  `List
    (Dynarray.to_list vpaper
    |> List.map (fun (p : Geom.point) ->
           match
             List.find_opt (fun (_, q) -> Geom.point_equal p q) named_points
           with
           | Some (name, _) -> `String name
           | None -> `Null))

(* beloch:edges array from an (ia, ib, assign, prov, cid) edge list *)
let beloch_edges_json edges : Yojson.Safe.t =
  `List
    (List.map
       (fun (_, _, _, prov, cid) ->
         match prov with
         | None -> `Null
         | Some (pr : State.provenance) ->
             `Assoc
               ([
                  ("axiom", `String pr.State.axiom);
                  ( "sources",
                    `List (List.map (fun s -> `String s) pr.State.sources) );
                  ("span", `String (Error.span_to_string pr.State.span));
                  ( "name",
                    match pr.State.name with
                    | Some n -> `String n
                    | None -> `Null );
                ]
               @ (match cid with Some c -> [ ("crease_id", `Int c) ] | None -> [])))
       edges)

(* Emit-time overlay (design §3.6). Graduates every mark whose MSeg endpoints
   both lie on a face boundary (corner / paper edge / real crease — the old
   CSubdivide test) into real creases by subdividing the state (in paper space,
   fold-invariantly) along the mark's line. Returns the display state plus the
   marks that stay records for `beloch:marks`. A mark coincident with a real
   crease subdivides nothing, so it silently drops (the real crease supersedes).
   Applied to BOTH the crease-pattern frame and each folded frame — fold-time
   algorithms never see it (emit-only). Partial (mid-segment) graduation is
   deferred: a whole mark graduates or it does not. *)
let cp_display (st : Fold_state.t) : Fold_state.t * Fold_state.mark list =
  let grad, kept =
    List.partition (Fold_state.mark_graduates st)
      (Array.to_list (Fold_state.marks st))
  in
  let disp =
    List.fold_left
      (fun s (m : Fold_state.mark) ->
        match m.Fold_state.mgeom with
        | Fold_state.MSeg (a, b) ->
            Fold_state.subdivide_paper s
              (Geom.line_through a b)
              ~intent:m.Fold_state.mintent ~prov:m.Fold_state.mprov
        | Fold_state.MPoint _ -> s)
      st grad
  in
  (disp, kept)

(* Build one self-contained foldedForm frame for a given state. Its topology is
   this state's faces (earlier steps have fewer faces than the final CP, so the
   frame cannot inherit the parent's vertex/face set — frame_inherit is false). *)
let folded_frame_of_state (named_points : (string * Geom.point) list)
    (state : Fold_state.t)
    (span : Error.span option) : Yojson.Safe.t =
  (* graduate marks into flat (F) creases for the folded diagram too, so a
     scored precrease shows in the folded frame; emit-only, like the CP frame *)
  let state, _ = cp_display state in
  let faces = Fold_state.faces state in
  (* dedup vertices by (paper coord, table coord) together, remembering both per
     vertex. Two faces sharing a paper corner merge only when their isometries
     agree there (same table position) — the case of a shared crease on a
     full-chord flat fold. A scoped ("up to") fold cuts only some layers, so the
     stationary layer and the moving flap can share a paper corner OFF the fold
     axis, where their isometries disagree; keying on table coord too gives each
     face its own reflected copy instead of collapsing the moving flap onto the
     stationary layer's position (which degenerated the moving face to zero area
     — the "diagonal slash" render). *)
  let vpaper = Dynarray.create () and vtable = Dynarray.create () in
  let vindex (fi : int) (p : Geom.point) : int =
    let t = Isometry.apply_point (Fold_state.face_iso2 state fi) p in
    let n = Dynarray.length vpaper in
    let rec find i =
      if i >= n then -1
      else if
        Geom.point_equal p (Dynarray.get vpaper i)
        && Geom.point_equal t (Dynarray.get vtable i)
      then i
      else find (i + 1)
    in
    let i = find 0 in
    if i >= 0 then i
    else begin
      Dynarray.add_last vpaper p;
      Dynarray.add_last vtable t;
      n
    end
  in
  let face_idx = Array.mapi (fun fi f -> Array.map (vindex fi) f) faces in
  (* edge classification *)
  let on_unit_boundary (a : Geom.point) (b : Geom.point) : bool =
    let z = Num.zero and o = Num.one in
    (Num.equal a.Geom.x z && Num.equal b.Geom.x z)
    || (Num.equal a.Geom.x o && Num.equal b.Geom.x o)
    || (Num.equal a.Geom.y z && Num.equal b.Geom.y z)
    || (Num.equal a.Geom.y o && Num.equal b.Geom.y o)
  in
  (* collect unique edges with (assignment string, provenance) *)
  let hs = Fold_state.hinges state in
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
          let pa = f.(k) and pb = f.((k + 1) mod m) in
          let assign, prov, cid =
            if on_unit_boundary pa pb then ("B", None, None)
            else
              match Fold_state.hinge_between state fi pa pb with
              | Some hi ->
                  let a =
                    match Fold_state.mv state hi with
                    | Fold_state.M -> "M"
                    | Fold_state.V -> "V"
                    | Fold_state.F -> "F"
                  in
                  (a, hs.(hi).Fold_state.prov, Some hs.(hi).Fold_state.crease_id)
              | None -> ("F", None, None)
          in
          edges := (ia, ib, assign, prov, cid) :: !edges
        end
      done)
    faces;
  let edges = List.rev !edges in
  let beloch_edges = beloch_edges_json edges in
  let beloch_vertices_names = vertices_names_json vpaper named_points in
  let verts_table =
    Dynarray.to_list vtable
    |> List.map (fun (p : Geom.point) ->
        `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
  in
  let edges_vertices =
    List.map (fun (a, b, _, _, _) -> `List [ `Int a; `Int b ]) edges
  in
  let edges_assignment = List.map (fun (_, _, a, _, _) -> `String a) edges in
  let edges_fold_angle =
    List.map
      (fun (_, _, a, _, _) ->
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
  (* faceOrders read directly from the folded state's partial order. For a pair
     (fi < gi) that overlaps, sign follows FOLD's convention keyed to gi's normal
     (its face_up-ness): a "below" relation with gi facing up is -1, etc. *)
  let nf = Array.length faces in
  let face_orders = ref [] in
  for fi = 0 to nf - 1 do
    for gi = fi + 1 to nf - 1 do
      match Fold_state.rel state fi gi with
      | Fold_state.Apart -> ()
      | rel ->
          let g_up = Fold_state.face_up state gi in
          let fi_below = rel = Fold_state.Below in
          let s =
            if fi_below then if g_up then -1 else 1
            else if g_up then 1 else -1
          in
          face_orders := `List [ `Int fi; `Int gi; `Int s ] :: !face_orders
    done
  done;
  let beloch_faces_matrix =
    Array.to_list
      (Array.mapi
         (fun fi _ ->
           let i = Fold_state.face_iso2 state fi in
           `List
             [ q_to_json i.Isometry.m00; q_to_json i.Isometry.m01;
               q_to_json i.Isometry.m10; q_to_json i.Isometry.m11;
               q_to_json i.Isometry.tx;  q_to_json i.Isometry.ty ])
         faces)
  in
  `Assoc
    [
      ("frame_classes", `List [ `String "foldedForm" ]);
      ("frame_parent", `Int 0);
      ("frame_inherit", `Bool false);
      ("vertices_coords", `List verts_table);
      ("edges_vertices", `List edges_vertices);
      ("edges_assignment", `List edges_assignment);
      ("edges_foldAngle", `List edges_fold_angle);
      ("faces_vertices", `List faces_vertices);
      ("beloch:faces_matrix", `List beloch_faces_matrix);
      ("faceOrders", `List (List.rev !face_orders));
      ("beloch:source_line",
        (match span with
        | Some (start, _) -> `Int start.Lexing.pos_lnum
        | None -> `Null));
      ("beloch:edges", beloch_edges);
      ("beloch:vertices_names", beloch_vertices_names);
    ]

(* One entry per fold- or mark-producing top-level statement, in source
   order — a statement-level sourcemap for the Playground step player. A
   mark statement embeds its OWN mark geometry as recorded at that point,
   independent of whether it later graduates into a real crease (which only
   ever happens at some LATER fold statement) — see
   docs/superpowers/specs/2026-07-20-playground-statement-sourcemap-design.md. *)
let beloch_statements_json (statements : Eval.stmt_log_entry list) : Yojson.Safe.t =
  `List
    (List.map
       (fun (s : Eval.stmt_log_entry) ->
         let common =
           [
             ( "kind",
               `String
                 (match s.Eval.sl_kind with
                 | Eval.SFold -> "fold"
                 | Eval.SMark -> "mark") );
             ("source_line", `Int (fst s.Eval.sl_span).Lexing.pos_lnum);
             ("frame_index", `Int s.Eval.sl_frame_index);
             ("kept_marks", `List (List.map mark_json s.Eval.sl_kept));
           ]
         in
         match s.Eval.sl_mark with
         | None -> `Assoc (("mark", `Null) :: common)
         | Some m -> `Assoc (("mark", mark_json m) :: common))
       statements)

let to_json_folded (fd : Eval.folded) : Yojson.Safe.t =
  let disp, kept_marks = cp_display fd.Eval.state in
  let faces = Fold_state.faces disp in
  (* dedup vertices by paper coord; remember paper coord per vertex, for the
     top-level crease-pattern frame (built from the final state). *)
  let vpaper = Dynarray.create () in
  let vindex (p : Geom.point) : int =
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
      n
    end
  in
  let face_idx = Array.map (fun f -> Array.map vindex f) faces in
  (* edge classification *)
  let on_unit_boundary (a : Geom.point) (b : Geom.point) : bool =
    let z = Num.zero and o = Num.one in
    (Num.equal a.Geom.x z && Num.equal b.Geom.x z)
    || (Num.equal a.Geom.x o && Num.equal b.Geom.x o)
    || (Num.equal a.Geom.y z && Num.equal b.Geom.y z)
    || (Num.equal a.Geom.y o && Num.equal b.Geom.y o)
  in
  (* collect unique edges with (assignment string, provenance) *)
  let hs = Fold_state.hinges disp in
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
          let pa = f.(k) and pb = f.((k + 1) mod m) in
          let assign, prov, cid =
            if on_unit_boundary pa pb then ("B", None, None)
            else
              match Fold_state.hinge_between disp fi pa pb with
              | Some hi ->
                  let h = hs.(hi) in
                  let a =
                    match h.Fold_state.intent with
                    | Fold_state.M -> "M"
                    | Fold_state.V -> "V"
                    | Fold_state.F -> "F"
                  in
                  (a, h.Fold_state.prov, Some h.Fold_state.crease_id)
              | None -> ("F", None, None)
          in
          edges := (ia, ib, assign, prov, cid) :: !edges
        end
      done)
    faces;
  let edges = List.rev !edges in
  let verts_paper =
    Dynarray.to_list vpaper
    |> List.map (fun (p : Geom.point) ->
        `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ])
  in
  let edges_vertices =
    List.map (fun (a, b, _, _, _) -> `List [ `Int a; `Int b ]) edges
  in
  let edges_assignment = List.map (fun (_, _, a, _, _) -> `String a) edges in
  let faces_vertices =
    Array.to_list face_idx
    |> List.map (fun idxs ->
        `List (Array.to_list (Array.map (fun i -> `Int i) idxs)))
  in
  let beloch_edges = beloch_edges_json edges in
  (* the step-annotated 3-tuple is only needed for beloch_named_points below;
     everywhere else strips it to keep the 2-tuple helper signature. *)
  let named_points_2 = List.map (fun (n, p, _step) -> (n, p)) fd.Eval.named_points in
  let beloch_vertices_names = vertices_names_json vpaper named_points_2 in
  let beloch_named_points =
    `Assoc
      (List.map
         (fun (name, (p : Geom.point), step) ->
           let t = Fold_state.table_position fd.Eval.state p in
           ( name,
             `Assoc
               [
                 ("paper", `List [ q_to_json p.Geom.x; q_to_json p.Geom.y ]);
                 ("table", `List [ q_to_json t.Geom.x; q_to_json t.Geom.y ]);
                 ("step", `Int step);
               ] ))
         fd.Eval.named_points)
  in
  let beloch_named_lines =
    `Assoc
      (List.map
         (fun (name, (l : Geom.line), step) ->
           ( name,
             `Assoc
               [
                 ("coeffs", `List [ q_to_json l.Geom.a; q_to_json l.Geom.b; q_to_json l.Geom.c ]);
                 ("step", `Int step);
               ] ))
         fd.Eval.named_lines)
  in
  (* record marks (non-subdividing; see Fold_state.mark) *)
  let beloch_marks = kept_marks |> List.map mark_json in
  (* forward-compat hook for a future renderer slider (issue #70); no
     renderer consumes this yet — see [Eval.free_info]. *)
  let beloch_free =
    `Assoc
      (List.map
         (fun (name, (fi : Eval.free_info)) ->
           ( name,
             `Assoc
               [
                 ("t", `String (Num.to_rational_string fi.Eval.fi_t));
                 ( "endpoints",
                   `List
                     [
                       `List
                         [ q_to_json fi.Eval.fi_p0.Geom.x;
                           q_to_json fi.Eval.fi_p0.Geom.y ];
                       `List
                         [ q_to_json fi.Eval.fi_p1.Geom.x;
                           q_to_json fi.Eval.fi_p1.Geom.y ];
                     ] );
                 ("source_line", `Int fi.Eval.fi_source_line);
               ] ))
         fd.Eval.free_points)
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
      ("beloch:edges", beloch_edges);
      ("beloch:vertices_names", beloch_vertices_names);
      ("beloch:named_points", beloch_named_points);
      ("beloch:named_lines", beloch_named_lines);
      ("beloch:named_lines_frame", `String "creasePattern");
      ("beloch:marks", `List beloch_marks);
      ("beloch:free", beloch_free);
      ("beloch:statements", beloch_statements_json fd.Eval.statements);
      ( "file_frames",
        (* Step 0: the flat, unfolded sheet, so a folded-diagram stepper opens
           on the starting paper rather than on the first fold. It is a viewing
           frame only — not counted as a fold (the `steps` assertion reads
           Eval.frames, which excludes it). *)
        `List
          (folded_frame_of_state named_points_2 Fold_state.init_square
             None
          :: List.map
               (fun (st, span) ->
                 folded_frame_of_state named_points_2 st span)
               fd.Eval.frames) );
    ]
