(** The `flatten` solver orchestration: single-vertex multi-crease fold, one
    solver pipeline (spec §4.9). *)

open Ctx

let run (ctx : Ctx.ctx) ~(name_opt : string option)
    ~(elems : Ast.collapse_elem list)
    ~(overs : (Ast.flap_arg * Ast.flap_arg) list)
    ~(staying_opt : Ast.flap_arg option)
    ~(toward_opt : Ast.point_operand option) (span : Error.span) : unit =
  (* materialize every collapse crease FIRST (a mark subdivides on
     segment-selection), so all of them cross and the shared collapse
     vertex is fully formed before any ray is selected. Selecting rays
     one-by-one would subdivide the first crease before the others exist,
     leaving it unsplit at the vertex (`no common interior vertex`). *)
  let rec force_material (lo : Ast.line_operand) =
    match lo with
    | Ast.LNamed cr -> ignore (Resolve.material_cid ctx cr)
    | Ast.LFilter (b, _, _) -> force_material b
    | Ast.LUnion (los, _) -> List.iter force_material los
    | Ast.LSelect _ -> ()
  in
  List.iter (fun (el : Ast.collapse_elem) -> force_material el.Ast.cline) elems;
  (* a resolved ray keeps its M/V CONSTRAINT (not yet a concrete valley
     — that's the solver's job now, spec 2026-07-16-flatten-derive-v2-
     design.md "the model"), as a 4-tuple rather than [Collapse.elem] so
     its fields can't be confused with that type's same-named
     cid/ea/eb once both are in scope below. *)
  let fail_not_material (el : Ast.collapse_elem) () =
    Error.fail span
      (Printf.sprintf
         "collapse folds along existing creases; %s is not a material \
          crease" (Resolve.lstr el.Ast.cline))
  in
  (* each element resolves to 1..k material SEGMENTS at the vertex — no
     eager multi-segment error any more (spec 2026-07-17 §Segment
     inference): the stayer filter and the vertex check prune the wrong
     segment combinations. Only genuinely-non-material operands error,
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
            (* segments from a cross-crease union: no single cid to fold
               along *)
            fail_not_material el ())
    | _ -> fail_not_material el ()
  in
  let elem_cands = List.map resolve_elem_candidates elems in
  let elem_of (fcid, fea, feb, valley) =
    { Collapse.cid = fcid; ea = fea; eb = feb; valley }
  in
  (* vertex O: the strictly-interior point shared by >= 1 candidate
     segment of EVERY element (generalizes [Collapse.common_vertex] to the
     per-element candidate lists). *)
  let strictly_interior_pt (p : Geom.point) =
    Num.sign p.Geom.x > 0
    && Num.compare p.Geom.x Num.one < 0
    && Num.sign p.Geom.y > 0
    && Num.compare p.Geom.y Num.one < 0
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
        (fun p -> strictly_interior_pt p && shared_by_all p)
        endpoints
    with
    | Some o -> o
    | None -> Error.fail span Collapse.e_no_vertex
  in
  (* keep only the candidate segments that actually end at O; every
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
  (* explicit staying: X's material is the stayer, order carries no
     meaning. The flap must touch the vertex fan, else it names no stayer
     sector at all (distinct from "no realization keeps it still"). *)
  let staying_stayer =
    match staying_opt with
    | None -> None
    | Some fa ->
        let faces = Resolve.resolve_flap_cluster ctx fa span in
        let touches =
          List.exists
            (fun f ->
              Array.exists (Geom.point_equal o)
                (Fold_state.table_polygon_ccw !(ctx.state) f))
            faces
        in
        if not touches then
          Error.fail span "the staying flap does not touch the vertex"
        else Some (Collapse.Faces faces)
  in
  let n_given = List.length elems in
  let odd = n_given mod 2 = 1 in
  let prov : State.provenance option =
    Some
      { State.axiom = "flatten"; sources = []; span; name = None }
  in
  (* pre-mint the emergent crease id ONCE (odd case only — the even
     case never materializes anything), so every candidate's probe
     subdivision (below) and the eventual winner share one id instead
     of drifting the global counter per candidate. *)
  let new_cid = lazy (Fold_state.fresh_crease_id ()) in
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
     sits strictly inside the arc" (dead — stayed material cannot carry a
     folding crease, spec §Semantics). The latter kill is ours, done here
     over the GIVEN rays before the kernel runs. Gated on a genuine
     segment choice (>1 combination): with a single combination the input
     has no alternative and the pre-2026-07-17 convention behaviour stands.
     Absent under [staying] — the convention carries no meaning then. *)
  let leading_arc_ok combo =
    match (staying_opt, combo) with
    | Some _, _ -> true
    | None, e1 :: e2 :: rest ->
        let f1 = far_of_combo_elem e1 and f2 = far_of_combo_elem e2 in
        let oc = (o.Geom.x, o.Geom.y) in
        let c =
          Collapse.cross oc (f1.Geom.x, f1.Geom.y) (f2.Geom.x, f2.Geom.y)
        in
        if Num.sign c = 0 then true (* collinear -> kernel: e_stayer_collinear *)
        else
          let a, b = if Num.sign c > 0 then (f1, f2) else (f2, f1) in
          not
            (List.exists
               (fun e -> Collapse.in_ccw_arc o a b (far_of_combo_elem e))
               rest)
    | None, _ -> true
  in
  (* the all-layers congruence guard (spec §Semantics: "Material /
     layers"), now judged per combination so a wrong-segment combination
     is dropped rather than aborting the whole statement. For each chosen
     element segment's table-space line, any face it actually cuts (not
     just grazes) must already carry THAT element's crease on that line —
     else the bundle is bent/missing on some layer and folding it as one
     unit is unsound. Returns the guard error, or None if the combination
     passes. *)
  let all_layers_error combo =
    let st = !(ctx.state) in
    List.find_map
      (fun (fcid, fea, feb, _) ->
        let line = Geom.line_through fea feb in
        let aligned_faces =
          Fold_state.crease_segments st fcid
          |> List.concat_map (fun (s : Fold_state.crease_segment) ->
                 if
                   Geom.side_of_line line s.Fold_state.ta = 0
                   && Geom.side_of_line line s.Fold_state.tb = 0
                 then
                   let l, r = s.Fold_state.faces in
                   l :: (if r >= 0 then [ r ] else [])
                 else [])
        in
        let bad = ref false in
        Array.iteri
          (fun i _ ->
            if
              Geom.segment_cuts_polygon (fea, feb)
                (Fold_state.table_polygon_ccw st i)
              && not (List.mem i aligned_faces)
            then bad := true)
          (Fold_state.faces st);
        if !bad then Some "collapse through unaligned layers" else None)
      combo
  in
  (* run one combination: pool every (state, tier, emergent-binding) that
     a candidate x M/V-pattern attempt closed, and every failure message.
     [given_fars] is this combination's given rays' far tips (the emergent
     scan excludes them). *)
  let run_combo combo (stayer : Collapse.stayer) =
    let local_real :
        (Fold_state.t * [ `Tier1 | `Tier2 ] * (int * Geom.line) option)
        list ref =
      ref []
    in
    let local_err = ref [] in
    let elems_geom =
      List.map (fun (a, b, c, _) -> elem_of (a, b, c, true)) combo
    in
    let given_fars = List.map (Collapse.far_of o) elems_geom in
    let try_patterns (st' : Fold_state.t) (tier : [ `Tier1 | `Tier2 ])
        (emergent : (int * Geom.line) option)
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
                (fun s -> local_real := (s, tier, emergent) :: !local_real)
                sts
          | Error msg -> local_err := msg :: !local_err)
        (Collapse.collapse_all_patterns st' es_geom ~over ~stayer ~patterns)
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
               (* materialize ONLY this candidate ray on a local copy of
                  the pre-flatten state, then scan every crease ray now
                  sitting at O on the kept side (the perpendicular guard
                  confines the cut to [ray_pt]'s side). Collinear-reuse
                  (the rabbit-ear up-spine) is found among EXISTING
                  segments, not [new_cid]. *)
               let guard = Geom.perpendicular_through line o in
               let keep = Geom.side_of_line guard ray_pt in
               let st' =
                 Fold_state.subdivide !(ctx.state) line
                   ~crease_id:(Lazy.force new_cid)
                   ~keep_side:(guard, keep) ~prov
               in
               let far_of_seg (s : Fold_state.crease_segment) =
                 if Geom.point_equal s.Fold_state.ta o then s.Fold_state.tb
                 else s.Fold_state.ta
               in
               let matches =
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
               List.iter
                 (fun (cid, far) ->
                   let emergent_ray = (cid, o, far, Ast.MvFree) in
                   try_patterns st' tier (Some (cid, line))
                     (emergent_ray :: combo))
                 matches)
             cands
     else try_patterns !(ctx.state) `Tier1 None combo);
    (!local_real, !local_err, given_fars)
  in
  (* enumerate combinations; each yields realizations + errors. A
     combination is dropped (contributes only errors) when the leading-arc
     filter or the all-layers guard rejects it. *)
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
          match all_layers_error combo with
          | Some e -> (combo, [], [ e ])
          | None ->
              let r, e, _ = run_combo combo stayer in
              (combo, r, e))
      combos
  in
  let surviving = List.filter (fun (_, r, _) -> r <> []) combo_runs in
  (* a genuine segment contradiction: two combinations both close with
     non-empty pools -> the user must disambiguate with `&`. *)
  (match surviving with
  | _ :: _ :: _ ->
      Error.fail span
        (Printf.sprintf
           "%s is ambiguous at the vertex; select a segment with `&`"
           multiseg)
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
  let tier1, tier2 = List.partition (fun (_, t, _) -> t = `Tier1) realizations in
  let deciding = if tier1 <> [] then tier1 else tier2 in
  (* records the emergent crease's (id, line) here so the name (if
     any) binds to it instead of the given rays; None if no candidate
     ray was materialized (even case) or left unbound. *)
  let emergent_bind = ref None in
  (match deciding with
  | [] ->
      (* spec step 6: out-of-paper trumps everything; otherwise the
         odd/even cases report differently — the odd case collapses
         every closure failure into one message (364660f's original
         differentiation, preserved verbatim); the even case surfaces
         the pool's own dominant kernel error instead, since there is
         no derived-crease framing to fall back on. *)
      let pool = error_pool in
      if List.mem Collapse.e_out_of_paper pool then
        Error.fail span Collapse.e_out_of_paper
      else (
        match
          (* eval-level and stayer diagnoses outrank the generic
             "derived crease does not close": the all-layers guard
             (a dropped combination), a collinear leading pair, and a
             dead [staying] flap each name a specific fixable cause. *)
          List.find_opt
            (fun m ->
              m = "collapse through unaligned layers"
              || m = Collapse.e_stayer_collinear
              || m = Collapse.e_stayer_dead)
            pool
        with
      | Some m -> Error.fail span m
      | None ->
      if odd then
        Error.fail span "the derived crease does not close the vertex"
      else begin
        match List.find_opt (fun m -> m <> Collapse.e_selfint) pool with
        | Some m -> Error.fail span m
        | None ->
            (* pool = [] only when every candidate's pin set was itself
               Maekawa-unsatisfiable (no pattern to even try); a pool of
               all-e_selfint falls back to e_selfint itself. *)
            Error.fail span
              (if pool = [] then Collapse.e_maekawa else Collapse.e_selfint)
      end)
  | [ (st, _, emergent) ] ->
      ctx.state := st;
      emergent_bind := emergent
  | many ->
      (* |deciding| > 1 — three-stage selection (amended spec 38bd69e +
         .superpowers/sdd/toward-stacking-rule.md, 2026-07-16):
         1. POSITION stage: placements depend only on ray LINES, so
            realizations group into position classes by moved-material
            centroid; {toward} picks the class by centroid dot.
         2. MIN-MOUNTAIN CANON: within the class, keep only the
            realizations with the fewest derived mountains among the
            USER-GIVEN creases (a freshly-materialized emergent cid is
            not a given cid, so it is excluded automatically; a
            collinear-reuse emergent — the fish diagonal — IS a given
            cid and counts, per the rule doc's fish derivation).
         3. RANK-DIPOLE stage: if several remain, maximize
            S(R) = Σ_faces area · (rank − (nf−1)/2) ·
            ((table_centroid − O)·(toward − O)) — "the material lying
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
      (* stage-2 canon: derived (never stored) M/V per hinge —
         [Fold_state.mv] reads rank + orientation, so two stackings of
         one pattern can differ. A given cid is a mountain iff some
         FOLDED hinge of that cid derives M. *)
      let given_cids =
        List.sort_uniq compare (List.map (fun (c, _, _, _) -> c) rays)
      in
      let given_mountains (st, _, _) : int =
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
        List.filter_map (fun (c, r) -> if c = m then Some r else None) counted
      in
      let commit (st, _, emergent) =
        ctx.state := st;
        emergent_bind := emergent
      in
      (match toward_opt with
      | None -> (
          (* no class to pick without {toward}; the min-mountain canon
             is toward-independent, so it may still single out THE
             least-forced realization — only a post-canon surplus is a
             genuine ambiguity (spec: "no {toward} while |S| > 1 after
             stage 2"). *)
          match min_mountain_filter many with
          | [ r ] -> commit r
          | kept ->
              Error.fail span
                (Printf.sprintf
                   "flatten is ambiguous: %d realizations; add {toward \
                    .p} to pick the fold direction"
                   (List.length kept)))
      | Some toward_po ->
          let toward_pt = Resolve.resolve_point ctx toward_po in
          let st_pre = !(ctx.state) in
          (* stage 1 — moved-material centroid per realization; a pure
             function of table placement, shared within a class. *)
          let centroid_of (st_post, _, _) : Geom.point =
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
                (* two DISTINCT position classes tie — toward is
                   collinear with a crease through O (the classes are
                   mirror-symmetric about it) *)
                Error.fail span Flatten.e_toward_ambiguous
            | (_, c) :: _ -> c
            | [] -> assert false (* [many] is non-empty here *)
          in
          let winners =
            List.filter_map
              (fun (c, r) ->
                if Geom.point_equal c winning_centroid then Some r else None)
              by_centroid
          in
          (* stage 2 *)
          (match min_mountain_filter winners with
          | [] -> assert false (* filter of a non-empty list *)
          | [ r ] -> commit r
          | kept ->
              (* stage 3 — but first the symmetry-axis guard (rule doc
                 §Ties): the dipole's null direction is NOT the
                 geometric mirror axis, so an on-axis toward would get
                 a strict-but-arbitrary argmax; if the given-ray
                 direction set is invariant under reflection across the
                 O–toward line, the sides are genuinely
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
                Error.fail span Flatten.e_toward_ambiguous
              else
                let dipole (st, _, _) : Num.t =
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
                    Error.fail span Flatten.e_toward_ambiguous
                | (_, r) :: _ -> commit r
                | [] -> assert false (* [kept] has >= 2 elements *)))));
  (* bind the name (if any): with no emergent ray materialized, bind a
     selectable bundle of the given rays; with one, bind the EMERGENT
     crease instead (the newly-completed vertex's own crease, not the
     rays that produced it), so a meet-point selector against the name
     (e.g. `.[--ear --ab]`) finds the emergent crease's tip. *)
  (match name_opt with
  | Some n ->
      let cv =
        match !emergent_bind with
        | Some (cid, line) -> Material (cid, line)
        | None ->
            Bundle
              (Ast.LUnion
                 (List.map (fun (el : Ast.collapse_elem) -> el.Ast.cline) elems, span))
      in
      bind_crease ctx n span cv
  | None -> ());
  push_frame ctx (Some span)
