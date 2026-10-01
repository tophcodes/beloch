(** The `flatten` solver orchestration: single-vertex multi-crease fold, one
    solver pipeline (spec §4.9). *)

open Ctx

let run (ctx : Ctx.ctx) ~(into : (int * (Geom.line -> unit)) option)
    ~(bind_out : Ctx.crease_val -> unit)
    ~(elems : Ast.collapse_elem list)
    ~(overs : (Ast.flap_arg * Ast.flap_arg) list)
    ~(staying_opt : Ast.point_operand list option) ~(on_opt : Ast.flap_arg option)
    ~(toward_opt : Ast.point_operand option) (span : Error.span) : unit =
  (* materialize every collapse crease FIRST (a mark subdivides on
     segment-selection), so all of them cross and the shared collapse
     vertex is fully formed before any ray is selected. Selecting rays
     one-by-one would subdivide the first crease before the others exist,
     and leave it unsplit at the vertex (`no common interior vertex`). *)
  let rec force_material (lo : Ast.line_operand) =
    match lo with
    | Ast.LNamed cr ->
        ignore (Resolve.crease_of ctx cr ~slot:"a flatten ray" cr.Ast.cspan);
        ignore (Resolve.material_cid ctx cr)
    | Ast.LFilter (b, _, _) -> force_material b
    | Ast.LUnion (los, _) -> List.iter force_material los
    | Ast.LSelect _ -> ()
  in
  List.iter (fun (el : Ast.collapse_elem) -> force_material el.Ast.cline) elems;
  (* a resolved ray keeps its M/V CONSTRAINT, which the solver below turns
     into a concrete valley, as a 4-tuple rather than [Collapse.elem] so
     its fields can't be confused with that type's same-named
     [cid]/ea/eb once both are in scope below. *)
  let fail_not_material (el : Ast.collapse_elem) () =
    Error.fail span
      (Printf.sprintf
         "collapse folds along existing creases; %s is not a material \
          crease" (Resolve.lstr el.Ast.cline))
  in
  (* each element resolves to 1..k material SEGMENTS at the vertex, no
     eager multi-segment error any more: the stayer filter and the vertex
     check prune the wrong segment combinations. Only non-material operands error,
     with the old zero-segment texts verbatim. *)
  let resolve_elem_candidates (el : Ast.collapse_elem) :
      (int * Geom.point * Geom.point * Ast.mv_constraint) list =
    let seg_tuple cid (s : Fold_state.crease_segment) =
      (cid, s.Fold_state.ta, s.Fold_state.tb, el.Ast.cdir)
    in
    match el.Ast.cline with
    | Ast.LNamed cr -> (
        let cid = Resolve.material_cid ctx cr in
        match Fold_state.crease_segments !(ctx.state) cid with
        | [] ->
            Error.fail span
              (Printf.sprintf "--%s has no material segment" cr.Ast.cname)
        | segs -> List.map (seg_tuple cid) segs)
    | (Ast.LFilter _ | Ast.LUnion _) as lo -> (
        match Resolve.bundle_segments ctx lo with
        | _, [] ->
            Error.fail span
              (Printf.sprintf "no segment of %s matches" (Resolve.lstr lo))
        | Some cid, segs -> List.map (seg_tuple cid) segs
        | None, _ ->
            (* segments from a cross-crease union: no single [cid] to fold
               along *)
            fail_not_material el ())
    | _ -> fail_not_material el ()
  in
  let elem_cands = List.map resolve_elem_candidates elems in
  let elem_of (fcid, fea, feb, valley) =
    { Collapse.cid = fcid; ea = fea; eb = feb; valley }
  in
  (* vertex O: the point shared by >= 1 candidate segment of EVERY element,
     off the sheet's raw edge on the paper (generalizes
     [Collapse.common_vertex] to the per-element candidate lists). *)
  let interior_pt (p : Geom.point) =
    let cids =
      List.concat_map
        (List.filter_map (fun (cid, a, b, _) ->
             if Geom.point_equal a p || Geom.point_equal b p then Some cid
             else None))
        elem_cands
      |> List.sort_uniq compare
    in
    Collapse.interior_vertex !(ctx.state) cids p
  in
  let o =
    let shared_by_all p =
      List.for_all
        (fun cands ->
          List.exists
            (fun (_, a, b, _) ->
              Geom.point_equal a p || Geom.point_equal b p)
            cands)
        elem_cands
    in
    let endpoints =
      List.concat_map (fun (_, a, b, _) -> [ a; b ]) (List.hd elem_cands)
    in
    match
      List.find_opt
        (fun p -> shared_by_all p && interior_pt p)
        endpoints
    with
    | Some o -> o
    | None -> Error.fail span Collapse.e_no_vertex
  in
  (* keep only the candidate segments that end at O; every
     element has >= 1 such by O's construction. *)
  let elem_cands_at_o =
    List.map
      (List.filter (fun (_, a, b, _) ->
           Geom.point_equal a o || Geom.point_equal b o))
      elem_cands
  in
  let far_at_o (a : Geom.point) (b : Geom.point) : Geom.point =
    if Geom.point_equal a o then b else a
  in
  (* a crease scored through several layers has one piece per layer on the
     same table ray; the solver reads rays in table space, so those pieces
     are one ray and one candidate *)
  let elem_cands_at_o =
    List.map
      (fun cands ->
        List.fold_left
          (fun kept ((cid, a, b, _) as c) ->
            if
              List.exists
                (fun (cid', a', b', _) ->
                  cid' = cid && Geom.point_equal (far_at_o a b) (far_at_o a' b'))
                kept
            then kept
            else kept @ [ c ])
          [] cands)
      elem_cands_at_o
  in
  let far_of_combo_elem (_, a, b, _) = far_at_o a b in
  (* combinations: one chosen segment per element (product; <= 2 per
     element in practice, so the corpus tops out at 2 combinations). *)
  let rec product = function
    | [] -> [ [] ]
    | xs :: rest ->
        List.concat_map
          (fun x -> List.map (fun r -> x :: r) (product rest))
          xs
  in
  let combos = product elem_cands_at_o in
  let over =
    List.map
      (fun (u, l) -> (Resolve.resolve_sector_face ctx u span, Resolve.resolve_sector_face ctx l span))
      overs
  in
  (* the anchor flap `on` names, as paper polygons: the odd case scores the
     emergent ray into a copy of the state, whose faces the kernel finds
     inside these. The flap must lie under the vertex. *)
  let anchor =
    match on_opt with
    | None -> None
    | Some fa ->
        let st = !(ctx.state) in
        let faces = Resolve.resolve_flap_cluster ctx fa span in
        let under =
          List.exists
            (fun f ->
              Geom.in_convex_polygon (Fold_state.table_polygon_ccw st f) o)
            faces
        in
        if not under then
          Error.fail span "the on flap does not lie under the vertex"
        else Some (List.map (fun f -> (Fold_state.faces st).(f)) faces)
  in
  (* explicit staying (ADR 0048): points on the anchor, whose table images
     name the one sector that stays; ray order carries no stayer meaning
     then. The sector itself is checked per candidate fan by the kernel. *)
  let staying_stayer =
    match staying_opt with
    | None -> None
    | Some pos ->
        let st = !(ctx.state) in
        let on_anchor = Collapse.anchor_faces st o anchor in
        let faces = Fold_state.faces st in
        let images =
          List.map
            (fun po ->
              let pp = Resolve.resolve_point ctx po in
              let held = ref false in
              Array.iteri
                (fun i f ->
                  if on_anchor.(i) && Geom.in_convex_polygon f pp then
                    held := true)
                faces;
              if not !held then
                Error.fail ~hint:"name a point on the flap the fan folds" span
                  (Printf.sprintf "%s does not lie on the anchor"
                     (Resolve.fstr (Ast.FlapPoint po)));
              Fold_state.table_position st pp)
            pos
        in
        Some (Collapse.Points images)
  in
  let n_given = List.length elems in
  let odd = n_given mod 2 = 1 in
  let prov : State.provenance option =
    Some
      { State.axiom = "flatten"; sources = []; span; name = None;
        stmt = Ctx.stmt_index ctx }
  in
  (* the layers under the fan (def-flatten's C): the faces of the state
     before the flatten whose table image meets the image of the anchor in
     positive area. Every scoring below stays inside them. *)
  let pre_st = !(ctx.state) in
  let pre = Fold_state.faces pre_st in
  let under_fan =
    let on_anchor = Collapse.anchor_faces pre_st o anchor in
    let tp = Fold_state.table_polygon_ccw pre_st in
    Array.init (Array.length pre) (fun i ->
        let pi = tp i in
        let hit = ref false in
        Array.iteri
          (fun j a ->
            if a && not !hit then hit := Geom.convex_overlap pi (tp j))
          on_anchor;
        !hit)
  in
  let centroid (f : Geom.point array) =
    let m = Num.of_int (Array.length f) in
    let sum get =
      Array.fold_left (fun acc p -> Num.add acc (get p)) Num.zero f
    in
    { Geom.x = Num.div (sum (fun p -> p.Geom.x)) m;
      y = Num.div (sum (fun p -> p.Geom.y)) m }
  in
  (* a ray to score: its crease id, its table line, and a point on it past
     O *)
  let ray_cut cid (far : Geom.point) = (cid, Geom.line_through o far, far) in
  (* score [cuts] into the state before the flatten, each ray into its own
     crease along its half-line from O, on the faces [within] holds *)
  let score_rays cuts (within : bool array) =
    Fold_state.subdivide_fan pre_st ~o ~rays:cuts ~only:(fun i -> within.(i))
      ~prov
  in
  (* the faces before the flatten that hold a face of [tip], a face set of
     a scored state [st] *)
  let parents_of (st : Fold_state.t) (tip : bool array) =
    let faces = Fold_state.faces st in
    Array.map
      (fun (f : Geom.point array) ->
        let holds = ref false in
        Array.iteri
          (fun t (tf : Geom.point array) ->
            if tip.(t) && Geom.in_convex_polygon f (centroid tf) then
              holds := true)
          faces;
        !holds)
      pre
  in
  (* the tip of every admissible stayer sector of [st_all], grouped by the
     faces before the flatten that hold it: sectors whose tips lie in the
     same faces are solved on one state *)
  let tip_groups st_all es_geom stayer =
    List.rev
      (List.fold_left
         (fun acc (s0, tip) ->
           let ps = parents_of st_all tip in
           match List.partition (fun (p, _) -> p = ps) acc with
           | [ (_, ss) ], rest -> (ps, s0 :: ss) :: rest
           | _ -> (ps, [ s0 ]) :: acc)
         []
         (Collapse.tips ?anchor st_all es_geom ~stayer))
  in
  (* the emergent crease id, fixed ONCE (odd case only; the even case
     scores its rays into their own creases and makes no new one), so every
     candidate's probe subdivision (below) and the eventual winner share one
     id instead of drifting the global counter per candidate. Under `into`
     it is the named crease's own id, so the emergent material lands on that
     crease. *)
  let new_cid =
    lazy
      (match into with
      | Some (cid, _) -> cid
      | None -> Fold_state.fresh_crease_id ())
  in
  (* the stayer for a bare combination: the <π arc between the first two
     ELEMENTS' chosen folded rays (leading-element convention). *)
  let arc_stayer combo =
    match combo with
    | e1 :: e2 :: _ ->
        Collapse.Arc (far_of_combo_elem e1, far_of_combo_elem e2)
    | _ -> Collapse.Arc (o, o)
  in
  (* KERNEL LIMITATION cover (Task-2 reviewer finding): the kernel's
     [admissible_sectors] cannot tell "the emergent splits the leading
     arc" (legitimate, 2 mirror worlds) from "another GIVEN element's ray
     sits strictly inside the arc" (dead: stayed material cannot carry a
     folding crease, spec §Semantics). The latter kill is ours, done here
     over the GIVEN rays before the kernel runs. Gated on a genuine
     segment choice (>1 combination): with a single combination the input
     has no alternative and the pre-2026-07-17 convention behaviour stands.
     Absent under [staying]: the convention carries no meaning then. *)
  let leading_arc_ok combo =
    match (staying_opt, combo) with
    | Some _, _ -> true
    | None, e1 :: e2 :: rest ->
        let f1 = far_of_combo_elem e1 and f2 = far_of_combo_elem e2 in
        let oc = (o.Geom.x, o.Geom.y) in
        let c =
          Collapse.cross oc (f1.Geom.x, f1.Geom.y) (f2.Geom.x, f2.Geom.y)
        in
        if Num.sign c = 0 then true (* collinear -> kernel: [e_stayer_collinear] *)
        else
          let a, b = if Num.sign c > 0 then (f1, f2) else (f2, f1) in
          not
            (List.exists
               (fun e -> Collapse.in_ccw_arc o a b (far_of_combo_elem e))
               rest)
    | None, _ -> true
  in
  (* run one combination: pool every (state, tier, emergent-binding) that
     a candidate x M/V-pattern attempt closed, and every failure message.
     [given_fars] is this combination's given rays' far tips (the emergent
     scan excludes them). *)
  let run_combo combo (stayer : Collapse.stayer) =
    let local_real :
        (Fold_state.t
        * [ `Tier1 | `Tier2 ]
        * (int * Geom.line) option
        * (Trace.segment list * Trace.segment option))
        list ref =
      ref []
    in
    let local_err = ref [] in
    let elems_geom =
      List.map (fun (a, b, c, _) -> elem_of (a, b, c, true)) combo
    in
    let given_fars = List.map (Collapse.far_of o) elems_geom in
    let given_rays =
      List.map (fun (_, a, b, _) -> (o, far_at_o a b)) combo
    in
    let given_cuts =
      List.map (fun (cid, a, b, _) -> ray_cut cid (far_at_o a b)) combo
    in
    let try_patterns ?sectors (st' : Fold_state.t) (tier : [ `Tier1 | `Tier2 ])
        (emergent : (int * Geom.line) option)
        (emergent_seg : Trace.segment option)
        (all_rays :
          (int * Geom.point * Geom.point * Ast.mv_constraint) list) =
      let constraints = List.map (fun (_, _, _, d) -> d) all_rays in
      let patterns = Flatten.mv_patterns constraints in
      (* one call solves every Maekawa pattern over the fixed vertex
         geometry, sharing placements/overlaps across patterns instead of
         refolding per pattern; [es_geom]'s valley is a placeholder (the
         real per-ray valley rides in [patterns]). *)
      let es_geom =
        List.map (fun (fcid, fea, feb, _) -> elem_of (fcid, fea, feb, true))
          all_rays
      in
      List.iter
        (fun res ->
          match res with
          | Ok sts ->
              List.iter
                (fun s -> local_real :=
                    (s, tier, emergent, (given_rays, emergent_seg))
                    :: !local_real)
                sts
          | Error msg -> local_err := msg :: !local_err)
        (Collapse.collapse_all_patterns ?anchor ?sectors st' es_geom ~over
           ~stayer ~patterns)
    in
    (if odd then
       let fixed = Collapse.sort_ccw o elems_geom in
       match Flatten.candidates o ~fixed with
       | [] -> local_err := Flatten.e_infeasible :: !local_err
       | cands ->
           List.iter
             (fun (line, ray_pt, tag) ->
               let tier : [ `Tier1 | `Tier2 ] =
                 match tag with
                 | `LineNew -> `Tier1
                 | `OppositeRay -> `Tier2
               in
               (* score this candidate ray with the given rays on a local
                  copy of the pre-flatten state, then scan every crease ray
                  now sitting at O on the candidate's side of the
                  perpendicular [guard]. Collinear-reuse (the rabbit-ear
                  up-spine) is found among EXISTING segments, not
                  [new_cid]. *)
               let guard = Geom.perpendicular_through line o in
               let keep = Geom.side_of_line guard ray_pt in
               let far_of_seg (s : Fold_state.crease_segment) =
                 if Geom.point_equal s.Fold_state.ta o then s.Fold_state.tb
                 else s.Fold_state.ta
               in
               let matches_in st' =
                 Fold_state.all_crease_ids st'
                 |> List.concat_map (fun cid ->
                        Fold_state.crease_segments st' cid
                        |> List.filter_map
                             (fun (s : Fold_state.crease_segment) ->
                               let far = far_of_seg s in
                               if
                                 (Geom.point_equal s.Fold_state.ta o
                                 || Geom.point_equal s.Fold_state.tb o)
                                 && Geom.side_of_line line far = 0
                                 && Geom.side_of_line guard far = keep
                                 && not
                                      (List.exists (Geom.point_equal far)
                                         given_fars)
                               then Some (cid, far)
                               else None))
               in
               (* the crease the emergent ray is scored into: a crease the
                  program already scored along the ray on some layer, so
                  that the ray is one crease on every layer of the tip, and
                  a new one otherwise. Under `into` it is the named crease. *)
               let emergent_cid =
                 let fresh = Lazy.force new_cid in
                 match into with
                 | Some _ -> fresh
                 | None -> (
                     match
                       List.sort_uniq compare
                         (List.map fst (matches_in !(ctx.state)))
                     with
                     | [ cid ] -> cid
                     | _ -> fresh)
               in
               (* the emergent ray first, then the given rays: on a state
                  that carries the given rays on every layer already, their
                  cuts change nothing *)
               let cuts = (emergent_cid, line, ray_pt) :: given_cuts in
               (* the tip is read off the state scored through every layer
                  under the fan, and the rays are then scored on the layers
                  of the tip alone (ADR 0037): a face of the pre-flatten
                  state is scored when a face of the tip lies in it. Stayer
                  sectors whose tips differ are solved on states of their
                  own. *)
               let st_all = score_rays cuts under_fan in
               List.iter
                 (fun (cid, far) ->
                   let emergent_ray = (cid, o, far, Ast.MvFree) in
                   let all_rays = emergent_ray :: combo in
                   let run ?sectors st' =
                     try_patterns ?sectors st' tier (Some (cid, line))
                       (Some (o, far)) all_rays
                   in
                   let es_geom =
                     List.map
                       (fun (fcid, fea, feb, _) ->
                         elem_of (fcid, fea, feb, true))
                       all_rays
                   in
                   match tip_groups st_all es_geom stayer with
                   | [] -> run st_all
                   | groups ->
                       List.iter
                         (fun (ps, ss) ->
                           let st' = score_rays cuts ps in
                           let found =
                             List.exists
                               (fun (c, f) ->
                                 c = cid && Geom.point_equal f far)
                               (matches_in st')
                           in
                           run ~sectors:ss (if found then st' else st_all))
                         groups)
                 (* a ray scored through several layers has one piece per
                    layer, all ending at the same table point: one
                    candidate *)
                 (List.fold_left
                    (fun kept (c, f) ->
                      if
                        List.exists
                          (fun (c', f') -> c = c' && Geom.point_equal f f')
                          kept
                      then kept
                      else kept @ [ (c, f) ])
                    [] (matches_in st_all)))
             cands
     else
       (* the even fan scores its given rays the same way: through every
          layer under the fan to find the tip, then on the layers of the
          tip alone. A fan that fails before its tip is defined is solved
          on the state as it stands, which reports that failure. *)
       match tip_groups (score_rays given_cuts under_fan) elems_geom stayer with
       | [] -> try_patterns pre_st `Tier1 None None combo
       | groups ->
           List.iter
             (fun (ps, ss) ->
               try_patterns ~sectors:ss (score_rays given_cuts ps) `Tier1 None
                 None combo)
             groups);
    (!local_real, !local_err, given_fars)
  in
  (* enumerate combinations; each yields realizations + errors. A
     combination is dropped (contributes nothing) when the leading-arc filter
     rejects it. *)
  let multiseg =
    let rec find els cands =
      match (els, cands) with
      | el :: es, cs :: cr ->
          if List.length cs > 1 then Resolve.lstr el.Ast.cline else find es cr
      | _ -> "--?"
    in
    find elems elem_cands_at_o
  in
  let combo_runs =
    List.map
      (fun combo ->
        let stayer =
          match staying_stayer with
          | Some s -> s
          | None -> arc_stayer combo
        in
        if List.length combos > 1 && not (leading_arc_ok combo) then
          (combo, [], [])
        else
          let r, e, _ = run_combo combo stayer in
          (combo, r, e))
      combos
  in
  let surviving = List.filter (fun (_, r, _) -> r <> []) combo_runs in
  (* the candidate states and the stage of the selection that removed each
     (spec/FOLD.md, "The trace"), recorded once, when a state lands or the
     statement fails *)
  let candidates = List.concat_map (fun (_, r, _) -> r) surviving in
  let removed = ref [] in
  let remove why ~kept rs =
    List.iter
      (fun r ->
        if not (List.memq r kept || List.mem_assq r !removed) then
          removed := (r, why) :: !removed)
      rs
  in
  let traced = ref false in
  let trace chosen =
    if not !traced then begin
      traced := true;
      Ctx.record_write ctx (Trace.Flatten { point = o })
        (List.map
           (fun ((st, _, _, (rays, emergent)) as r) ->
             { Trace.state = Some st;
               detail = Trace.fan ~pre:!(ctx.state) ~post:st ~point:o ~rays ~emergent;
               removed = List.assq_opt r !removed;
               chosen = (match chosen with Some c -> c == r | None -> false) })
           candidates)
    end
  in
  (* a genuine segment contradiction: two combinations both close with
     non-empty pools -> the user must disambiguate with `&`. *)
  (match surviving with
  | _ :: _ :: _ ->
      trace None;
      Error.fail ~hint:"select a segment with `&`" span
        (Printf.sprintf "%s is ambiguous at the vertex" multiseg)
  | _ -> ());
  (* the winning combination (or the leading one when none survive, so the
     selection code's [rays]/[given_fars] are well-defined for the
     error-reporting path). *)
  let winner_combo =
    match surviving with (c, _, _) :: _ -> c | [] -> List.hd combos
  in
  let rays = winner_combo in
  let given_fars =
    List.map
      (fun (a, b, c, _) -> Collapse.far_of o (elem_of (a, b, c, true)))
      winner_combo
  in
  let realizations =
    match surviving with (_, r, _) :: _ -> r | [] -> []
  in
  let error_pool = List.concat_map (fun (_, _, e) -> e) combo_runs in
  let tier1, tier2 = List.partition (fun (_, t, _, _) -> t = `Tier1) realizations in
  let deciding = if tier1 <> [] then tier1 else tier2 in
  if tier1 <> [] then remove Trace.By_opposite ~kept:tier1 tier2;
  (* records the emergent crease's (id, line) here so the name (if
     any) binds to it instead of the given rays; None if no candidate
     ray was materialized (even case) or left unbound. *)
  let emergent_bind = ref None in
  (* `into`'s axis check runs on the emergent line before the winning state
     lands: the emergent line comes from the pre-flatten table geometry, and
     the check must compare it against material in the same frame, so it
     runs before the collapsed state replaces it. With no emergent ray there
     is nothing for `into` to add. *)
  let land_realization ((st, _, emergent, _) as r) =
    trace (Some r);
    (match (into, emergent) with
    | Some (_, check_axis), Some (_, line) -> check_axis line
    | Some _, None ->
        Error.fail ~hint:"drop into" span
          "flatten with an even ray count scores no new crease"
    | None, _ -> ());
    ctx.state := st;
    emergent_bind := emergent
  in
  (try
  match deciding with
  | [] ->
      (* spec step 6: out-of-paper trumps everything; otherwise the
         odd/even cases report differently: the odd case collapses
         every closure failure into one message (364660f's original
         differentiation, preserved verbatim); the even case surfaces
         the pool's own dominant kernel error instead, since there is
         no derived-crease framing to fall back on. *)
      let pool = error_pool in
      if List.mem Collapse.e_out_of_paper pool then
        Error.fail span Collapse.e_out_of_paper
      else (
        match
          (* the tip and stayer diagnoses outrank the generic "derived
             crease does not close": a layer of the tip without the rays,
             an anchor with nothing to move, a collinear leading pair, and
             a dead [staying] flap each name a specific fixable cause. *)
          List.find_opt
            (fun m ->
              m = Collapse.e_unaligned
              || m = Collapse.e_anchor_stays
              || m = Collapse.e_stayer_collinear
              || m = Collapse.e_stayer_dead
              || m = Collapse.e_staying_none
              || m = Collapse.e_staying_several
              || m = Collapse.e_staying_off_anchor)
            pool
        with
      | Some m -> Error.fail ?hint:(Collapse.hint_of m) span m
      | None ->
      if odd then
        Error.fail span "the derived crease does not close the vertex"
      else begin
        match List.find_opt (fun m -> m <> Collapse.e_selfint) pool with
        | Some m -> Error.fail ?hint:(Collapse.hint_of m) span m
        | None ->
            (* pool = [] only when every candidate's pin set was itself
               Maekawa-unsatisfiable (no pattern to even try); a pool of
               all-[e_selfint] falls back to [e_selfint] itself. *)
            Error.fail span
              (if pool = [] then Collapse.e_maekawa else Collapse.e_selfint)
      end)
  | [ r ] -> land_realization r
  | many
    when (* the fan fixes its stayer before any selection stage runs (ADR
            0048): states with different stayers leave the statement
            ambiguous *)
         let stayer_of (st, _, _, (rays, emergent)) =
           match
             Trace.fan ~pre:!(ctx.state) ~post:st ~point:o ~rays ~emergent
           with
           | Trace.Fan { stayer; _ } -> Some stayer
           | _ -> None
         in
         let same (a, b) (c, d) = Geom.point_equal a c && Geom.point_equal b d in
         let stayers =
           List.fold_left
             (fun acc r ->
               match stayer_of r with
               | Some s when not (List.exists (same s) acc) -> s :: acc
               | _ -> acc)
             [] many
         in
         List.length stayers > 1 ->
      trace None;
      Error.fail ~hint:"add (staying .p) with .p in the sector that stays" span
        "flatten is ambiguous: its candidates hold different sectors still"
  | many ->
      (* |deciding| > 1: three-stage selection, derived empirically against
         the fish mirror pair and the swivel golden:
         1. POSITION stage: placements depend only on ray LINES, so
            realizations group into position classes by moved-material
            centroid; (toward) picks the class by centroid dot.
         2. MIN-MOUNTAIN CANON: within the class, keep only the
            realizations with the fewest derived mountains among the
            USER-GIVEN creases (a freshly-materialized emergent [cid] is
            not a given [cid], so it is excluded automatically; a
            collinear-reuse emergent (the fish diagonal) IS a given
            [cid] and counts, per the rule doc's fish derivation).
         3. RANK-DIPOLE stage: if several remain, maximize
            {m S(R) = Σ_faces area · (rank − (nf−1)/2) ·
            ((table_centroid − O)·(toward − O)) }: "the material lying
            toward p ends up on top." Mirror realizations score ±equal,
            so any off-axis toward decides; toward ON a reflective
            symmetry axis of the given rays is guarded explicitly. *)
      let paper_centroid_area (poly : Geom.point array) :
          Geom.point * Num.t =
        let n = Array.length poly in
        let a2 = ref Num.zero and cx = ref Num.zero and cy = ref Num.zero in
        for i = 0 to n - 1 do
          let p = poly.(i) and q = poly.((i + 1) mod n) in
          let cross =
            Num.sub (Num.mul p.Geom.x q.Geom.y) (Num.mul q.Geom.x p.Geom.y)
          in
          a2 := Num.add !a2 cross;
          cx := Num.add !cx (Num.mul (Num.add p.Geom.x q.Geom.x) cross);
          cy := Num.add !cy (Num.mul (Num.add p.Geom.y q.Geom.y) cross)
        done;
        let area = Num.div !a2 (Num.of_int 2) in
        let denom = Num.mul (Num.of_int 3) !a2 in
        ({ Geom.x = Num.div !cx denom; y = Num.div !cy denom }, area)
      in
      (* stage-2 canon: derived (never stored) M/V per hinge:
         [Fold_state.mv] reads rank + orientation, so two stackings of
         one pattern can differ. A given [cid] is a mountain iff some
         FOLDED hinge of that [cid] derives M. *)
      let given_cids =
        List.sort_uniq compare (List.map (fun (c, _, _, _) -> c) rays)
      in
      let given_mountains (st, _, _, _) : int =
        List.length
          (List.filter
             (fun cid ->
               let hs = Fold_state.hinges st in
               let m = ref false in
               Array.iteri
                 (fun i (h : Fold_state.hinge) ->
                   if
                     h.Fold_state.crease_id = cid
                     && Num.sign h.Fold_state.angle <> 0
                     && Fold_state.mv st i = Fold_state.M
                   then m := true)
                 hs;
               !m)
             given_cids)
      in
      let min_mountain_filter rs =
        let counted = List.map (fun r -> (given_mountains r, r)) rs in
        let m = List.fold_left (fun acc (c, _) -> min acc c) max_int counted in
        let kept =
          List.filter_map (fun (c, r) -> if c = m then Some r else None) counted
        in
        remove Trace.By_mountains ~kept rs;
        kept
      in
      let commit = land_realization in
      (match toward_opt with
      | None -> (
          (* no class to pick without (toward); the min-mountain canon
             is toward-independent, so it may still single out THE
             least-forced realization: only a post-canon surplus is a
             genuine ambiguity (spec: "no (toward) while |S| > 1 after
             stage 2"). *)
          match min_mountain_filter many with
          | [ r ] -> commit r
          | kept ->
              Error.fail ~hint:"add (toward .p) to pick the fold direction"
                span
                (Printf.sprintf "flatten is ambiguous: %d realizations"
                   (List.length kept)))
      | Some toward_po ->
          let toward_pt = Resolve.resolve_point ctx toward_po in
          let st_pre = !(ctx.state) in
          (* stage 1: moved-material centroid per realization; a pure
             function of table placement, shared within a class. *)
          let centroid_of (st_post, _, _, _) : Geom.point =
            let faces = Fold_state.faces st_post in
            let nf = Array.length faces in
            let sx = ref Num.zero and sy = ref Num.zero and sa = ref Num.zero in
            for f = 0 to nf - 1 do
              let c_f, a_f = paper_centroid_area faces.(f) in
              let pre_pos = Fold_state.table_position st_pre c_f in
              let post_pos =
                Isometry.apply_point (Fold_state.face_iso2 st_post f) c_f
              in
              if not (Geom.point_equal pre_pos post_pos) then begin
                sx := Num.add !sx (Num.mul a_f post_pos.Geom.x);
                sy := Num.add !sy (Num.mul a_f post_pos.Geom.y);
                sa := Num.add !sa a_f
              end
            done;
            if Num.sign !sa = 0 then
              invalid_arg
                "Flatten: a completed collapse moved no material \
                 (unreachable)"
            else { Geom.x = Num.div !sx !sa; y = Num.div !sy !sa }
          in
          let dot_toward (p : Geom.point) : Num.t =
            Num.add
              (Num.mul (Num.sub p.Geom.x o.Geom.x)
                 (Num.sub toward_pt.Geom.x o.Geom.x))
              (Num.mul (Num.sub p.Geom.y o.Geom.y)
                 (Num.sub toward_pt.Geom.y o.Geom.y))
          in
          let by_centroid = List.map (fun r -> (centroid_of r, r)) many in
          let distinct_centroids =
            List.fold_left
              (fun acc (c, _) ->
                if List.exists (Geom.point_equal c) acc then acc else c :: acc)
              [] by_centroid
          in
          let class_scored =
            List.map (fun c -> (dot_toward c, c)) distinct_centroids
            |> List.sort (fun (d1, _) (d2, _) -> Num.compare d2 d1)
          in
          let winning_centroid =
            match class_scored with
            | (d0, _) :: (d1, _) :: _ when Num.compare d0 d1 = 0 ->
                remove Trace.By_toward
                  ~kept:
                    (List.filter_map
                       (fun (c, r) ->
                         if Num.compare (dot_toward c) d0 = 0 then Some r
                         else None)
                       by_centroid)
                  many;
                (* two DISTINCT position classes tie: toward is
                   collinear with a crease through O (the classes are
                   mirror-symmetric about it) *)
                Error.fail ~hint:Flatten.e_toward_ambiguous_hint span
                  Flatten.e_toward_ambiguous
            | (_, c) :: _ -> c
            | [] -> assert false (* [many] is non-empty here *)
          in
          let winners =
            List.filter_map
              (fun (c, r) ->
                if Geom.point_equal c winning_centroid then Some r else None)
              by_centroid
          in
          remove Trace.By_toward ~kept:winners many;
          (* stage 2 *)
          (match min_mountain_filter winners with
          | [] -> assert false (* filter of a non-empty list *)
          | [ r ] -> commit r
          | kept ->
              (* stage 3, but first the symmetry-axis guard (rule doc
                 §Ties): the dipole's null direction is NOT the
                 geometric mirror axis, so an on-axis toward would get
                 a strict-but-arbitrary [argmax]; if the given-ray
                 direction set is invariant under reflection across the
                 O-toward line, the sides are
                 indistinguishable. *)
              let on_symmetry_axis =
                Geom.point_equal toward_pt o
                ||
                let axis = Geom.line_through o toward_pt in
                let refl = Isometry.reflect_across_line axis in
                List.for_all
                  (fun far ->
                    let rf = Isometry.apply_point refl far in
                    List.exists
                      (fun g -> Geom.ccw_compare ~center:o rf g = 0)
                      given_fars)
                  given_fars
              in
              if on_symmetry_axis then
                Error.fail ~hint:Flatten.e_toward_ambiguous_hint span
                  Flatten.e_toward_ambiguous
              else
                let dipole (st, _, _, _) : Num.t =
                  let faces = Fold_state.faces st in
                  let rank = Fold_state.rank st in
                  let nf = Array.length faces in
                  let center =
                    Num.div (Num.of_int (nf - 1)) (Num.of_int 2)
                  in
                  let acc = ref Num.zero in
                  for f = 0 to nf - 1 do
                    let pc, a_f = paper_centroid_area faces.(f) in
                    let a_f = if Num.sign a_f < 0 then Num.neg a_f else a_f in
                    let tc =
                      Isometry.apply_point (Fold_state.face_iso2 st f) pc
                    in
                    acc :=
                      Num.add !acc
                        (Num.mul a_f
                           (Num.mul
                              (Num.sub (Num.of_int rank.(f)) center)
                              (dot_toward tc)))
                  done;
                  !acc
                in
                let scored =
                  List.map (fun r -> (dipole r, r)) kept
                  |> List.sort (fun (d1, _) (d2, _) -> Num.compare d2 d1)
                in
                (match scored with
                | (d0, _) :: (d1, _) :: _ when Num.compare d0 d1 = 0 ->
                    remove Trace.By_top
                      ~kept:
                        (List.filter_map
                           (fun (d, r) -> if Num.compare d d0 = 0 then Some r else None)
                           scored)
                      kept;
                    Error.fail ~hint:Flatten.e_toward_ambiguous_hint span
                  Flatten.e_toward_ambiguous
                | (_, r) :: _ ->
                    remove Trace.By_top ~kept:[ r ] kept;
                    commit r
                | [] -> assert false (* [kept] has >= 2 elements *))))
  with Error.Beloch_error _ as e ->
    trace None;
    raise e);
  (* run the output clause's binding step: with no emergent ray materialized
     it takes a selectable bundle of the given rays; with one it takes the
     EMERGENT crease (the newly-completed vertex's own crease, not the rays
     that produced it), so a meet-point selector against the name
     (e.g. `.[--ear --ab]`) finds the emergent crease's tip. *)
  bind_out
    (match !emergent_bind with
    | Some (ecid, line) ->
        (* `into` keeps the named crease's id: a freshly materialized
           emergent already carries it, and an emergent that reuses an
           existing collinear crease scores no material to move the name
           to. *)
        let cid = match into with Some (cid, _) -> cid | None -> ecid in
        Material (cid, line)
    | None ->
        Bundle
          (Ast.LUnion
             (List.map (fun (el : Ast.collapse_elem) -> el.Ast.cline) elems, span)));
  push_frame ctx (Some span)
