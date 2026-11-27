(** The `flatten` solver orchestration: single-vertex multi-crease fold, one
    solver pipeline (spec §4.9). *)

open Ctx

type elem_cand = int * Geom.point * Geom.point * Ast.mv_constraint

(* The candidate segments of every ray item of a `flatten`, resolved from
   its operands. *)
let resolve_elems (ctx : Ctx.ctx) ~(elems : Ast.collapse_elem list)
    (span : Error.span) : elem_cand list list =
  (* materialize every collapse crease FIRST (a mark subdivides on
     segment-selection), so all of them cross and the shared collapse
     vertex is fully formed before any ray is selected. Selecting rays
     one-by-one would subdivide the first crease before the others exist,
     and leave it unsplit at the vertex (`no common interior vertex`). *)
  let rec force_material (lo : Ast.line_operand) =
    match lo with
    | Ast.LNamed cr ->
        ignore (lookup_crease ctx cr);
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
  (* each element resolves to 1..k material SEGMENTS at the vertex, and
     several segments are no error: the stayer filter and the vertex check
     prune the wrong segment combinations. Only non-material operands error,
     with the zero-segment texts. *)
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
  List.map resolve_elem_candidates elems

(* vertex O: the point shared by >= 1 candidate segment of EVERY element,
   off the sheet's raw edge on the paper (generalizes
   [Collapse.common_vertex] to the per-element candidate lists). *)
let vertex_of (ctx : Ctx.ctx) ~(elem_cands : elem_cand list list)
    (span : Error.span) : Geom.point =
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

(* The fan on resolved operands (docs/reference/KERNEL.md, Fan): the
   candidate segments of every element, the vertex [o] they share, the
   `over` constraints as face pairs, the anchor as paper polygons, the
   stayer and the emergent item, a table point and its name. [verb] names the write in
   its messages and in the crease records; [elem_names] names the elements
   as the program wrote them, for the message that blames one. Returns the
   emergent crease when one was scored; the caller binds the output clause
   and pushes the frame. *)
let solve (ctx : Ctx.ctx) ~(into : (int * (Geom.line -> unit)) option)
    ~(verb : string) ~(elem_cands : elem_cand list list)
    ~(pieces : Fold_state.crease_segment list list) ~(o : Geom.point)
    ~(elem_names : string list) ~(over : (int * int) list)
    ~(anchor : Geom.point array list option)
    ~(staying : Collapse.stayer option) ?staying_paper
    ~(emergent : (Geom.point * string) option)
    (span : Error.span) : (int * Geom.line) option =
  let staying =
    match staying with
    | Some s -> s
    | None ->
        Error.fail ~hint:Collapse.hint_staying_missing span
          (Collapse.e_staying_missing verb)
  in
  let elem_of (fcid, fea, feb) = { Collapse.cid = fcid; ea = fea; eb = feb }
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
  let n_given = List.length elem_cands in
  let odd = n_given mod 2 = 1 in
  let prov : State.provenance option =
    Some
      { State.axiom = verb; sources = []; span; name = None;
        stmt = Ctx.stmt_index ctx }
  in
  let pre_st = !(ctx.state) in
  let pre = Fold_state.faces pre_st in
  (* The vertex on the paper (spec multifold,
     "A fan folds at a point of the paper"): the one paper point at which a
     piece of every element passes over [o]. Where several remain, the anchor
     of a squash picks the one on it; a flatten has no anchor and fails. *)
  let pv =
    let on_anchor = Collapse.anchor_faces pre_st o anchor in
    let on_it q =
      List.exists
        (fun i -> on_anchor.(i) && Geom.in_convex_polygon pre.(i) q)
        (List.init (Array.length pre) Fun.id)
    in
    match
      Fan_paper.vertex ~pick:(if anchor = None then (fun _ -> false) else on_it) span
        (List.map (fun segs -> Fan_paper.paper_points segs o) pieces)
    with
    | Some p -> p
    | None -> Error.fail span Collapse.e_no_vertex
  in
  (* the layers that meet at the vertex, as paper polygons: the kernel reads
     them where it reads an anchor (Kawasaki's condition where they surround
     the vertex, the staying sector's material) *)
  let anchor_pv =
    Some (List.filter (fun f -> Geom.in_convex_polygon f pv) (Array.to_list pre))
  in
  let on_half (far : Geom.point) (q : Geom.point) =
    Geom.side_of_line (Geom.line_through o far) q = 0
    && Num.sign
         (Num.add
            (Num.mul (Num.sub q.Geom.x o.Geom.x) (Num.sub far.Geom.x o.Geom.x))
            (Num.mul (Num.sub q.Geom.y o.Geom.y) (Num.sub far.Geom.y o.Geom.y)))
       >= 0
  in
  (* The tip on the scored state [g] for the rays [all_rays] (an emergent ray
     first, then the given ones in element order), given the sector [sec] of
     every face. A hinge of the fan is a piece of a ray's crease on its
     half-line that ends at the vertex's paper point, and for a given ray one
     of the pieces its item names. The parts of the paper those hinges
     separate stay where they hold a face of the staying sector with a
     staying point, or with the vertex when the statement names none; the
     rest is the tip. A hinge on a ray that does not end at the vertex's
     paper point keeps its angle. *)
  let tip_rule_for (all_rays : elem_cand list) (g : Fold_state.t) (sec : int array) =
    let hs = Fold_state.hinges g in
    let n_all = List.length all_rays in
    let indexed = List.mapi (fun k r -> (k - (n_all - n_given), r)) all_rays in
    let at_vertex i =
      let pa, pb = Fold_state.hinge_segment g i in
      Geom.point_equal pa pv || Geom.point_equal pb pv
    in
    let cut =
      Array.init (Array.length hs) (fun i ->
          let h = hs.(i) in
          let pa, pb = Fold_state.hinge_segment g i in
          let ta, tb = Fold_state.hinge_table_segment g i in
          at_vertex i
          && (Geom.point_equal ta o || Geom.point_equal tb o)
          && List.exists
               (fun (k, (cid, a, b, _)) ->
                 let far = if Geom.point_equal a o then b else a in
                 cid = h.Fold_state.crease_id
                 && on_half far ta && on_half far tb
                 && (k < 0
                    || List.exists
                         (fun (sg : Fold_state.crease_segment) ->
                           Geom.on_segment (sg.Fold_state.pa, sg.Fold_state.pb) pa
                           && Geom.on_segment (sg.Fold_state.pa, sg.Fold_state.pb) pb)
                         (List.nth pieces k)))
               indexed)
    in
    let faces = Fold_state.faces g in
    let part = Fan_paper.parts g ~cut:(fun i -> cut.(i)) in
    let seeds = staying_paper |> Option.value ~default:[ pv ] in
    let stays = Array.make (Array.length part) false in
    Array.iteri
      (fun i f ->
        if sec.(i) = 0 && List.exists (Geom.in_convex_polygon f) seeds then
          stays.(part.(i)) <- true)
      faces;
    let tip = Array.map (fun k -> not stays.(k)) part in
    (* the layer check is the rule of `flatten`; a squash keeps its anchor *)
    match
      if verb <> "flatten" then None
      else
      Fan_paper.unfolded_layer ctx ~pre:pre_st ~st:g ~v:[ o ]
        ~parent:(Fan_paper.parents pre g) ~tip ~fan_hinge:(fun i -> cut.(i))
    with
    | Some e -> Error e
    | None -> Ok (tip, (fun i -> cut.(i)), at_vertex)
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
  (* run one combination: pool every (state, emergent-binding, letters of
     the given rays) that
     a candidate x M/V-pattern attempt closed, and every failure message.
     [given_fars] is this combination's given rays' far tips (the emergent
     scan excludes them). *)
  let run_combo combo (stayer : Collapse.stayer) =
    let local_real :
        (Fold_state.t
        * (int * Geom.line) option
        * (Trace.segment list * Trace.segment option)
        * bool list)
        list ref =
      ref []
    in
    let local_err = ref [] in
    let elems_geom =
      List.map (fun (a, b, c, _) -> elem_of (a, b, c)) combo
    in
    let given_fars = List.map (Collapse.far_of o) elems_geom in
    let given_rays =
      List.map (fun (_, a, b, _) -> (o, far_at_o a b)) combo
    in
    let try_patterns ?sectors (st' : Fold_state.t)
        (emergent : (int * Geom.line) option)
        (emergent_seg : Trace.segment option)
        (all_rays :
          (int * Geom.point * Geom.point * Ast.mv_constraint) list) =
      let constraints = List.map (fun (_, _, _, d) -> d) all_rays in
      let patterns = Flatten.mv_patterns constraints in
      (* one call solves every Maekawa pattern over the fixed vertex
         geometry, sharing placements/overlaps across patterns instead of
         refolding per pattern; the letter of each ray rides in
         [patterns]. *)
      let es_geom =
        List.map (fun (fcid, fea, feb, _) -> elem_of (fcid, fea, feb))
          all_rays
      in
      (* the letters of the given rays: the pattern without the emergent ray,
         which stands first *)
      let given_letters pat =
        List.filteri (fun i _ -> i >= List.length pat - n_given) pat
      in
      List.iter2
        (fun pat res ->
          match res with
          | Ok sts ->
              List.iter
                (fun s -> local_real :=
                    (s, emergent, (given_rays, emergent_seg), given_letters pat)
                    :: !local_real)
                sts
          | Error msg -> local_err := msg :: !local_err)
        patterns
        (Collapse.collapse_all_patterns ?anchor:anchor_pv ?sectors
           ~tip_rule:(tip_rule_for all_rays) st' es_geom ~over ~stayer ~patterns)
    in
    (if odd then
       let fixed = Collapse.sort_ccw o elems_geom in
       match Flatten.candidates o ~fixed with
       | [] -> local_err := Flatten.e_infeasible :: !local_err
       | cands ->
           List.iter
             (fun (line, ray_dir, _) ->
               (* the end of the emergent ray: the farther of [ray_dir] and
                  the farthest point along it where [line] leaves a face on
                  the table, so that the cut reaches every face of the
                  bundle the ray crosses *)
               let ray_pt =
                 let along (q : Geom.point) =
                   Num.add
                     (Num.mul (Num.sub q.Geom.x o.Geom.x)
                        (Num.sub ray_dir.Geom.x o.Geom.x))
                     (Num.mul (Num.sub q.Geom.y o.Geom.y)
                        (Num.sub ray_dir.Geom.y o.Geom.y))
                 in
                 List.init (Array.length pre) Fun.id
                 |> List.fold_left
                      (fun best i ->
                        match
                          Geom.clip_line_to_convex line
                            (Fold_state.table_polygon_ccw pre_st i)
                        with
                        | None -> best
                        | Some (a, b) ->
                            List.fold_left
                              (fun best q ->
                                if Num.compare (along q) (along best) > 0 then q
                                else best)
                              best [ a; b ])
                      ray_dir
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
               (* the emergent ray runs through every layer that meets at
                  the vertex; the given rays are the pieces their items name *)
               let bundle = Fan_paper.line_faces pre_st ~v:o ~p:pv ~far:ray_pt in
               let st_all =
                 Fold_state.subdivide_fan pre_st ~o
                   ~rays:[ (emergent_cid, line, ray_pt) ]
                   ~only:(fun i -> List.mem i bundle)
                   ~prov
               in
               (* the emergent pieces through the vertex's paper point *)
               let through_pv st' (c, f) =
                 List.exists
                   (fun (sg : Fold_state.crease_segment) ->
                     fst sg.Fold_state.faces >= 0
                     && Geom.on_segment (sg.Fold_state.ta, sg.Fold_state.tb) o
                     && Geom.point_equal (Fan_paper.paper_on sg o) pv
                     && (Geom.point_equal sg.Fold_state.ta f
                        || Geom.point_equal sg.Fold_state.tb f))
                   (Fold_state.crease_segments st' c)
               in
               List.iter
                 (fun (cid, far) ->
                   let emergent_ray = (cid, o, far, Ast.MvFree) in
                   let all_rays = emergent_ray :: combo in
                   try_patterns st_all (Some (cid, line)) (Some (o, far)) all_rays)
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
                    []
                    (List.filter (through_pv st_all) (matches_in st_all))))
             cands
     else
       (* the even fan folds along the pieces its items name *)
       try_patterns pre_st None None combo);
    (!local_real, !local_err, given_fars)
  in
  (* enumerate combinations; each yields realizations + errors. A
     combination is dropped (contributes nothing) when the leading-arc filter
     rejects it. *)
  let multiseg =
    let rec find names cands =
      match (names, cands) with
      | name :: es, cs :: cr ->
          if List.length cs > 1 then name else find es cr
      | _ -> "--?"
    in
    find elem_names elem_cands_at_o
  in
  let combo_runs =
    List.map
      (fun combo ->
        let r, e, _ = run_combo combo staying in
        (combo, r, e))
      combos
  in
  (* `(emergent beside .p)`: the states whose emergent ray lies in a wedge of
     the given rays whose closure holds .p, a condition on the set
     (spec multifold, "emergent beside names the wedge of the emergent ray") *)
  let combo_runs =
    match emergent with
    | None -> combo_runs
    | Some _ when not odd ->
        Error.fail ~hint:"drop the emergent item" span
          (verb ^ " with an even ray count has no emergent ray")
    | Some (p, _) when Geom.point_equal p o ->
        Error.fail ~hint:"name a point off the vertex" span
          "the point of the emergent item lies on the vertex"
    | Some (p, name) ->
        let same a b = Geom.ccw_compare ~center:o a b = 0 in
        let beside (_, _, (rays, eseg), _) =
          match eseg with
          | None -> false
          | Some (_, far) ->
              let fars =
                Array.of_list
                  (List.sort (Geom.ccw_compare ~center:o) (List.map snd rays))
              in
              let k = Array.length fars in
              List.exists
                (fun i ->
                  let lo = fars.(i) and hi = fars.((i + 1) mod k) in
                  Flatten.in_gap o lo hi far
                  && (Flatten.in_gap o lo hi p || same p lo || same p hi))
                (List.init k Fun.id)
        in
        let kept =
          List.map (fun (c, r, e) -> (c, List.filter beside r, e)) combo_runs
        in
        if
          List.exists (fun (_, r, _) -> r <> []) combo_runs
          && List.for_all (fun (_, r, _) -> r = []) kept
        then
          Error.fail ~hint:"name a point in a wedge the emergent ray can split"
            span
            (Printf.sprintf "no state has its emergent ray beside %s" name)
        else kept
  in
  let surviving = List.filter (fun (_, r, _) -> r <> []) combo_runs in
  (* the candidate states (docs/reference/FOLD.md, "The trace"), recorded
     once, when a state lands or the statement fails *)
  let candidates = List.concat_map (fun (_, r, _) -> r) surviving in
  let traced = ref false in
  let trace ?(suggest = fun _ -> None) chosen =
    if not !traced then begin
      traced := true;
      Ctx.record_write ctx (Trace.Flatten { point = o })
        (List.map
           (fun ((st, _, (rays, emergent), _) as r) ->
             { Trace.state = Some st;
               detail =
                 Trace.fan ~pre:!(ctx.state) ~post:st ~point:o ~rays ~emergent
                   ~suggestion:(suggest r);
               removed = None;
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
  (* the winning combination, or the leading one when none survive *)
  let winner_combo =
    match surviving with (c, _, _) :: _ -> c | [] -> List.hd combos
  in
  let realizations =
    match surviving with (_, r, _) :: _ -> r | [] -> []
  in
  let error_pool = List.concat_map (fun (_, _, e) -> e) combo_runs in
  let deciding = realizations in
  (* records the emergent crease's (id, line) here so the name (if
     any) binds to it instead of the given rays; None if no candidate
     ray was materialized (even case) or left unbound. *)
  let emergent_bind = ref None in
  (* `into`'s axis check runs on the emergent line before the winning state
     lands: the emergent line comes from the pre-flatten table geometry, and
     the check must compare it against material in the same frame, so it
     runs before the collapsed state replaces it. With no emergent ray there
     is nothing for `into` to add. *)
  let land_realization ((st, emergent, _, _) as r) =
    trace (Some r);
    (match (into, emergent) with
    | Some (_, check_axis), Some (_, line) -> check_axis line
    | Some _, None ->
        Error.fail ~hint:"drop into" span
          (verb ^ " with an even ray count scores no new crease")
    | None, _ -> ());
    ctx.state := st;
    emergent_bind := emergent
  in
  (try
  match deciding with
  | [] ->
      (* the odd and the even case report differently: the odd case collapses
         every closure failure into one message (364660f's original
         differentiation, preserved verbatim); the even case surfaces
         the pool's own dominant kernel error instead, since there is
         no derived-crease framing to fall back on. *)
      let pool = error_pool in
      (
        match
          (* the tip and stayer diagnoses outrank the generic "derived
             crease does not close": a layer of the tip without the rays,
             an anchor with nothing to move, and a dead [staying] flap each
             name a specific fixable cause. *)
          match List.find_opt Collapse.is_layer_error pool with
          | Some m -> Some m
          | None ->
          List.find_opt
            (fun m ->
              m = Collapse.e_unaligned
              || m = Collapse.e_anchor_stays
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
    when (* the fan fixes its stayer before any selection stage runs
            (spec multifold,
            "Every item of a flatten is a condition on its states"): states
            with different stayers leave the statement ambiguous *)
         let stayer_of (st, _, (rays, emergent), _) =
           match
             Trace.fan ~pre:!(ctx.state) ~post:st ~point:o ~rays ~emergent
               ~suggestion:None
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
        (verb ^ " is ambiguous: its candidates hold different sectors still")
  | many ->
      (* more than one state left: the hint names the items that would
         leave one (spec multifold,
         "Every item of a flatten is a condition on its states"). A verb that
         wrote the rays itself gets no hint. *)
      if verb = "flatten" then
        let names =
          List.map2
            (fun name (_, _, _, dir) ->
              if dir = Ast.MvFree then Some (Flatten.ray_item name) else None)
            elem_names winner_combo
        in
        let above (st, _, _, _) i j =
          let nf = Array.length (Fold_state.faces st) in
          i < nf && j < nf && Fold_state.rel st i j = Fold_state.Above
        in
        let message, hint, items =
          Flatten.suggest ~verb ~items:names ~letters:(fun (_, _, _, l) -> l)
            ~points:(Resolve.named_point_faces ctx) ~above many
        in
        trace ~suggest:(fun r -> Option.join (List.assq_opt r (List.combine many items))) None;
        Error.fail ~hint span message
      else
        Error.fail span
          (Printf.sprintf "%s is ambiguous: %d realizations" verb
             (List.length many))
  with Error.Beloch_error _ as e ->
    trace None;
    raise e);
  !emergent_bind

let run (ctx : Ctx.ctx) ~(into : (int * (Geom.line -> unit)) option)
    ~(bind_out : Ctx.crease_val -> unit)
    ~(elems : Ast.collapse_elem list)
    ~(overs : (Ast.flap_arg * Ast.flap_arg) list)
    ~(staying_opt : Ast.point_operand list option)
    ~(emergent_opt : Ast.point_operand option) (span : Error.span) : unit =
  let elem_cands = resolve_elems ctx ~elems span in
  (* the pieces each item names, on the state the statement folds *)
  let pieces =
    List.map
      (fun (el : Ast.collapse_elem) ->
        match el.Ast.cline with
        | Ast.LNamed cr ->
            Fold_state.crease_segments !(ctx.state) (Resolve.material_cid ctx cr)
        | lo -> snd (Resolve.bundle_segments ctx lo))
      elems
  in
  let o = vertex_of ctx ~elem_cands span in
  let over =
    List.map
      (fun (u, l) -> (Resolve.resolve_sector_face ctx u span, Resolve.resolve_sector_face ctx l span))
      overs
  in
  (* explicit staying (spec multifold,
     "staying names the part that holds every point"): points of the paper,
     whose table images name the one sector that stays; ray order carries no
     stayer meaning then. The sector itself is checked per candidate fan by the
     kernel. *)
  let staying =
    Option.map
      (fun pos ->
        Collapse.Points
          (List.map (fun po -> Fold_state.table_position !(ctx.state) (Resolve.resolve_point ctx po)) pos))
      staying_opt
  in
  let staying_paper =
    Option.map (List.map (Resolve.resolve_point ctx)) staying_opt
  in
  let emergent =
    Option.map
      (fun po -> (Resolve.table_of ctx po, Resolve.fstr (Ast.FlapPoint po)))
      emergent_opt
  in
  let elem_names =
    List.map (fun (el : Ast.collapse_elem) -> Resolve.lstr el.Ast.cline) elems
  in
  let emergent =
    solve ctx ~into ~verb:"flatten" ~elem_cands ~pieces ~o ~elem_names ~over ~anchor:None
      ~staying ?staying_paper ~emergent span
  in
  (* run the output clause's binding step: with no emergent ray materialized
     it takes a selectable bundle of the given rays; with one it takes the
     EMERGENT crease (the newly-completed vertex's own crease, not the rays
     that produced it), so a meet-point selector against the name
     (e.g. `.[--ear --ab]`) finds the emergent crease's tip. *)
  bind_out
    (match emergent with
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
