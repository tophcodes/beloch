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

(* A bare subdivide (no movement) produces a single F edge between its two
   children, left/right being those two children. *)
let test_subdivide_produces_u_edge () =
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in
  let st' = Fold_state.subdivide Fold_state.init_square axis ~prov:None in
  Alcotest.(check int) "subdivide: two faces" 2 (Array.length st'.Fold_state.faces);
  Alcotest.(check int) "subdivide: one edge" 1 (Array.length st'.Fold_state.edges);
  let e = st'.Fold_state.edges.(0) in
  Alcotest.(check bool) "subdivide: eassign = F" true
    (e.Fold_state.eassign = Fold_state.F);
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

(* #27: a precrease (mark) that is later folded on must have its carried F
   edge upgraded to V in place, not left stale or duplicated. *)
let test_precrease_upgrades_in_place () =
  let src = "paper square\nmark map .b onto .a\nfold map .b onto .a moving .b\n" in
  let fd = Eval.eval_folded (Beloch.parse ~filename:"t.bel" src) in
  let edges = fd.Eval.state.Fold_state.edges in
  let vs = Array.to_list edges
           |> List.filter (fun (e:Fold_state.edge) -> e.Fold_state.eassign = Fold_state.V) in
  Alcotest.(check int) "precrease folded to a single V edge" 1 (List.length vs);
  let us = Array.to_list edges
           |> List.filter (fun (e:Fold_state.edge) -> e.Fold_state.eassign = Fold_state.F) in
  Alcotest.(check int) "no stale F crease left on the fold line" 0 (List.length us)

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

(* flap_of_points: the a-c split square has two triangle FACES, but the split
   is a bare F precrease (nothing folded), so both triangles are the SAME
   coplanar cluster (ADR 0017). Every point-set below now resolves to that one
   `Cluster, including {b,d} and {a,c} which used to be `Zero/`Ambiguous under
   the old per-face semantics — "still flat ⇒ still one flap". *)
let test_flap_of_points_unique_zero_multi () =
  let pt x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  let cid = Fold_state.fresh_crease_id () in
  let st = Fold_state.subdivide Fold_state.init_square l ~crease_id:cid ~prov:None in
  (match Fold_state.flap_of_points st [ pt 0 0; pt 1 0; pt 1 1 ] with
   | `Cluster _ -> ()
   | _ -> Alcotest.fail "{a,b,c}: unfolded precrease is one cluster");
  (match Fold_state.flap_of_points st [ pt 0 0; pt 1 1 ] with
   | `Cluster _ -> ()  (* both triangles are the same still-flat cluster *)
   | _ -> Alcotest.fail "{a,c}: unfolded precrease is one cluster");
  (match Fold_state.flap_of_points st [ pt 1 0; pt 0 1 ] with
   | `Cluster _ -> ()  (* b and d sit on opposite triangles, same cluster *)
   | _ -> Alcotest.fail "{b,d}: unfolded precrease is one cluster")

(* coplanar_clusters: a single unfolded face is its own (only) cluster. *)
let test_coplanar_clusters_flat_square () =
  Alcotest.(check (list int)) "one face -> one cluster" [ 0 ]
    (Array.to_list (Fold_state.coplanar_clusters Fold_state.init_square))

(* Once a crease is actually FOLDED (F -> M/V), the flap splits there: the two
   faces land in different clusters, and a point-set spanning both (off the
   crease) no longer shares a flap. *)
let test_cluster_split_on_fold () =
  let pt x y = { Geom.x = Num.of_int x; y = Num.of_int y } in
  let st =
    Fold_state.simple_fold Fold_state.init_square
      ~axis:{ Geom.a = Num.zero; b = Num.one; c = Num.of_q (Q.of_ints 1 2) }
      ~move_side:1 ~valley:true
  in
  let cl = Fold_state.coplanar_clusters st in
  Alcotest.(check bool) "folded faces land in different clusters" true
    (cl.(0) <> cl.(1));
  match Fold_state.flap_of_points st [ pt 0 0; pt 0 1 ] with
  | `Zero -> () (* a (face 0) and d (face 1), off the now-folded crease *)
  | _ -> Alcotest.fail "points on opposite folded faces should share no flap"

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
    eassign = Fold_state.F;
    crease_id = cid;
    eprov = None;
  }

(* Build a state from identity-placed faces (paper = table), explicit edges, and
   a top→bottom rank per face (higher rank = higher in the stack). *)
let mk_state faces edges ranks =
  let rel_of i j =
    if ranks.(i) > ranks.(j) then Fold_state.Above else Fold_state.Below
  in
  { Fold_state.faces; order = Fold_state.build_order faces rel_of; edges; marks = [||] }

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

(* --- line_material_segments / line_cuts_paper ----------------------------- *)

let test_line_material_segments_flat_square () =
  let l = { Geom.a = Num.zero; b = Num.one; c = qf 1 2 } (* y = 1/2 *) in
  match Fold_state.line_material_segments Fold_state.init_square l with
  | [ (a, b) ] ->
      Alcotest.(check bool)
        "segment is (0,1/2)-(1,1/2)" true
        ((Geom.point_equal a { Geom.x = q 0; y = qf 1 2 }
          && Geom.point_equal b { Geom.x = q 1; y = qf 1 2 })
        || (Geom.point_equal a { Geom.x = q 1; y = qf 1 2 }
           && Geom.point_equal b { Geom.x = q 0; y = qf 1 2 }))
  | other -> Alcotest.failf "expected exactly 1 segment, got %d" (List.length other)

let test_line_cuts_paper_flat_square () =
  let mid = { Geom.a = Num.zero; b = Num.one; c = qf 1 2 } (* y = 1/2 *) in
  let outside = { Geom.a = Num.one; b = Num.zero; c = q 2 } (* x = 2 *) in
  let edge = { Geom.a = Num.one; b = Num.zero; c = q 0 } (* x = 0, on the boundary *) in
  Alcotest.(check bool) "y=1/2 cuts the square" true
    (Fold_state.line_cuts_paper Fold_state.init_square mid);
  Alcotest.(check bool) "x=2 misses the square" false
    (Fold_state.line_cuts_paper Fold_state.init_square outside);
  Alcotest.(check bool) "x=0 only grazes the boundary (closed-vs-strict)" false
    (Fold_state.line_cuts_paper Fold_state.init_square edge)

(* unit square valley-folded along x=1/2, right half moved onto the left:
   table space becomes [0,1/2]x[0,1], 2 faces stacked *)
let two_layer_x () =
  Fold_state.simple_fold Fold_state.init_square
    ~axis:{ Geom.a = Num.one; b = Num.zero; c = qf 1 2 }
    ~move_side:1 ~valley:true

let test_line_material_segments_folded () =
  let st = two_layer_x () in
  let l = { Geom.a = Num.zero; b = Num.one; c = qf 1 2 } (* y = 1/2 *) in
  match Fold_state.line_material_segments st l with
  | [ _; _ ] -> ()
  | other -> Alcotest.failf "expected 2 segments (one per layer), got %d" (List.length other)

let test_line_cuts_paper_folded () =
  let st = two_layer_x () in
  let l = { Geom.a = Num.one; b = Num.zero; c = qf 3 4 } (* x = 3/4 *) in
  Alcotest.(check bool)
    "x=3/4 misses the folded material (now confined to [0,1/2])" false
    (Fold_state.line_cuts_paper st l)

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

(* Same physical configuration as [taco_tortilla_faces], but c is placed by a
   REFLECTED isometry (det -1) rather than identity — the same footprint,
   reached the way a genuinely folded face would be. Reflecting c's paper
   square across its own vertical midline (x=2) fixes the two side edges in
   place but swaps the corners, so table_poly_of's un-normalized winding comes
   out CW. segment_crosses_interior assumes CCW input ("interior is left of
   each edge"); fed a CW polygon it silently reports no interior crossing, so
   the taco-tortilla violation must still fire here or the check is blind on
   every reflected face — i.e. on most real folded states. *)
let taco_tortilla_faces_reflected () =
  let refl = Isometry.reflect_across_line (line 1 0 2) (* x = 2 *) in
  [|
    mkface [| pt 0 0; pt 4 0; pt 4 4; pt 0 4 |] (* a *);
    mkface [| pt 0 0; pt 4 0; pt 4 4; pt 0 4 |] (* b *);
    { Fold_state.paper = [| pt 1 (-2); pt 3 (-2); pt 3 2; pt 1 2 |]; iso = refl }
    (* c straddles y=0, placed by a reflection: table footprint identical to
       [taco_tortilla_faces]'s c, but table_poly_of winds it CW *);
  |]

let test_taco_tortilla_fires_on_reflected_face () =
  (* a > c > b : c is sandwiched between the taco's two faces, same as
     [test_taco_tortilla_fires], but c is a reflected (CW) face. *)
  let st =
    mk_state (taco_tortilla_faces_reflected ()) (taco_tortilla_edges ()) [| 2; 0; 1 |]
  in
  Alcotest.(check int) "sanity: c is indeed reflected" (-1)
    (Isometry.det_sign st.Fold_state.faces.(2).Fold_state.iso);
  expect_violation "taco-tortilla when reflected c is between a and b"
    "taco-tortilla" st

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

(* --- scoped fold ("up to") machinery (#65 Task 2) ------------------------- *)

(* two-layer stack: unit square valley-folded along y=1/2, top half moved down *)
let two_layer () =
  Fold_state.simple_fold Fold_state.init_square
    ~axis:{ Geom.a = Num.zero; b = Num.one; c = Num.of_q (Q.of_ints 1 2) }
    ~move_side:1 ~valley:true

let vline_half = { Geom.a = Num.one; b = Num.zero; c = Num.of_q (Q.of_ints 1 2) }

(* the top face of the 2-layer stack = the moved one (index found via order) *)
let top_face (st : Fold_state.t) =
  let n = Array.length st.Fold_state.faces in
  let is_top i =
    List.for_all
      (fun j -> i = j || Layer_order.get st.Fold_state.order i j <> Layer_order.Below)
      (List.init n Fun.id)
  in
  match List.find_opt is_top (List.init n Fun.id) with
  | Some i -> i
  | None -> Alcotest.fail "no top face"

let test_select_scope_top_only () =
  let st = two_layer () in
  let top = top_face st in
  match
    Fold_state.select_scope st ~axis:vline_half ~move_side:1 ~valley:true
      ~anchor:top ~target:(Fold_state.TargetFace top)
  with
  | Ok m ->
      Alcotest.(check int) "exactly one moving parent" 1
        (Array.fold_left (fun a b -> if b then a + 1 else a) 0 m);
      Alcotest.(check bool) "it is the top face" true m.(top)
  | Error e -> Alcotest.fail e

let test_select_scope_buried_anchor () =
  let st = two_layer () in
  let top = top_face st in
  let bottom = 1 - top in
  match
    Fold_state.select_scope st ~axis:vline_half ~move_side:1 ~valley:true
      ~anchor:bottom ~target:(Fold_state.TargetFace bottom)
  with
  | Ok _ -> Alcotest.fail "expected a buried-anchor error"
  | Error e ->
      Alcotest.(check bool) "mentions covering" true
        (try
           ignore (Str.search_forward (Str.regexp_string "cover") e 0);
           true
         with Not_found -> false)

let test_scoped_fold_leaves_others_uncut () =
  let st = two_layer () in
  let top = top_face st in
  let m = Array.init (Array.length st.Fold_state.faces) (fun i -> i = top) in
  let st' =
    Fold_state.fold_with_records st ~moving_parents:m ~axis:vline_half
      ~move_side:1 ~valley:true ~prov:None
  in
  (* top face splits in two, bottom stays whole: 3 faces, not 4 *)
  Alcotest.(check int) "three faces" 3 (Array.length st'.Fold_state.faces)

let test_unscoped_fold_unchanged () =
  let st = two_layer () in
  let st' =
    Fold_state.fold_with_records st ~axis:vline_half ~move_side:1 ~valley:true
      ~prov:None
  in
  Alcotest.(check int) "all-layers cuts both: four faces" 4
    (Array.length st'.Fold_state.faces)

(* Cohesion (ADR 0017 defect 2): a coplanar cluster (F-adjacent faces) must
   move as a unit even when its members never geometrically overlap each
   other, so the existing `outer`/overlap closure can't see the link. Two
   side-by-side top-layer siblings (topA, topB) share an F edge and both sit
   above a bottom face; the fold axis is placed off to the side so every face
   is fully a candidate (the axis does NOT cut the cluster). Anchored at
   topA with `up to` itself (the minimal scope), the OLD closure — overlap-only
   — never reaches topB (they don't overlap; they're side by side), leaving a
   still-flat neighbour behind. Cohesion must pull topB in anyway. *)
let test_select_scope_cohesion_pulls_in_u_sibling () =
  let bot = mkface [| pt 0 0; pt 4 0; pt 4 4; pt 0 4 |] in
  let top_a = mkface [| pt 0 0; pt 2 0; pt 2 4; pt 0 4 |] in
  let top_b = mkface [| pt 2 0; pt 4 0; pt 4 4; pt 2 4 |] in
  let edges = [| mkedge ~ea:(pt 2 0) ~eb:(pt 2 4) ~left:1 ~right:2 ~cid:300 |] in
  let st = mk_state [| bot; top_a; top_b |] edges [| 0; 5; 5 |] in
  (* axis far to the left: every face is entirely on move_side=1, so the axis
     never cuts the cluster — this is not the "legitimate tear" case *)
  let axis = { Geom.a = Num.one; b = Num.zero; c = Num.of_int (-100) } in
  match
    Fold_state.select_scope st ~axis ~move_side:1 ~valley:true ~anchor:1
      ~target:(Fold_state.TargetFace 1)
  with
  | Error e -> Alcotest.fail e
  | Ok m ->
      Alcotest.(check bool) "anchor (topA) moves" true m.(1);
      Alcotest.(check bool) "F-adjacent sibling (topB) moves too (cohesion)"
        true m.(2);
      Alcotest.(check bool) "bottom face does not move" false m.(0)

(* add a dangling point mark at (1/4,1/4), fold the square in half along
   x=1/2, and assert the mark survives unchanged (paper coords fold-invariant).
   Local [pt] here is the rational 4-arg form (a/b, c/d), distinct from the
   top-level 2-arg int [pt] used elsewhere in this file. *)
let test_marks_carry_through_fold () =
  let pt a b c d = { Geom.x = qf a b; y = qf c d } in
  let p = pt 1 4 1 4 in
  let m =
    { Fold_state.mgeom = Fold_state.MPoint p;
      mline = Geom.line_through p (pt 3 4 1 4);
      mintent = Fold_state.V; mcrease_id = 999 }
  in
  let st = Fold_state.add_mark Fold_state.init_square m in
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in  (* x = 1/2, as elsewhere in this file *)
  let st' = Fold_state.fold_with_records st ~axis ~move_side:1 ~valley:true ~prov:None in
  Alcotest.(check int) "one mark preserved" 1 (Array.length st'.Fold_state.marks);
  let m' = st'.Fold_state.marks.(0) in
  (match m'.Fold_state.mgeom with
   | Fold_state.MPoint qp -> Alcotest.(check bool) "paper coord unchanged" true (Geom.point_equal p qp)
   | _ -> Alcotest.fail "geom kind changed");
  Alcotest.(check bool) "mark_face resolves to a face"
    true (Fold_state.mark_face st' m' <> None)

(* --- classify_mark_extent (#partial marks / pinch, Task 3) ---------------- *)

let flap0 = [ 0 ]

let test_classify_interior_segment_records () =
  let pt a b c d = { Geom.x = qf a b; y = qf c d } in
  let a = pt 1 4 1 4 and b = pt 1 2 1 2 in
  let axis = Geom.line_through a b in
  match
    Fold_state.classify_mark_extent Fold_state.init_square ~flap:flap0 ~axis
      ~extent_geom:(Fold_state.MSeg (a, b))
  with
  | Fold_state.CRecord (Fold_state.MSeg _) -> ()
  | _ -> Alcotest.fail "interior segment should record"

let test_classify_boundary_to_boundary_subdivides () =
  let pt a b c d = { Geom.x = qf a b; y = qf c d } in
  let a = pt 0 1 1 2 and b = pt 1 1 1 2 in
  (* left edge (0,1/2) to right edge (1,1/2) *)
  let axis = Geom.line_through a b in
  match
    Fold_state.classify_mark_extent Fold_state.init_square ~flap:flap0 ~axis
      ~extent_geom:(Fold_state.MSeg (a, b))
  with
  | Fold_state.CSubdivide _ -> ()
  | _ -> Alcotest.fail "chord should subdivide"

let test_classify_point_records () =
  let pt a b c d = { Geom.x = qf a b; y = qf c d } in
  let p = pt 1 3 1 3 in
  let axis = Geom.line_through p (pt 2 3 1 3) in
  match
    Fold_state.classify_mark_extent Fold_state.init_square ~flap:flap0 ~axis
      ~extent_geom:(Fold_state.MPoint p)
  with
  | Fold_state.CRecord (Fold_state.MPoint _) -> ()
  | _ -> Alcotest.fail "point should record"

let test_classify_crosses_fold () =
  (* fold at x=1/2 -> 2 faces in DIFFERENT coplanar clusters, joined by a V
     edge. A horizontal extent (1/4,1/2)->(3/4,1/2) leaves the left flap
     across it. *)
  let pt a b c d = { Geom.x = qf a b; y = qf c d } in
  let axis = { Geom.a = Num.one; b = Num.zero; c = qf 1 2 } in
  let st =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
      ~valley:true ~prov:None
  in
  let left =
    Option.get
      (Fold_state.mark_face st
         {
           Fold_state.mgeom = Fold_state.MPoint (pt 1 4 1 4);
           mline = axis;
           mintent = Fold_state.V;
           mcrease_id = 0;
         })
  in
  let a = pt 1 4 1 2 and b = pt 3 4 1 2 in
  match
    Fold_state.classify_mark_extent st ~flap:[ left ]
      ~axis:(Geom.line_through a b) ~extent_geom:(Fold_state.MSeg (a, b))
  with
  | Fold_state.CCrossesFold _ -> ()
  | _ -> Alcotest.fail "extent across a folded crease must be CCrossesFold"

let test_classify_mixed () =
  (* subdivide along y=1/2 (an F edge; the halves stay ONE coplanar cluster).
     Vertical extent (1/2,1) [top boundary] -> (1/2,1/4) [interior of lower
     half] subdivides the upper part and records the dangling stub. *)
  let pt a b c d = { Geom.x = qf a b; y = qf c d } in
  let mid = Geom.line_through (pt 0 1 1 2) (pt 1 1 1 2) in
  let st = Fold_state.subdivide Fold_state.init_square mid ~prov:None in
  let flap = List.init (Array.length st.Fold_state.faces) Fun.id in
  (* one F-joined cluster *)
  let a = pt 1 2 1 1 and b = pt 1 2 1 4 in
  match
    Fold_state.classify_mark_extent st ~flap ~axis:(Geom.line_through a b)
      ~extent_geom:(Fold_state.MSeg (a, b))
  with
  | Fold_state.CMixed (_, _, Fold_state.MSeg _, cut_faces) ->
      (* the boundary portion cuts exactly one face (the top half), never the
         stub's (lower) face *)
      Alcotest.(check int) "CMixed cuts exactly the boundary face" 1
        (List.length cut_faces)
  | _ -> Alcotest.fail "boundary->interior across an F edge must be CMixed"

(* Task 3 review finding: both extent endpoints strictly interior but in
   DIFFERENT flap faces has no double-stub [mark_class] constructor, and used
   to `invalid_arg`. Three F-joined faces along one flap — cut the square at
   x=1/4 and x=1/2, giving [0,1/4]x[0,1], [1/4,1/2]x[0,1], [1/2,1]x[0,1] — with
   a horizontal extent at y=1/2 whose ends sit strictly inside the outer two
   faces (never touching x=1/4 or x=1/2) must come back as [CSpansCrease],
   not raise. *)
let test_classify_spans_crease_both_interior_different_faces () =
  let pt a b c d = { Geom.x = qf a b; y = qf c d } in
  let cut1 = Geom.line_through (pt 1 4 0 1) (pt 1 4 1 1) in
  let cut2 = Geom.line_through (pt 1 2 0 1) (pt 1 2 1 1) in
  let st =
    Fold_state.subdivide
      (Fold_state.subdivide Fold_state.init_square cut1 ~prov:None)
      cut2 ~prov:None
  in
  Alcotest.(check int) "three faces" 3 (Array.length st.Fold_state.faces);
  let flap = List.init (Array.length st.Fold_state.faces) Fun.id in
  (* (1/8,1/2) strictly inside [0,1/4]x[0,1]; (3/4,1/2) strictly inside
     [1/2,1]x[0,1] — different faces, neither touching x=1/4 or x=1/2. *)
  let a = pt 1 8 1 2 and b = pt 3 4 1 2 in
  match
    Fold_state.classify_mark_extent st ~flap ~axis:(Geom.line_through a b)
      ~extent_geom:(Fold_state.MSeg (a, b))
  with
  | Fold_state.CSpansCrease _ -> ()
  | _ ->
      Alcotest.fail
        "both-interior-different-faces extent must be CSpansCrease, not raise"

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
          Alcotest.test_case "subdivide produces F edge" `Quick
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
          Alcotest.test_case "coplanar_clusters: flat square is one cluster"
            `Quick test_coplanar_clusters_flat_square;
          Alcotest.test_case "coplanar_clusters: fold splits the cluster"
            `Quick test_cluster_split_on_fold;
        ] );
      ( "line-material",
        [
          Alcotest.test_case "line_material_segments: flat square, 1 segment"
            `Quick test_line_material_segments_flat_square;
          Alcotest.test_case "line_cuts_paper: flat square (mid/outside/edge)"
            `Quick test_line_cuts_paper_flat_square;
          Alcotest.test_case "line_material_segments: folded, 2 segments"
            `Quick test_line_material_segments_folded;
          Alcotest.test_case "line_cuts_paper: folded, off-material line misses"
            `Quick test_line_cuts_paper_folded;
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
          Alcotest.test_case "taco-tortilla fires on a reflected (CW) sandwiched face"
            `Quick test_taco_tortilla_fires_on_reflected_face;
          Alcotest.test_case "taco-taco fires when creases interleave" `Quick
            test_taco_taco_fires;
          Alcotest.test_case "taco-taco silent when tacos nest" `Quick
            test_taco_taco_ok_nested;
          Alcotest.test_case "taco-taco silent when tacos are separated" `Quick
            test_taco_taco_ok_separated;
        ] );
      ( "scoped-fold",
        [
          Alcotest.test_case "select_scope: target is the sole moving parent"
            `Quick test_select_scope_top_only;
          Alcotest.test_case "select_scope: buried anchor errors" `Quick
            test_select_scope_buried_anchor;
          Alcotest.test_case "scoped fold leaves non-moving faces uncut" `Quick
            test_scoped_fold_leaves_others_uncut;
          Alcotest.test_case "unscoped fold unchanged (status quo)" `Quick
            test_unscoped_fold_unchanged;
          Alcotest.test_case
            "cohesion: F-adjacent sibling moves with its cluster (ADR 0017)"
            `Quick test_select_scope_cohesion_pulls_in_u_sibling;
        ] );
      ( "marks",
        [
          Alcotest.test_case "marks carry through fold unchanged" `Quick
            test_marks_carry_through_fold;
        ] );
      ( "classify_mark_extent",
        [
          Alcotest.test_case "interior segment records" `Quick
            test_classify_interior_segment_records;
          Alcotest.test_case "boundary-to-boundary chord subdivides" `Quick
            test_classify_boundary_to_boundary_subdivides;
          Alcotest.test_case "point records" `Quick test_classify_point_records;
          Alcotest.test_case "extent across a folded crease errors" `Quick
            test_classify_crosses_fold;
          Alcotest.test_case "boundary->interior across F edge is mixed"
            `Quick test_classify_mixed;
          Alcotest.test_case
            "both interior in different faces -> CSpansCrease, not raise"
            `Quick test_classify_spans_crease_both_interior_different_faces;
        ] );
    ]
