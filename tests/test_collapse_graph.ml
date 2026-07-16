open Beloch

(* Old-vs-new parity for [Collapse.collapse_graph] against [Collapse.collapse]
   (Plan 3b Task 5). Geometry is transcribed verbatim from
   tests/test_collapse.ml's fixtures — no new lines/points are invented; only
   valley-assignment bit patterns are chosen (data, not geometry) to reach the
   Maekawa/ambiguous branches. *)

let q = Num.of_int
let half = Num.div Num.one (q 2)
let pt x y = { Geom.x; Geom.y }
let o = pt half half

(* the four full lines through the centre, each paired with its two ray
   far-tips (from tests/test_collapse.ml's [line_specs]) *)
let line_specs =
  [
    ( Geom.line_through (pt (q 0) (q 0)) (pt (q 1) (q 1)),
      [ pt (q 1) (q 1); pt (q 0) (q 0) ] );
    ( Geom.line_through (pt (q 1) (q 0)) (pt (q 0) (q 1)),
      [ pt (q 0) (q 1); pt (q 1) (q 0) ] );
    ( Geom.line_through (pt (q 0) half) (pt (q 1) half),
      [ pt (q 1) half; pt (q 0) half ] );
    ( Geom.line_through (pt half (q 0)) (pt half (q 1)),
      [ pt half (q 1); pt half (q 0) ] );
  ]

(* precreased 8-ray symmetric-cross pre-state, built in BOTH models with
   lockstep crease ids (both counters reset first, minted in the same order,
   so the ids coincide by construction). *)
let precreased_both () =
  Fold_graph.reset_ids ();
  Fold_state.reset_ids ();
  List.fold_left
    (fun (g, st, rays) (l, fars) ->
      let cid_g = Fold_graph.fresh_crease_id () in
      let cid_s = Fold_state.fresh_crease_id () in
      assert (cid_g = cid_s);
      let g' = Fold_graph.subdivide ~crease_id:cid_g g l ~prov:None in
      let st' = Fold_state.subdivide ~crease_id:cid_s st l ~prov:None in
      (g', st', rays @ List.map (fun f -> (f, cid_g)) fars))
    (Fold_graph.init_square, Fold_state.init_square, [])
    line_specs

let elems_of st_rays valleys =
  List.mapi
    (fun i (far, cid) ->
      { Collapse.cid; ea = o; eb = far; valley = valleys.(i) })
    st_rays

(* degree-4 "+" vertex (tests/test_collapse.ml's [precreased_plus]): horizontal
   + vertical lines through the centre, four 90-degree sectors. *)
let precreased_plus_both () =
  Fold_graph.reset_ids ();
  Fold_state.reset_ids ();
  let hline = Geom.line_through (pt (q 0) half) (pt (q 1) half) in
  let vline = Geom.line_through (pt half (q 0)) (pt half (q 1)) in
  let cidh_g = Fold_graph.fresh_crease_id () in
  let cidh_s = Fold_state.fresh_crease_id () in
  assert (cidh_g = cidh_s);
  let g = Fold_graph.subdivide ~crease_id:cidh_g Fold_graph.init_square hline ~prov:None in
  let st = Fold_state.subdivide ~crease_id:cidh_s Fold_state.init_square hline ~prov:None in
  let cidv_g = Fold_graph.fresh_crease_id () in
  let cidv_s = Fold_state.fresh_crease_id () in
  assert (cidv_g = cidv_s);
  let g = Fold_graph.subdivide ~crease_id:cidv_g g vline ~prov:None in
  let st = Fold_state.subdivide ~crease_id:cidv_s st vline ~prov:None in
  (* rays CCW-ish order: right(h), up(v), left(h), down(v) *)
  let rays =
    [
      (pt (q 1) half, cidh_g);
      (pt half (q 1), cidv_g);
      (pt (q 0) half, cidh_g);
      (pt half (q 0), cidv_g);
    ]
  in
  (g, st, rays)

(* --- parity harness: copied verbatim from tests/test_fold_graph.ml (noted
   duplication; Plan 3c is expected to factor this into a shared test lib) --- *)

let check_parity label (g : Fold_graph.t) (st : Fold_state.t) =
  let nf = Array.length (Fold_graph.faces g) in
  Alcotest.(check int) (label ^ ": face count") (Array.length st.Fold_state.faces) nf;
  for i = 0 to nf - 1 do
    let fp = (Fold_graph.faces g).(i) in
    let op = st.Fold_state.faces.(i).Fold_state.paper in
    Alcotest.(check int) (label ^ ": paper verts") (Array.length op) (Array.length fp);
    Array.iteri
      (fun k p ->
        Alcotest.(check bool)
          (Printf.sprintf "%s: face %d paper %d" label i k) true
          (Geom.point_equal p op.(k)))
      fp;
    let tp = Fold_graph.table_polygon g i in
    let ot = Fold_state.table_polygon st i in
    Array.iteri
      (fun k p ->
        Alcotest.(check bool)
          (Printf.sprintf "%s: face %d table %d" label i k) true
          (Geom.point_equal p ot.(k)))
      tp
  done;
  for i = 0 to nf - 1 do
    for j = 0 to nf - 1 do
      let nr = Fold_graph.rel g i j in
      let orl = Layer_order.get st.Fold_state.order i j in
      let same =
        match (nr, orl) with
        | Fold_graph.Above, Fold_state.Above
        | Fold_graph.Below, Fold_state.Below
        | Fold_graph.Apart, Fold_state.Apart -> true
        | _ -> false
      in
      Alcotest.(check bool) (Printf.sprintf "%s: rel %d %d" label i j) true same
    done
  done

(* Collapse variant of test_fold_graph.ml's [check_assign_parity]. The derived
   [Fold_graph.mv] is deliberately NOT compared against the old kernel's stored
   [eassign] — the two genuinely diverge, and the divergence was adjudicated in
   favour of the new model (Plan 3b Task 5 finding):

   The old collapse kernel stores `eassign = effective_valley user_valley
   tsec.(l) sector_iso.(l)` — the user letter XORed with the POST-collapse
   left-sector parity, including the sector fan's own alternating `tsec` term.
   That stored letter contradicts the old codebase's own [intrinsic_valley]
   probe (test_collapse.ml) evaluated on the very same old result, and
   contradicts old [fold_with_records]' convention (pre-fold parity) — two old
   subsystems disagree with each other. The rewrite's [Fold_graph.mv] is
   derived from rank + placement (validated against hullzakharevich2023 in
   Plan 2c and against old fold eassign in every Plan 3a parity test) and
   cannot contradict the geometry — it is authoritative; this is exactly the
   bug class the rewrite exists to eliminate. The parity-adjusted CP-frame
   letters (old eintent) ARE preserved bit-for-bit — [collapse_graph] stores
   them as hinge [intent]. [test_old_eassign_divergence] below pins the
   divergence executably.

   Checked here: (a) hinge/edge bijection on paper segments, (b) hinge
   [intent] EQUAL to old [eintent], (c) internal consistency of the derived
   letters at the collapse vertex — Maekawa, |#M - #V| = 2 over the folded
   (ray) hinges, via [Fold_graph.mv]. *)
let check_collapse_assign_parity label (g : Fold_graph.t) (st : Fold_state.t) =
  let hs = Fold_graph.hinges g in
  let es = st.Fold_state.edges in
  Alcotest.(check int)
    (Printf.sprintf "%s: hinge/edge count" label)
    (Array.length es) (Array.length hs);
  let of_old = function
    | Fold_state.M -> Fold_graph.M
    | Fold_state.V -> Fold_graph.V
    | Fold_state.F -> Fold_graph.F
  in
  (* (a) + (b): segment bijection with matching intent (old eintent) *)
  let used = Array.make (Array.length es) false in
  Array.iteri
    (fun i (h : Fold_graph.hinge) ->
      let a, b = Fold_graph.hinge_segment g i in
      let matches j =
        (not used.(j))
        &&
        let e = es.(j) in
        ((Geom.point_equal e.Fold_state.ea a && Geom.point_equal e.Fold_state.eb b)
        || (Geom.point_equal e.Fold_state.ea b && Geom.point_equal e.Fold_state.eb a))
        && h.Fold_graph.intent = of_old e.Fold_state.eintent
      in
      let rec find j =
        if j >= Array.length es then None
        else if matches j then Some j
        else find (j + 1)
      in
      match find 0 with
      | Some j -> used.(j) <- true
      | None ->
          let pt p =
            Printf.sprintf "(%g,%g)" (Num.to_float p.Geom.x) (Num.to_float p.Geom.y)
          in
          Alcotest.failf
            "%s: hinge %d %s--%s has no unused old edge with matching \
             segment+intent"
            label i (pt a) (pt b))
    hs;
  (* (c) Maekawa over the folded (ray) hinges' DERIVED letters *)
  let m, v =
    Array.to_list hs
    |> List.mapi (fun i h -> (i, h))
    |> List.filter (fun (_, (h : Fold_graph.hinge)) ->
           Num.sign h.Fold_graph.angle <> 0)
    |> List.fold_left
         (fun (m, v) (i, _) ->
           match Fold_graph.mv g i with
           | Fold_graph.M -> (m + 1, v)
           | Fold_graph.V -> (m, v + 1)
           | Fold_graph.F -> (m, v))
         (0, 0)
  in
  Alcotest.(check int)
    (Printf.sprintf "%s: derived letters satisfy Maekawa (|M-V|=2)" label)
    2
    (abs (m - v))

(* --- Step 1 tests --------------------------------------------------------- *)

(* Ok-case parity: the degree-4 "+" vertex, valley pattern [M;V;M;M]
   (tests/test_collapse.ml's [test_eassign_parity] fixture — guaranteed Ok,
   unique layer order). *)
let test_rabbit_ear_collapse_parity () =
  let g, st, rays = precreased_plus_both () in
  let es = elems_of rays [| false; true; false; false |] in
  match (Collapse.collapse_graph g es ~over:[], Collapse.collapse st es ~over:[]) with
  | Ok ng, Ok nst ->
      check_parity "rabbit ear collapse" ng nst;
      check_collapse_assign_parity "rabbit ear collapse" ng nst
  | Error e, _ -> Alcotest.fail ("new kernel: expected Ok, got: " ^ e)
  | _, Error e -> Alcotest.fail ("old kernel: expected Ok, got: " ^ e)

let test_collapse_errors_parity () =
  (* n=2 (odd count, 7 of 8 rays) -> e_count, mirrors
     [test_odd_count_rejected] *)
  let g8, st8, rays8 = precreased_both () in
  let es_all = elems_of rays8 (Array.make 8 true) in
  let seven = List.filteri (fun i _ -> i < 7) es_all in
  (match
     (Collapse.collapse_graph g8 seven ~over:[], Collapse.collapse st8 seven ~over:[])
   with
  | Error eg, Error es -> Alcotest.(check string) "count error parity" es eg
  | _ -> Alcotest.fail "expected both kernels to reject odd count");

  (* no common vertex, mirrors [test_no_common_vertex_rejected]: the early
     guard never touches the graph, so any pre-built [g] is a valid stand-in *)
  let es_disjoint =
    [
      { Collapse.cid = 0; ea = pt (q 0) (q 0); eb = pt (q 1) (q 0); valley = true };
      { Collapse.cid = 1; ea = pt (q 1) (q 1); eb = pt (q 0) (q 1); valley = true };
      { Collapse.cid = 2; ea = pt (q 0) (q 1); eb = pt (q 1) (q 1); valley = false };
      { Collapse.cid = 3; ea = pt (q 1) (q 0); eb = pt (q 0) (q 0); valley = false };
    ]
  in
  (match
     ( Collapse.collapse_graph Fold_graph.init_square es_disjoint ~over:[],
       Collapse.collapse Fold_state.init_square es_disjoint ~over:[] )
   with
  | Error eg, Error es -> Alcotest.(check string) "no-vertex error parity" es eg
  | _ -> Alcotest.fail "expected both kernels to reject with no common vertex");

  (* Maekawa violated: all-valley on the 8-ray cross, mirrors
     [test_maekawa_rejected] *)
  match
    (Collapse.collapse_graph g8 es_all ~over:[], Collapse.collapse st8 es_all ~over:[])
  with
  | Error eg, Error es -> Alcotest.(check string) "maekawa error parity" es eg
  | _ -> Alcotest.fail "expected both kernels to reject Maekawa violation"

(* the 8-ray cross, valley pattern [V;V;M;M;V;M;M;M]: |nm-nv| = |5-3| = 2
   (Maekawa holds) but the stacking is ambiguous (4 distinct orders) without
   `over`; over=[(3,4)] (face 3 above face 4) resolves it to a unique Ok. Both
   facts verified empirically against the certified old kernel — same
   [precreased] geometry, only the valley bit pattern and the resolving `over`
   pair are new data, not new geometry. *)
let test_collapse_over_parity () =
  let g8, st8, rays8 = precreased_both () in
  let valleys = [| true; true; false; false; true; false; false; false |] in
  let es = elems_of rays8 valleys in
  (match
     (Collapse.collapse_graph g8 es ~over:[], Collapse.collapse st8 es ~over:[])
   with
  | Error eg, Error es -> Alcotest.(check string) "ambiguous parity (no over)" es eg
  | _ -> Alcotest.fail "expected both kernels to report ambiguous stacking without `over`");
  match
    ( Collapse.collapse_graph g8 es ~over:[ (3, 4) ],
      Collapse.collapse st8 es ~over:[ (3, 4) ] )
  with
  | Ok ng, Ok nst ->
      check_parity "over resolves ambiguity" ng nst;
      check_collapse_assign_parity "over resolves ambiguity" ng nst
  | Error e, _ -> Alcotest.fail ("new kernel: expected Ok with over, got: " ^ e)
  | _, Error e -> Alcotest.fail ("old kernel: expected Ok with over, got: " ^ e)

(* --- executable record of the adjudicated divergence ---------------------- *)

(* Intrinsic (geometry-only) M/V of a crease — copied with attribution from
   tests/test_collapse.ml (its [intrinsic_valley], pinned there against the
   emitter on a trivial simple fold): the crease is a valley iff the UPPER of
   its two incident faces is front-down (det < 0), no reference to the stored
   letter. *)
let old_intrinsic_valley (s : Fold_state.t) (fl : int) (fj : int) : bool =
  let upper =
    if Layer_order.get s.Fold_state.order fj fl = Layer_order.Above then fj
    else fl
  in
  Isometry.det_sign s.Fold_state.faces.(upper).Fold_state.iso < 0

(* Pins the Task 5 finding itself (adjudicated in favour of the new model):
   on the rabbit-ear fixture,
   (1) the new kernel's DERIVED letters equal the raw user-declared
       valley/mountain on every ray hinge (no prior flip, so no parity
       adjustment applies physically), while
   (2) the old kernel's STORED eassign contradicts the old codebase's own
       [intrinsic_valley] probe on at least one ray edge of the very same old
       result — i.e. the old stored letter is geometrically inconsistent with
       the old layer order + face orientation it ships with.
   If (2) ever starts failing, the old kernel changed underneath us and the
   check_collapse_assign_parity carve-out should be revisited. *)
let test_old_eassign_divergence () =
  let g, st, rays = precreased_plus_both () in
  let valleys = [| false; true; false; false |] in
  let es = elems_of rays valleys in
  match (Collapse.collapse_graph g es ~over:[], Collapse.collapse st es ~over:[]) with
  | Error e, _ -> Alcotest.fail ("new kernel: expected Ok, got: " ^ e)
  | _, Error e -> Alcotest.fail ("old kernel: expected Ok, got: " ^ e)
  | Ok ng, Ok nst ->
      (* (1) new derived mv == raw user valley, on every ray hinge. The "+"
         pre-state is flat (identity placements), so each hinge's PAPER
         segment lies on its ray. *)
      let hs = Fold_graph.hinges ng in
      let ray_of i =
        let a, b = Fold_graph.hinge_segment ng i in
        let found = ref None in
        List.iteri
          (fun j (far, cid) ->
            if
              (hs.(i)).Fold_graph.crease_id = cid
              && Geom.on_segment (o, far) a
              && Geom.on_segment (o, far) b
            then found := Some j)
          rays;
        !found
      in
      let checked = ref 0 in
      Array.iteri
        (fun i (h : Fold_graph.hinge) ->
          if Num.sign h.Fold_graph.angle <> 0 then
            match ray_of i with
            | None -> Alcotest.failf "folded hinge %d matches no ray" i
            | Some j ->
                incr checked;
                let expect =
                  if valleys.(j) then Fold_graph.V else Fold_graph.M
                in
                Alcotest.(check bool)
                  (Printf.sprintf
                     "new derived mv equals raw declared letter (ray %d)" j)
                  true
                  (Fold_graph.mv ng i = expect))
        hs;
      Alcotest.(check int) "all four ray hinges checked" 4 !checked;
      (* (2) old stored eassign contradicts old intrinsic on >= 1 ray edge *)
      let divergent =
        Array.exists
          (fun (e : Fold_state.edge) ->
            e.Fold_state.left >= 0
            && e.Fold_state.eassign <> Fold_state.F
            && old_intrinsic_valley nst e.Fold_state.left e.Fold_state.right
               <> (e.Fold_state.eassign = Fold_state.V))
          nst.Fold_state.edges
      in
      Alcotest.(check bool)
        "old stored eassign contradicts old intrinsic_valley somewhere" true
        divergent

let () =
  Alcotest.run "collapse_graph parity"
    [
      ( "parity",
        [
          Alcotest.test_case "rabbit-ear collapse Ok-parity" `Quick
            test_rabbit_ear_collapse_parity;
          Alcotest.test_case "collapse error-string parity" `Quick
            test_collapse_errors_parity;
          Alcotest.test_case "over resolves ambiguity parity" `Quick
            test_collapse_over_parity;
        ] );
      ( "divergence",
        [
          Alcotest.test_case "old eassign vs derived mv (adjudicated)" `Quick
            test_old_eassign_divergence;
        ] );
    ]
