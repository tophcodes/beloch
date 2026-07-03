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
    ]
