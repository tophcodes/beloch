open Beloch
let q = Num.of_int
let qf a b = Num.of_q (Q.of_ints a b)
let line a b c = { Geom.a = q a; b = q b; c = q c }

(* one vertical fold splits the square into two faces that share the crease *)
let test_neighbors_after_one_fold () =
  let st = Fold_state.init_square in
  let axis = line 1 0 1 (* x = 1/2 needs rationals; use midline *) in
  ignore axis;
  let st' = Fold_state.fold_with_records st
      ~axis:(let h = Num.of_q (Q.of_ints 1 2) in { Geom.a = Num.one; b = Num.zero; c = h })
      ~move_side:1 ~valley:true ~prov:None in
  Alcotest.(check (list int)) "face 0 borders face 1"
    [1] (List.sort compare (Fold_state.neighbors st' 0))

(* Multi-face disambiguation: fold the unit square on an asymmetric vertical
   axis (x = 3/10) to get two faces with different footprints, then fold a
   second axis (x = -1/5) that only cuts the moved child of the first fold
   (the stationary child, x in [0, 3/10], never crosses x = -1/5). The
   untouched face contributes no *new* cut edge, and the cut face's two
   children must be the ones referenced by the new edge's left/right. Edges
   accumulate across folds (#26), so the first fold's crease carries forward:
   st2 holds two edges — the fresh cut (index 0) and the carried crease. *)
let test_disambiguates_second_fold_touching_one_face () =
  let axis1 = { Geom.a = Num.one; b = Num.zero; c = qf 3 10 } in
  let st1 =
    Fold_state.fold_with_records Fold_state.init_square ~axis:axis1
      ~move_side:1 ~valley:true ~prov:None
  in
  Alcotest.(check int) "st1: two faces" 2 (Array.length st1.Fold_state.faces);
  Alcotest.(check int) "st1: one edge" 1 (Array.length st1.Fold_state.edges);
  let axis2 = { Geom.a = Num.one; b = Num.zero; c = qf (-1) 5 } in
  let st2 =
    Fold_state.fold_with_records st1 ~axis:axis2 ~move_side:(-1) ~valley:true
      ~prov:None
  in
  Alcotest.(check int) "st2: three faces" 3 (Array.length st2.Fold_state.faces);
  (* two edges: the fresh cut (index 0) plus the carried first-fold crease.
     The untouched face adds no *new* cut edge. *)
  Alcotest.(check int)
    "st2: two edges (fresh cut + carried crease, untouched face adds no cut)" 2
    (Array.length st2.Fold_state.edges);
  let e = st2.Fold_state.edges.(0) in
  Alcotest.(check int) "st2: new edge left is the cut face's stationary child" 1
    e.Fold_state.left;
  Alcotest.(check int) "st2: new edge right is the cut face's moved child" 2
    e.Fold_state.right;
  (* the carried first-fold crease now joins the untouched face (0) to the cut
     face's stationary child (1) — it followed its faces through the second
     fold rather than being dropped *)
  let carried = st2.Fold_state.edges.(1) in
  Alcotest.(check int) "st2: carried crease left is the untouched face" 0
    carried.Fold_state.left;
  Alcotest.(check int) "st2: carried crease right is the cut face's stationary child"
    1 carried.Fold_state.right;
  (* the untouched face's geometry is carried over unchanged as face 0 *)
  Alcotest.(check bool) "st2: face 0 (untouched) matches st1's face 0"
    true
    (Array.for_all2 Geom.point_equal st1.Fold_state.faces.(0).Fold_state.paper
       st2.Fold_state.faces.(0).Fold_state.paper)

(* Left/right orientation, valley and mountain: left must be the stationary
   child (keeps the parent's orientation) and right the moved child (gets
   one more reflection, flipping det_sign) — in both directions, and
   regardless of which array index each child ends up at. *)
let test_edge_left_right_orientation () =
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in
  let check_orientation label st =
    Alcotest.(check int) (label ^ ": one edge") 1
      (Array.length st.Fold_state.edges);
    let e = st.Fold_state.edges.(0) in
    Alcotest.(check int) (label ^ ": det_sign(left) unreflected (stationary)")
      1
      (Isometry.det_sign st.Fold_state.faces.(e.Fold_state.left).Fold_state.iso);
    Alcotest.(check int) (label ^ ": det_sign(right) reflected (moved)") (-1)
      (Isometry.det_sign st.Fold_state.faces.(e.Fold_state.right).Fold_state.iso)
  in
  let stv =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
      ~valley:true ~prov:None
  in
  check_orientation "valley" stv;
  Alcotest.(check int) "valley: left=0 (stationary keeps position 0)" 0
    stv.Fold_state.edges.(0).Fold_state.left;
  Alcotest.(check int) "valley: right=1 (moved keeps position 1)" 1
    stv.Fold_state.edges.(0).Fold_state.right;
  let stm =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
      ~valley:false ~prov:None
  in
  check_orientation "mountain" stm;
  (* mountain orders children moved-then-stationary, so the array positions
     flip relative to valley — a left/right swap bug would not show up if we
     only checked one direction *)
  Alcotest.(check int) "mountain: left=1 (stationary now at position 1)" 1
    stm.Fold_state.edges.(0).Fold_state.left;
  Alcotest.(check int) "mountain: right=0 (moved now at position 0)" 0
    stm.Fold_state.edges.(0).Fold_state.right

(* A bare subdivide (no movement) produces a single U edge between its two
   children, left/right being those two children. *)
let test_subdivide_produces_u_edge () =
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in
  let st' = Fold_state.subdivide Fold_state.init_square axis ~prov:None in
  Alcotest.(check int) "subdivide: two faces" 2 (Array.length st'.Fold_state.faces);
  Alcotest.(check int) "subdivide: one edge" 1 (Array.length st'.Fold_state.edges);
  let e = st'.Fold_state.edges.(0) in
  Alcotest.(check bool) "subdivide: eassign = U" true
    (e.Fold_state.eassign = Fold_state.U);
  Alcotest.(check int) "subdivide: left = child 0" 0 e.Fold_state.left;
  Alcotest.(check int) "subdivide: right = child 1" 1 e.Fold_state.right

(* flip reindexes edge left/right through n-1-i. *)
let test_flip_reindexes_edge () =
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in
  let st =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
      ~valley:true ~prov:None
  in
  let n = Array.length st.Fold_state.faces in
  Alcotest.(check int) "pre-flip: two faces" 2 n;
  let e = st.Fold_state.edges.(0) in
  let left0 = e.Fold_state.left and right0 = e.Fold_state.right in
  let st' = Fold_state.flip st in
  Alcotest.(check int) "flip: one edge" 1 (Array.length st'.Fold_state.edges);
  let e' = st'.Fold_state.edges.(0) in
  Alcotest.(check int) "flip: left reindexed via n-1-i" (n - 1 - left0)
    e'.Fold_state.left;
  Alcotest.(check int) "flip: right reindexed via n-1-i" (n - 1 - right0)
    e'.Fold_state.right

(* #27: a precrease (mark) that is later folded on must have its carried U
   edge upgraded to V in place, not left stale or duplicated. *)
let test_precrease_upgrades_in_place () =
  let src = "paper square\nmap .b onto .a\n@map .b onto .a moving .b\n" in
  let fd = Eval.eval_folded (Beloch.parse ~filename:"t.bel" src) in
  let edges = fd.Eval.state.Fold_state.edges in
  let vs = Array.to_list edges
           |> List.filter (fun (e:Fold_state.edge) -> e.Fold_state.eassign = Fold_state.V) in
  Alcotest.(check int) "precrease folded to a single V edge" 1 (List.length vs);
  let us = Array.to_list edges
           |> List.filter (fun (e:Fold_state.edge) -> e.Fold_state.eassign = Fold_state.U) in
  Alcotest.(check int) "no stale U crease left on the fold line" 0 (List.length us)

(* a diagonal precrease is straight; after flip it tracks to the OTHER diagonal *)
let test_crease_axis_flat_and_flip () =
  let pt x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  let l_orig = Geom.line_through (pt 0 0) (pt 1 1) in  (* diagonal a-c *)
  let cid = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide Fold_state.init_square l_orig ~crease_id:cid ~prov:None in
  (match Fold_state.crease_axis st cid l_orig with
   | `Line l ->
       Alcotest.(check bool) "flat crease returns its own line"
         true (Geom.side_of_line l (pt 0 0) = 0 && Geom.side_of_line l (pt 1 1) = 0)
   | _ -> Alcotest.fail "flat crease should resolve to a line");
  let stf = Fold_state.flip st in
  (match Fold_state.crease_axis stf cid l_orig with
   | `Line l ->
       (* the flipped diagonal passes through b(1,0) and d(0,1), not a(0,0)/c(1,1) *)
       Alcotest.(check bool) "flip tracked crease to the other diagonal"
         true (Geom.side_of_line l (pt 1 0) = 0 && Geom.side_of_line l (pt 0 1) = 0)
   | _ -> Alcotest.fail "flipped flat crease should still resolve to a line")

(* flap_of_points: the a-c split square has triangles; {a,b,c} picks exactly one *)
let test_flap_of_points_unique_zero_multi () =
  let pt x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  let cid = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide Fold_state.init_square l ~crease_id:cid ~prov:None in
  (match Fold_state.flap_of_points st [ pt 0 0; pt 1 0; pt 1 1 ] with
   | `Face _ -> ()
   | _ -> Alcotest.fail "{a,b,c} should pick a unique flap");
  (match Fold_state.flap_of_points st [ pt 0 0; pt 1 1 ] with
   | `Ambiguous -> ()  (* both triangles contain the shared diagonal endpoints *)
   | _ -> Alcotest.fail "{a,c} lie on both flaps → ambiguous");
  (match Fold_state.flap_of_points st [ pt 1 0; pt 0 1 ] with
   | `Zero -> ()  (* b and d are on opposite triangles → no single flap *)
   | _ -> Alcotest.fail "{b,d} share no flap → zero")

let test_layer_scaling_subquadratic () =
  (* precrease N well-separated vertical creases via subdivide (grows faces
     linearly, overlaps stay local) and time it for N and 2N.
     This loop's own cost isn't literally sub-quadratic in N: each subdivide
     call reprocesses the full current face array, so the O(n) calls sum to
     ~O(n^2 log n) even with a sparse order build. What the sweep-and-prune
     broad phase (Layer_order.build) removes is the *dense* O(m^2) pairwise
     convex_overlap scan the old build_order did per call (no spatial culling
     at all), which sums to O(n^3) across n calls — an 8x cost for doubling N.
     Measured: new algorithm is ~4.3-4.7x for 200->400 (matches ~O(n^2 log n));
     6x cleanly separates that from the old ~8x, catching a regression to the
     dense per-call scan without chasing float noise. *)
  let build n =
    let st = ref Fold_state.init_square in
    for k = 1 to n do
      let x = Q.make (Z.of_int k) (Z.of_int (n + 1)) in
      let axis = { Geom.a = Num.one; b = Num.zero; c = Num.of_q x } in
      st := Fold_state.subdivide !st axis ~prov:None
    done;
    !st
  in
  let time f = let t0 = Unix.gettimeofday () in ignore (f ()); Unix.gettimeofday () -. t0 in
  let t1 = time (fun () -> build 200) in
  let t2 = time (fun () -> build 400) in
  Alcotest.(check bool)
    (Printf.sprintf "subdivide 400 (%.3fs) < 6x subdivide 200 (%.3fs)" t2 t1)
    true (t2 < 6.0 *. t1 +. 0.05)

(* --- taco-taco / taco-tortilla validity checks (#47) ---------------------- *)

let contains hay needle =
  let hl = String.length hay and nl = String.length needle in
  let rec go i = i + nl <= hl && (String.sub hay i nl = needle || go (i + 1)) in
  nl = 0 || go 0

let pt a b = { Geom.x = q a; y = q b }
let mkface poly = { Fold_state.paper = poly; iso = Isometry.identity }

let mkedge ~ea ~eb ~left ~right ~cid =
  {
    Fold_state.ea;
    eb;
    left;
    right;
    eassign = Fold_state.U;
    crease_id = cid;
    eprov = None;
  }

(* Build a state from identity-placed faces (paper = table), explicit edges, and
   a top→bottom rank per face (higher rank = higher in the stack). *)
let mk_state faces edges ranks =
  let rel_of i j =
    if ranks.(i) > ranks.(j) then Fold_state.Above else Fold_state.Below
  in
  { Fold_state.faces; order = Fold_state.build_order faces rel_of; edges }

let expect_violation label needle st =
  match Fold_state.validity_error st with
  | Some msg ->
      Alcotest.(check bool) (label ^ ": " ^ msg) true (contains msg needle)
  | None -> Alcotest.fail (label ^ ": expected a violation, got None")

let expect_ok label st =
  Alcotest.(check (option string)) label None (Fold_state.validity_error st)

let test_crease_segments_diagonal () =
  let cid = Fold_state.fresh_crease_id () in
  let axis = Geom.line_through (pt 0 0) (pt 1 1) in
  let st = Fold_state.subdivide ~crease_id:cid Fold_state.init_square axis ~prov:None in
  match Fold_state.crease_segments st cid with
  | [ s ] ->
      let a = s.Fold_state.ta and b = s.Fold_state.tb in
      Alcotest.(check bool)
        "segment endpoints are the (0,0)-(1,1) diagonal" true
        ((Geom.point_equal a (pt 0 0) && Geom.point_equal b (pt 1 1))
        || (Geom.point_equal a (pt 1 1) && Geom.point_equal b (pt 0 0)))
  | other -> Alcotest.failf "expected exactly 1 segment, got %d" (List.length other)

(* A taco a|b (both filling the same square, hinged at the bottom edge y=0) with
   a third face c straddling the crease line. When c is stacked between a and b,
   the crease passes through c and c is sandwiched between the two hinged faces —
   physically impossible: taco-tortilla. *)
let taco_tortilla_faces () =
  [|
    mkface [| pt 0 0; pt 4 0; pt 4 4; pt 0 4 |] (* a *);
    mkface [| pt 0 0; pt 4 0; pt 4 4; pt 0 4 |] (* b *);
    mkface [| pt 1 (-2); pt 3 (-2); pt 3 2; pt 1 2 |] (* c straddles y=0 *);
  |]

let taco_tortilla_edges () =
  [| mkedge ~ea:(pt 0 0) ~eb:(pt 4 0) ~left:0 ~right:1 ~cid:100 |]

let test_taco_tortilla_fires () =
  (* a > c > b : c is sandwiched between the taco's two faces *)
  let st = mk_state (taco_tortilla_faces ()) (taco_tortilla_edges ()) [| 2; 0; 1 |] in
  expect_violation "taco-tortilla when c between a and b" "taco-tortilla" st

let test_taco_tortilla_ok_when_not_between () =
  (* a > b > c : c crosses the crease but sits below the whole taco — allowed *)
  let st = mk_state (taco_tortilla_faces ()) (taco_tortilla_edges ()) [| 2; 1; 0 |] in
  expect_ok "no taco-tortilla when c is outside the taco" st

(* Two creases e1 (a|b) and e2 (c|d) that coincide on the table (both the left
   edge x=0 of the same square) but hinge disjoint face pairs. The four faces all
   overlap; whether they cross depends only on the stacking order. *)
let taco_taco_faces () =
  let sq () = [| pt 0 0; pt 2 0; pt 2 2; pt 0 2 |] in
  [| mkface (sq ()); mkface (sq ()); mkface (sq ()); mkface (sq ()) |]

let taco_taco_edges () =
  [|
    mkedge ~ea:(pt 0 0) ~eb:(pt 0 2) ~left:0 ~right:1 ~cid:100;
    mkedge ~ea:(pt 0 0) ~eb:(pt 0 2) ~left:2 ~right:3 ~cid:200;
  |]

let test_taco_taco_fires () =
  (* a > c > b > d : the two hinged pairs interleave (chords cross) *)
  let st = mk_state (taco_taco_faces ()) (taco_taco_edges ()) [| 3; 1; 2; 0 |] in
  expect_violation "taco-taco when the creases interleave" "taco-taco" st

let test_taco_taco_ok_nested () =
  (* a > c > d > b : taco (c|d) nests inside taco (a|b) — allowed *)
  let st = mk_state (taco_taco_faces ()) (taco_taco_edges ()) [| 3; 0; 2; 1 |] in
  expect_ok "no taco-taco when one taco nests in the other" st

let test_taco_taco_ok_separated () =
  (* a > b > c > d : taco (a|b) entirely above taco (c|d) — allowed *)
  let st = mk_state (taco_taco_faces ()) (taco_taco_edges ()) [| 3; 2; 1; 0 |] in
  expect_ok "no taco-taco when one taco is entirely above the other" st

let () =
  Alcotest.run "fold_state"
    [
      ( "adjacency",
        [ Alcotest.test_case "one fold" `Quick test_neighbors_after_one_fold ] );
      ( "edges",
        [
          Alcotest.test_case "disambiguates second fold touching one face"
            `Quick test_disambiguates_second_fold_touching_one_face;
          Alcotest.test_case "left/right orientation (valley & mountain)"
            `Quick test_edge_left_right_orientation;
          Alcotest.test_case "subdivide produces U edge" `Quick
            test_subdivide_produces_u_edge;
          Alcotest.test_case "flip reindexes edge left/right" `Quick
            test_flip_reindexes_edge;
          Alcotest.test_case "precrease upgrades in place (#27)" `Quick
            test_precrease_upgrades_in_place;
        ] );
      ( "material-creases",
        [
          Alcotest.test_case "crease_segments diagonal" `Quick
            test_crease_segments_diagonal;
          Alcotest.test_case "crease_axis flat + flip tracking" `Quick
            test_crease_axis_flat_and_flip;
          Alcotest.test_case "flap_of_points unique/zero/ambiguous" `Quick
            test_flap_of_points_unique_zero_multi;
        ] );
      ( "scaling",
        [
          Alcotest.test_case "layer scaling: sparse order build vs. old dense scan"
            `Slow test_layer_scaling_subquadratic;
        ] );
      ( "taco-checks",
        [
          Alcotest.test_case "taco-tortilla fires when a face is sandwiched"
            `Quick test_taco_tortilla_fires;
          Alcotest.test_case "taco-tortilla silent when face is outside the taco"
            `Quick test_taco_tortilla_ok_when_not_between;
          Alcotest.test_case "taco-taco fires when creases interleave" `Quick
            test_taco_taco_fires;
          Alcotest.test_case "taco-taco silent when tacos nest" `Quick
            test_taco_taco_ok_nested;
          Alcotest.test_case "taco-taco silent when tacos are separated" `Quick
            test_taco_taco_ok_separated;
        ] );
    ]
