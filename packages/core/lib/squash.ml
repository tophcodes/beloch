(** `squash`: the fan of a squash fold from the bare alignment of its spine
    (docs/reference/KERNEL.md, Fan; ADR 0038). The spine is a folded hinge
    on the named crease, its vertex the end of it inside the paper, and the
    axis the bisector through the vertex that lays the spine on the target
    on the flap's side. The axis is scored on both layers of the flap, and
    the fan runs through [Flatten_solve.solve] with the spine, the two
    pieces of the axis and the crease on the target line as its elements
    (ADR 0044). *)

open Ctx

let centroid (poly : Geom.point array) : Geom.point =
  let m = Num.of_int (Array.length poly) in
  let sum get = Array.fold_left (fun acc p -> Num.add acc (get p)) Num.zero poly in
  { Geom.x = Num.div (sum (fun p -> p.Geom.x)) m;
    y = Num.div (sum (fun p -> p.Geom.y)) m }

(* A candidate spine: a folded hinge on the named crease whose one end
   lies inside the paper, with the target point it lands toward. *)
type candidate = {
  cid : int;  (** the spine's crease *)
  o : Geom.point;  (** the vertex, table *)
  f : Geom.point;  (** the far end, table *)
  f_paper : Geom.point;
  seg : Fold_state.crease_segment;
  upper : int;  (** the face of the anchor's layer at the spine *)
  lower : int;  (** the face of the other layer *)
  target : Geom.point;  (** a table point the spine lands toward *)
}

(* The item that keeps one candidate: the spine's crease filtered by a
   line through the far end of this spine and no other, else by a named
   point on this spine alone, else by a point at the far end. *)
let keeping_item (ctx : Ctx.ctx) (span : Error.span) ~(spine_str : string)
    ~(target_str : string) (c : candidate) (others : candidate list) : string =
  let paper_line_of name cv =
    match cv with
    | Ctx.Edge (_, l) -> Some l
    | Ctx.Material _ | Ctx.Mark _ | Ctx.Frozen _ -> (
        try
          Some
            (fst
               (Resolve.resolve_paper_line ctx
                  (Ast.LNamed { Ast.cname = name; cspan = span })))
        with Error.Beloch_error _ -> None)
    | Ctx.Bundle _ -> None
  in
  let on_this l = Geom.side_of_line l c.f_paper = 0 in
  let on_other l = List.exists (fun d -> Geom.side_of_line l d.f_paper = 0) others in
  let by_line =
    List.find_map
      (fun (s : Ctx.scope) ->
        Hashtbl.fold
          (fun name cv acc ->
            match (acc, paper_line_of name cv) with
            | None, Some l when on_this l && not (on_other l) -> Some name
            | _ -> acc)
          s.Ctx.lines None)
      ctx.Ctx.scopes
  in
  let on_seg (p : Geom.point) (d : candidate) =
    Geom.on_segment (d.seg.Fold_state.pa, d.seg.Fold_state.pb) p
  in
  let by_point =
    List.find_map
      (fun (s : Ctx.scope) ->
        Hashtbl.fold
          (fun n p acc ->
            if acc = None && on_seg p c && not (List.exists (on_seg p) others)
            then Some n
            else acc)
          s.Ctx.points None)
      ctx.Ctx.scopes
  in
  match (by_line, by_point) with
  | Some name, _ -> Printf.sprintf "(%s & --%s onto %s)" spine_str name target_str
  | None, Some n -> Printf.sprintf "(%s & .%s onto %s)" spine_str n target_str
  | None, None ->
      Printf.sprintf "(%s & .p onto %s) with .p at %s" spine_str target_str
        (Resolve.point_str c.f_paper)

let eval (ctx : Ctx.ctx) (out : Ast.output) (spine_lo : Ast.line_operand)
    (target : Ast.align_object) (span : Error.span) : unit =
  let spine_str = Resolve.lstr spine_lo in
  let target_str =
    match target with
    | Ast.AoPoint p -> Resolve.pstr p
    | Ast.AoLine l -> Resolve.lstr l
  in
  (* a target crease is materialized first, so that every face index below
     reads one state *)
  (match target with
  | Ast.AoLine lo -> ignore (Resolve.bundle_segments ctx lo)
  | Ast.AoPoint _ -> ());
  let spine_cid, segs = Resolve.bundle_segments ctx spine_lo in
  if segs = [] then
    Error.fail span (Printf.sprintf "%s has no material segment" spine_str);
  (match spine_cid with
  | Some _ -> ()
  | None ->
      Error.fail span
        (Printf.sprintf "the spine of a squash lies on one crease; %s names several"
           spine_str));
  let st = !(ctx.state) in
  let hs = Fold_state.hinges st in
  let rank = Fold_state.rank st in
  (* the folded hinges among the segments *)
  let folded =
    List.filter_map
      (fun (s : Fold_state.crease_segment) ->
        let fa, fb = s.Fold_state.faces in
        let found = ref None in
        Array.iteri
          (fun i (h : Fold_state.hinge) ->
            if
              !found = None && h.Fold_state.fa = fa && h.Fold_state.fb = fb
              && Num.sign h.Fold_state.angle <> 0
            then found := Some i)
          hs;
        Option.map (fun i -> (s, i)) !found)
      segs
  in
  if folded = [] then
    Error.fail span
      (Printf.sprintf "no folded edge lies on %s; a squash opens a spine" spine_str);
  (* each folded hinge with its vertex and the point its spine lands toward,
     or the reason it is no candidate *)
  let classify ((s : Fold_state.crease_segment), hinge) : (candidate, string) result =
    let a_in = not (Fold_state.on_raw_edge st s.Fold_state.pa) in
    let b_in = not (Fold_state.on_raw_edge st s.Fold_state.pb) in
    match (a_in, b_in) with
    | true, true ->
        Error
          (Printf.sprintf
             "both ends of the spine on %s lie inside the paper; which one is \
              the vertex is not decided"
             spine_str)
    | false, false ->
        Error
          (Printf.sprintf "the spine on %s runs from edge to edge; a squash needs a vertex"
             spine_str)
    | _ ->
        let o, f, f_paper =
          if a_in then (s.Fold_state.ta, s.Fold_state.tb, s.Fold_state.pb)
          else (s.Fold_state.tb, s.Fold_state.ta, s.Fold_state.pa)
        in
        let fa, fb = s.Fold_state.faces in
        let upper, lower = if rank.(fa) > rank.(fb) then (fa, fb) else (fb, fa) in
        let spine_line = Geom.line_through o f in
        let flap_point = centroid (Fold_state.table_polygon_ccw st upper) in
        let flap_side = Geom.side_of_line spine_line flap_point in
        let target_point =
          match target with
          | Ast.AoLine lo -> (
              (* the far ends of the target's segments at the vertex; the
                 crease has no table line of its own where a fold bent it
                 or laid it on itself *)
              let fars =
                snd (Resolve.bundle_segments ctx lo)
                |> List.filter_map (fun (t : Fold_state.crease_segment) ->
                       if Geom.point_equal t.Fold_state.ta o then Some t.Fold_state.tb
                       else if Geom.point_equal t.Fold_state.tb o then Some t.Fold_state.ta
                       else None)
              in
              match List.filter (fun q -> Geom.side_of_line spine_line q = flap_side) fars with
              | q :: _ -> Ok q
              | [] ->
                  if fars = [] then
                    Error
                      (Printf.sprintf "%s does not reach the vertex %s of the spine"
                         target_str (Resolve.point_str o))
                  else if List.for_all (fun q -> Geom.side_of_line spine_line q = 0) fars
                  then Error (Printf.sprintf "%s lies on the spine's line" target_str)
                  else
                    Error
                      (Printf.sprintf "%s lies beyond the spine; the flap cannot reach it"
                         target_str))
          | Ast.AoPoint po ->
              let p = Resolve.table_of ctx po in
              let sd = Geom.side_of_line spine_line p in
              if sd = 0 then Error (Printf.sprintf "%s lies on the spine's line" target_str)
              else if sd <> flap_side then
                Error
                  (Printf.sprintf "%s lies beyond the spine; the flap cannot reach it"
                     target_str)
              else Ok p
        in
        Result.map
          (fun target ->
            { cid = hs.(hinge).Fold_state.crease_id; o; f; f_paper; seg = s; upper;
              lower; target })
          target_point
  in
  let classified = List.map classify folded in
  let candidates = List.filter_map Result.to_option classified in
  let c =
    match candidates with
    | [ c ] -> c
    | [] -> (
        match List.find_map (function Error m -> Some m | Ok _ -> None) classified with
        | Some m -> Error.fail span m
        | None -> assert false)
    | all ->
        let items =
          List.map
            (fun c ->
              keeping_item ctx span ~spine_str ~target_str c
                (List.filter (fun d -> d != c) all))
            all
        in
        Error.fail
          ~hint:("name the flap by its spine: " ^ String.concat " or " items)
          span
          (Printf.sprintf "squash is ambiguous: %d flaps have a spine on %s that lands on %s"
             (List.length all) spine_str target_str)
  in
  let o = c.o and f = c.f in
  let spine_line = Geom.line_through o f in
  let target_line = Geom.line_through o c.target in
  let guard_t = Geom.perpendicular_through target_line o in
  let want = Geom.side_of_line guard_t c.target in
  (* the crease on the target line, materialized before the axis is scored
     so that every face index below reads one state *)
  let target_cid =
    match target with
    | Ast.AoLine lo -> (
        match fst (Resolve.bundle_segments ctx lo) with
        | Some cid -> cid
        | None ->
            Error.fail span
              (Printf.sprintf "the target of a squash is one crease; %s names several"
                 target_str))
    | Ast.AoPoint _ -> (
        (* the creases whose paper line runs through the vertex and the
           target on the anchor's layer; read on the paper, since a crease
           folded onto itself has no table line of its own *)
        let to_paper =
          Isometry.apply_point (Isometry.inverse (Fold_state.face_iso2 st c.upper))
        in
        let o_paper = to_paper o and t_paper = to_paper c.target in
        let on_target_line name cv =
          match cv with
          | Ctx.Material _ | Ctx.Mark _ -> (
              let cr = { Ast.cname = name; cspan = span } in
              match Resolve.resolve_paper_line ctx (Ast.LNamed cr) with
              | pl, _
                when Geom.side_of_line pl o_paper = 0 && Geom.side_of_line pl t_paper = 0 ->
                  Some cr
              | _ -> None
              | exception Error.Beloch_error _ -> None)
          | _ -> None
        in
        let names =
          List.concat_map
            (fun (s : Ctx.scope) ->
              Hashtbl.fold
                (fun name cv acc ->
                  match on_target_line name cv with Some cr -> cr :: acc | None -> acc)
                s.Ctx.lines [])
            ctx.Ctx.scopes
        in
        match List.sort_uniq compare (List.map (Resolve.material_cid ctx) names) with
        | [ cid ] -> cid
        | [] ->
            Error.fail ~hint:"mark it first" span
              (Printf.sprintf "no crease lies on the line from the vertex through %s"
                 target_str)
        | _ ->
            Error.fail span
              (Printf.sprintf "several creases lie on the line from the vertex through %s"
                 target_str))
  in
  (* the two layers of the flap, as paper polygons, read off the state once
     the spine and the target are material creases *)
  let st = !(ctx.state) in
  let faces = Fold_state.faces st in
  let clusters = Fold_state.coplanar_clusters st in
  let upper, lower =
    match
      List.find_opt
        (fun (s : Fold_state.crease_segment) ->
          (Geom.point_equal s.Fold_state.ta o && Geom.point_equal s.Fold_state.tb f)
          || (Geom.point_equal s.Fold_state.ta f && Geom.point_equal s.Fold_state.tb o))
        (Fold_state.crease_segments st c.cid)
    with
    | Some s ->
        let fa, fb = s.Fold_state.faces in
        let rank = Fold_state.rank st in
        if rank.(fa) > rank.(fb) then (fa, fb) else (fb, fa)
    | None -> (c.upper, c.lower)
  in
  let polys_of fi =
    List.filter_map
      (fun j -> if clusters.(j) = clusters.(fi) then Some faces.(j) else None)
      (List.init (Array.length faces) Fun.id)
  in
  let anchor_polys = polys_of upper and lower_polys = polys_of lower in
  let within polys (g : Fold_state.t) =
    let fs = Fold_state.faces g in
    fun i -> List.exists (fun poly -> Geom.in_convex_polygon poly (centroid fs.(i))) polys
  in
  (* the axis: the bisector of the spine's line and the target line through
     the vertex that lays the far end on the target's ray *)
  let axis =
    match Geom.angle_bisectors spine_line target_line with
    | None -> Error.fail span (Printf.sprintf "%s lies on the spine's line" target_str)
    | Some (b1, b2) ->
        if Geom.side_of_line guard_t (Geom.reflect_point b1 f) = want then b1 else b2
  in
  let f' = Geom.reflect_point axis f in
  let cid_a, check_axis, bind_out =
    Action.crease_id_for ctx out ~fresh:Fold_state.fresh_crease_id
  in
  check_axis axis;
  let cid_b = Fold_state.fresh_crease_id () in
  (* the name the output clause binds labels the axis on both layers *)
  let prov_name =
    match out with
    | (Ast.Named (n, _, _) | Ast.Into (n, _)) when not (Ctx.is_temp n) -> (
        match ctx.name_ctx with
        | Root -> Some n
        | InInstance i -> Some (i ^ "." ^ n)
        | Anon -> None)
    | _ -> None
  in
  let prov name : State.provenance option =
    Some
      { State.axiom = "squash"; sources = [ spine_str; target_str ]; span; name;
        stmt = Ctx.stmt_index ctx }
  in
  (* the axis as a half-line from the vertex toward the flap, on each layer,
     under an id of its own while the fan is solved: two elements of one
     crease in one direction would read as a duplicate ray *)
  let guard = Geom.perpendicular_through axis o in
  let keep = Geom.side_of_line guard f' in
  let st1 =
    Fold_state.subdivide ~crease_id:cid_a ~keep_side:(guard, keep)
      ~only:(within anchor_polys st) st axis ~prov:(prov prov_name)
  in
  let st2 =
    Fold_state.subdivide ~crease_id:cid_b ~keep_side:(guard, keep)
      ~only:(within lower_polys st1) st1 axis ~prov:(prov prov_name)
  in
  ctx.state := st2;
  let at_o (s : Fold_state.crease_segment) =
    Geom.point_equal s.Fold_state.ta o || Geom.point_equal s.Fold_state.tb o
  in
  let far_of (s : Fold_state.crease_segment) =
    if Geom.point_equal s.Fold_state.ta o then s.Fold_state.tb else s.Fold_state.ta
  in
  let cand cid (s : Fold_state.crease_segment) : Flatten_solve.elem_cand =
    (cid, s.Fold_state.ta, s.Fold_state.tb, Ast.MvFree)
  in
  let axis_elem cid =
    match List.filter at_o (Fold_state.crease_segments st2 cid) with
    | [] -> Error.fail span "the axis of the squash does not cross the flap"
    | segs -> List.map (cand cid) segs
  in
  let in_anchor = within anchor_polys st2 in
  let target_elem =
    let segs =
      Fold_state.crease_segments st2 target_cid
      |> List.filter (fun (s : Fold_state.crease_segment) ->
             let fa, fb = s.Fold_state.faces in
             at_o s
             && Geom.side_of_line target_line (far_of s) = 0
             && Geom.side_of_line guard_t (far_of s) = want
             && (in_anchor fa || in_anchor fb))
    in
    match segs with
    | [] ->
        Error.fail ~hint:"mark it first" span
          (Printf.sprintf
             "no segment of %s runs on the flap from the vertex to where the spine lands"
             target_str)
    | segs -> List.map (cand target_cid) segs
  in
  (* the stayer: the sector of the anchor beyond the target line, away from
     the spine, named by a table point inside it *)
  let stayer =
    let away = -Geom.side_of_line target_line f in
    let faces2 = Fold_state.faces st2 in
    let rec find i =
      if i >= Array.length faces2 then None
      else if in_anchor i then
        let clip =
          Geom.clip_convex_halfplane target_line away (Fold_state.table_polygon_ccw st2 i)
        in
        if Array.length clip >= 3 && Num.sign (Geom.signed_area clip) <> 0 then
          Some (centroid clip)
        else find (i + 1)
      else find (i + 1)
    in
    match find 0 with
    | Some p -> p
    | None ->
        Error.fail span
          (Printf.sprintf "the flap has no material beyond %s; nothing holds the squash"
             target_str)
  in
  let spine_elem = [ cand c.cid c.seg ] in
  ignore
    (Flatten_solve.solve ctx ~into:None ~verb:"squash"
       ~elem_cands:[ spine_elem; axis_elem cid_a; axis_elem cid_b; target_elem ]
       ~o ~elem_names:[ spine_str; "the axis"; "the axis"; target_str ]
       ~over:[] ~anchor:(Some anchor_polys)
       ~staying:(Some (Collapse.Points [ stayer ]))
       ~toward:None span);
  (* one crease on both layers from here on: `--s` is the whole axis, and
     `--s & .p` the piece of it on the layer of `.p` *)
  ctx.state := Fold_state.merge_crease !(ctx.state) ~from:cid_b ~into:cid_a;
  bind_out (Material (cid_a, axis));
  push_frame ctx (Some span)
