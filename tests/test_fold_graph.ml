open Beloch

let q = Num.of_int
let gp x y : Geom.point = { Geom.x = q x; y = q y }
let sq a b c d : Fold_graph.face = [| a; b; c; d |]

let i3eq (a : Isometry3.point) (b : Isometry3.point) =
  Num.equal a.Isometry3.x b.Isometry3.x
  && Num.equal a.Isometry3.y b.Isometry3.y
  && Num.equal a.Isometry3.z b.Isometry3.z

let p3 x y z : Isometry3.point = { Isometry3.x = q x; y = q y; z = q z }

(* line x = k : a=1,b=0,c=k *)
let vline k : Geom.line = { Geom.a = q 1; b = q 0; c = q k }
(* line y = k : a=0,b=1,c=k *)
let hline k : Geom.line = { Geom.a = q 0; b = q 1; c = q k }

(* Task 1 helper: metadata-carrying hinge literal with defaults *)
let mkh ?(cid = -1) ?(intent = Fold_graph.F) ?(prov = None) fa fb line angle =
  { Fold_graph.fa; fb; line; angle; crease_id = cid; intent; prov }

let mk ?(root = 0) ~faces ~hinges ~rank () =
  match Fold_graph.make ~faces ~hinges ~root ~rank () with
  | Ok g -> g
  | Error v -> Alcotest.failf "expected Ok, got: %s" (Fold_graph.violation_to_string v)

let expect_error label pred ~faces ~hinges ~root ~rank =
  match Fold_graph.make ~faces ~hinges ~root ~rank () with
  | Ok _ -> Alcotest.fail (label ^ ": expected a violation, got Ok")
  | Error v ->
      Alcotest.(check bool)
        (label ^ ": " ^ Fold_graph.violation_to_string v)
        true (pred v)

(* strip of unit squares [k,k+1]x[0,1] *)
let strip_face k w = sq (gp k 0) (gp (k + w) 0) (gp (k + w) 1) (gp k 1)

(* SINGLE FOLD: square split at x=1; face1 folded across x=1 onto face0. *)
let single_fold_faces () = [| strip_face 0 1; strip_face 1 1 |]
let single_fold_hinges () = [| mkh 0 1 (vline 1) (q 1) |]

let test_single_fold () =
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "root at identity" true
    (i3eq (Isometry3.apply_point isos.(0) (p3 3 5 0)) (p3 3 5 0));
  Alcotest.(check bool) "face1 reflects across x=1" true
    (i3eq (Isometry3.apply_point isos.(1) (p3 2 0 0)) (p3 0 0 0));
  Alcotest.(check bool) "face1 above face0" true (Fold_graph.above g 1 0);
  Alcotest.(check bool) "face0 not above face1" false (Fold_graph.above g 0 1)

(* ACCORDION: strip [0,1],[1,2],[2,3]; hinges at x=1 and x=2, both folded. *)
let test_accordion () =
  let faces = [| strip_face 0 1; strip_face 1 1; strip_face 2 1 |] in
  let hinges = [| mkh 0 1 (vline 1) (q 1); mkh 1 2 (vline 2) (q 1) |] in
  let g = mk ~faces ~hinges ~rank:[| 0; 1; 2 |] () in
  let isos = Fold_graph.face_isos g in
  let half = Num.of_q (Q.of_ints 1 2) in
  Alcotest.(check bool) "face2 folds back to x=1/2" true
    (i3eq
       (Isometry3.apply_point isos.(2)
          { Isometry3.x = Num.of_q (Q.of_ints 5 2); y = half; z = q 0 })
       { Isometry3.x = half; y = half; z = q 0 })

let test_rejects_bad_angle () =
  let hinges = [| mkh 0 1 (vline 1) (Num.of_q (Q.of_ints 1 2)) |] in
  expect_error "angle 1/2 outside flat-first domain"
    (function Fold_graph.Bad_angle 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_bad_rank () =
  expect_error "duplicate rank"
    (function Fold_graph.Bad_rank -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:0 ~rank:[| 0; 0 |];
  expect_error "rank length mismatch"
    (function Fold_graph.Bad_rank -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:0 ~rank:[| 0 |]

let test_rejects_bad_index () =
  expect_error "hinge face out of range"
    (function Fold_graph.Bad_index _ -> true | _ -> false)
    ~faces:(single_fold_faces ())
    ~hinges:[| mkh 0 5 (vline 1) (q 1) |]
    ~root:0 ~rank:[| 0; 1 |];
  expect_error "root out of range"
    (function Fold_graph.Bad_index _ -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:7 ~rank:[| 0; 1 |]

let test_rejects_disconnected () =
  expect_error "two faces, no hinges"
    (function Fold_graph.Disconnected _ -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:[||] ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_line_not_between () =
  (* line x=1/2 cuts face0 instead of separating the faces *)
  let hinges =
    [| mkh 0 1
         { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 1 2) }
         (q 1) |]
  in
  expect_error "line cuts a face"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_gap () =
  (* faces [0,1]² and [2,3]²: opposite sides of x=3/2, but no shared edge *)
  let faces = [| strip_face 0 1; strip_face 2 1 |] in
  let hinges =
    [| mkh 0 1
         { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 3 2) }
         (q 1) |]
  in
  expect_error "faces do not touch the line"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_vertex_touch () =
  (* [0,1]² and [1,2]×[1,2] share only the corner (1,1) on line x=1 *)
  let faces =
    [| strip_face 0 1; sq (gp 1 1) (gp 2 1) (gp 2 2) (gp 1 2) |]
  in
  let hinges = [| mkh 0 1 (vline 1) (q 1) |] in
  expect_error "zero-length shared boundary"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces ~hinges ~root:0 ~rank:[| 0; 1 |]

(* Quadrants of [0,2]²: f0=[0,1]², f1=[1,2]×[0,1], f2=[1,2]×[1,2], f3=[0,1]×[1,2].
   Hinges form a 4-cycle around the interior vertex (1,1). *)
let quadrant_faces () =
  [| sq (gp 0 0) (gp 1 0) (gp 1 1) (gp 0 1);
     sq (gp 1 0) (gp 2 0) (gp 2 1) (gp 1 1);
     sq (gp 1 1) (gp 2 1) (gp 2 2) (gp 1 2);
     sq (gp 0 1) (gp 1 1) (gp 1 2) (gp 0 2) |]

let quadrant_hinges ~last_angle =
  [| mkh 0 1 (vline 1) (q 1);
     mkh 1 2 (hline 1) (q 1);
     mkh 2 3 (vline 1) (q 1);
     mkh 3 0 (hline 1) last_angle |]

let test_cycle_closes_fold_in_quarters () =
  (* all four creases folded: reflections compose to identity around the
     vertex — the classic fold-in-quarters; rank = physical stacking *)
  let g =
    mk ~faces:(quadrant_faces ()) ~hinges:(quadrant_hinges ~last_angle:(q 1))
      ~rank:[| 0; 1; 2; 3 |] ()
  in
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "far corner (2,2) lands on (0,0)" true
    (i3eq (Isometry3.apply_point isos.(2) (p3 2 2 0)) (p3 0 0 0))

let test_cycle_tear_rejected () =
  (* only 3 of the 4 creases at an interior vertex folded: the cycle cannot
     close — the sheet would tear along the remaining hinge *)
  expect_error "3-of-4 folded tears"
    (function Fold_graph.Hinge_not_closed _ -> true | _ -> false)
    ~faces:(quadrant_faces ())
    ~hinges:(quadrant_hinges ~last_angle:(q 0))
    ~root:0 ~rank:[| 0; 1; 2; 3 |]

(* Wide-middle accordion: f0=[0,2] (double width), f1=[2,3], f2=[3,4]; both
   hinges folded. Table: f0=[0,2], f1=[1,2], f2=[1,2]; hinge1's crease maps to
   table x=1 — which f0 straddles. Whether f0 crosses it depends on the rank. *)
let tortilla_faces () = [| strip_face 0 2; strip_face 2 1; strip_face 3 1 |]

let tortilla_hinges () =
  [| mkh 0 1 (vline 2) (q 1); mkh 1 2 (vline 3) (q 1) |]

let test_taco_tortilla_fires () =
  (* f0 stacked between the taco (f1|f2) whose crease it straddles *)
  expect_error "tortilla sandwiched in the taco"
    (function
      | Fold_graph.Taco_tortilla { tortilla = 0; hinge = 1 } -> true
      | _ -> false)
    ~faces:(tortilla_faces ()) ~hinges:(tortilla_hinges ())
    ~root:0 ~rank:[| 1; 0; 2 |]

let test_taco_tortilla_ok_outside () =
  (* f0 below the whole taco — legal *)
  let g =
    mk ~faces:(tortilla_faces ()) ~hinges:(tortilla_hinges ())
      ~rank:[| 0; 1; 2 |] ()
  in
  ignore g

let test_taco_tortilla_fires_reflected_root () =
  (* same geometry, root=1: f0 is now placed by a REFLECTION (CW table
     winding). The check must normalize winding or it is blind on most real
     folded states — regression for the CCW normalization. *)
  expect_error "reflected tortilla sandwiched in the taco"
    (function
      | Fold_graph.Taco_tortilla { tortilla = 0; hinge = 1 } -> true
      | _ -> false)
    ~faces:(tortilla_faces ()) ~hinges:(tortilla_hinges ())
    ~root:1 ~rank:[| 1; 0; 2 |]

(* Fold-in-quarters strip: f0..f3 = [k,k+1]×[0,1], hinges at x=1,2,3, all
   folded. All faces stack on [0,1]; hinge0's and hinge2's creases both map to
   table x=1 — a taco-taco configuration decided by the rank. *)
let quarters_faces () =
  [| strip_face 0 1; strip_face 1 1; strip_face 2 1; strip_face 3 1 |]

let quarters_hinges () =
  [| mkh 0 1 (vline 1) (q 1);
     mkh 1 2 (vline 2) (q 1);
     mkh 2 3 (vline 3) (q 1) |]

let test_taco_taco_fires () =
  (* f2 inside taco (f0|f1), f3 outside: the pairs interleave — the paper
     would have to pass through itself at table x=1 *)
  expect_error "interleaved tacos"
    (function Fold_graph.Taco_taco (0, 2) -> true | _ -> false)
    ~faces:(quarters_faces ()) ~hinges:(quarters_hinges ())
    ~root:0 ~rank:[| 1; 3; 2; 0 |]

let test_taco_taco_ok_nested () =
  (* taco (f2|f3) nests entirely inside taco (f0|f1) — legal wrap *)
  let g =
    mk ~faces:(quarters_faces ()) ~hinges:(quarters_hinges ())
      ~rank:[| 0; 3; 2; 1 |] ()
  in
  ignore g

let test_taco_taco_ok_separated () =
  (* zigzag accordion: taco (f0|f1) entirely below taco (f2|f3) — legal *)
  let g =
    mk ~faces:(quarters_faces ()) ~hinges:(quarters_hinges ())
      ~rank:[| 0; 1; 2; 3 |] ()
  in
  ignore g

let test_faces_accessor_deep_copies () =
  (* mutating the array returned by [faces] must not desync the state's
     memoized isos from the geometry the caller can now see. *)
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  let returned = Fold_graph.faces g in
  returned.(0).(0) <- gp 9 9;
  let again = Fold_graph.faces g in
  Alcotest.(check bool) "face 0 vertex 0 unchanged after external mutation" true
    (Geom.point_equal again.(0).(0) (gp 0 0))

let test_make_deep_copies_input_faces () =
  (* mutating the input array's inner face after [make] returns must not
     affect the constructed state's geometry. *)
  let faces = single_fold_faces () in
  let g =
    mk ~faces ~hinges:(single_fold_hinges ()) ~rank:[| 0; 1 |] ()
  in
  faces.(0).(0) <- gp 9 9;
  let seen = Fold_graph.faces g in
  Alcotest.(check bool) "face 0 vertex 0 unchanged after mutating input" true
    (Geom.point_equal seen.(0).(0) (gp 0 0))

let test_rejects_degenerate_hinge_line () =
  let hinges =
    [| mkh 0 1 { Geom.a = q 0; b = q 0; c = q 1 } (q 1) |]
  in
  expect_error "degenerate hinge line a=b=0"
    (function Fold_graph.Bad_line 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_mv_single_fold_valley () =
  (* f1 folded on TOP of face-up f0: the crease is a valley — the calibration
     case (old evaluator: valley folds stack the mover above; fold_state.ml
     assign rule V ⟺ valley XOR reflected). *)
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  Alcotest.(check bool) "f0 is face-up" true (Fold_graph.face_up g 0);
  Alcotest.(check bool) "f1 is face-down" false (Fold_graph.face_up g 1);
  Alcotest.(check bool) "hinge 0 is V" true (Fold_graph.mv g 0 = Fold_graph.V)

let test_mv_single_fold_mountain () =
  (* same fold, f1 tucked UNDER f0: mountain *)
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 1; 0 |] ()
  in
  Alcotest.(check bool) "hinge 0 is M" true (Fold_graph.mv g 0 = Fold_graph.M)

let test_mv_side_symmetric () =
  (* swapping fa/fb in the hinge record must not change the derived MV *)
  let hinges = [| mkh 1 0 (vline 1) (q 1) |] in
  let g = mk ~faces:(single_fold_faces ()) ~hinges ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "still V with fa/fb swapped" true
    (Fold_graph.mv g 0 = Fold_graph.V)

let test_mv_flat_hinge_none () =
  (* two coplanar faces joined by an unfolded crease: no M/V *)
  let hinges = [| mkh 0 1 (vline 1) (q 0) |] in
  let g = mk ~faces:(single_fold_faces ()) ~hinges ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "flat hinge has no MV" true (Fold_graph.mv g 0 = Fold_graph.F)

let test_mv_accordion_zigzag () =
  (* accordion bottom-to-top f0,f1,f2: the two creases alternate V then M *)
  let faces = [| strip_face 0 1; strip_face 1 1; strip_face 2 1 |] in
  let hinges = [| mkh 0 1 (vline 1) (q 1); mkh 1 2 (vline 2) (q 1) |] in
  let g = mk ~faces ~hinges ~rank:[| 0; 1; 2 |] () in
  Alcotest.(check bool) "hinge 0 is V" true (Fold_graph.mv g 0 = Fold_graph.V);
  Alcotest.(check bool) "hinge 1 is M" true (Fold_graph.mv g 1 = Fold_graph.M)

(* Waterbomb-base 8-fan around the square's centre: sector faces
   (c, p_k, p_{k+1}), hinges through c, all folded; the classic
   Kawasaki-satisfying single-vertex cycle. All coordinates rational. *)
let half = Num.of_q (Q.of_ints 1 2)
let gph x y : Geom.point = { Geom.x = x; y }
let c2 = gph half half

let wb_ring =
  [| gph (q 1) half; gph (q 1) (q 1); gph half (q 1); gph (q 0) (q 1);
     gph (q 0) half; gph (q 0) (q 0); gph half (q 0); gph (q 1) (q 0) |]

let wb_faces () =
  Array.init 8 (fun k -> [| c2; wb_ring.(k); wb_ring.((k + 1) mod 8) |])

let wb_lines =
  (* line through c and p_{k+1}, k = 0..7: y=x, x=½, x+y=1, y=½, repeating *)
  [| { Geom.a = q 1; b = q (-1); c = q 0 };
     { Geom.a = q 1; b = q 0; c = half };
     { Geom.a = q 1; b = q 1; c = q 1 };
     { Geom.a = q 0; b = q 1; c = half };
     { Geom.a = q 1; b = q (-1); c = q 0 };
     { Geom.a = q 1; b = q 0; c = half };
     { Geom.a = q 1; b = q 1; c = q 1 };
     { Geom.a = q 0; b = q 1; c = half } |]

let wb_hinges () =
  Array.init 8 (fun k -> mkh k ((k + 1) mod 8) wb_lines.(k) (q 1))

let test_waterbomb_constructs () =
  (* the full 8-cycle passes closure (Kawasaki) and non-crossing (spiral wrap) *)
  let g =
    mk ~faces:(wb_faces ()) ~hinges:(wb_hinges ())
      ~rank:[| 0; 1; 2; 3; 4; 5; 6; 7 |] ()
  in
  (* every face lands on sector 0: p3=(0,1), three hinges from the root,
     must land on p1=(1,1) — trace: R(x+y=1)→(0,1); R(x=½)→(1,1); R(y=x)→(1,1) *)
  let isos = Fold_graph.face_isos g in
  Alcotest.(check bool) "p3 lands on (1,1)" true
    (i3eq
       (Isometry3.apply_point isos.(3)
          { Isometry3.x = q 0; y = q 1; z = q 0 })
       (p3 1 1 0));
  (* centre is fixed by every placement *)
  Alcotest.(check bool) "centre fixed under iso 5" true
    (i3eq
       (Isometry3.apply_point isos.(5)
          { Isometry3.x = half; y = half; z = q 0 })
       { Isometry3.x = half; y = half; z = q 0 })

let test_waterbomb_mv_maekawa () =
  let g =
    mk ~faces:(wb_faces ()) ~hinges:(wb_hinges ())
      ~rank:[| 0; 1; 2; 3; 4; 5; 6; 7 |] ()
  in
  let expected =
    [| Fold_graph.V; M; V; M; V; M; V; V |]
  in
  Array.iteri
    (fun i e ->
      Alcotest.(check bool)
        (Printf.sprintf "hinge %d assignment" i)
        true
        (Fold_graph.mv g i = e))
    expected;
  let m, v =
    Array.fold_left
      (fun (m, v) i ->
        match Fold_graph.mv g i with
        | Fold_graph.M -> (m + 1, v)
        | Fold_graph.V -> (m, v + 1)
        | Fold_graph.F -> (m, v))
      (0, 0)
      (Array.init 8 (fun i -> i))
  in
  Alcotest.(check int) "Maekawa: |M - V| = 2" 2 (abs (m - v))

let test_waterbomb_bad_wrap_rejected () =
  (* swapping the heights of f1 and f2 interleaves tacos {0,1} and {2,3} on
     the y=x ray: rank intervals [0,2] and [1,3] cross — taco-taco *)
  expect_error "illegal wrap order"
    (function Fold_graph.Taco_taco _ -> true | _ -> false)
    ~faces:(wb_faces ()) ~hinges:(wb_hinges ())
    ~root:0 ~rank:[| 0; 2; 1; 3; 4; 5; 6; 7 |]

let test_waterbomb_tear_rejected () =
  (* unfolding one crease of the 8-cycle (angle 0 on h4) breaks Kawasaki
     closure: 7 folded creases at an interior vertex cannot close *)
  let hinges = wb_hinges () in
  hinges.(4) <- { (hinges.(4)) with Fold_graph.angle = q 0 };
  expect_error "7-of-8 folded tears"
    (function Fold_graph.Hinge_not_closed _ -> true | _ -> false)
    ~faces:(wb_faces ()) ~hinges ~root:0 ~rank:[| 0; 1; 2; 3; 4; 5; 6; 7 |]

(* --- Plan 3a Task 1: metadata, marks, base ------------------------------- *)

let test_metadata_carried () =
  let faces = single_fold_faces () in
  let hinges = [| mkh ~cid:7 ~intent:Fold_graph.V 0 1 (vline 1) (q 1) |] in
  let g = mk ~faces ~hinges ~rank:[| 0; 1 |] () in
  let h = (Fold_graph.hinges g).(0) in
  Alcotest.(check int) "crease_id" 7 h.Fold_graph.crease_id;
  Alcotest.(check bool) "intent" true (h.Fold_graph.intent = Fold_graph.V)

let test_mv_total () =
  (* folded hinge derives M or V; flat hinge derives F *)
  let faces = single_fold_faces () in
  let folded = mk ~faces ~hinges:[| mkh 0 1 (vline 1) (q 1) |] ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "folded = V" true (Fold_graph.mv folded 0 = Fold_graph.V);
  let flat = mk ~faces ~hinges:[| mkh 0 1 (vline 1) (q 0) |] ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "flat = F" true (Fold_graph.mv flat 0 = Fold_graph.F)

let test_base_shifts_placements () =
  (* base = translation by (3,0): derived table coords shift; invariants hold *)
  let tr =
    { Isometry3.identity with Isometry3.tx = q 3 }
  in
  let faces = single_fold_faces () in
  let hinges = [| mkh 0 1 (vline 1) (q 1) |] in
  match Fold_graph.make ~base:tr ~faces ~hinges ~root:0 ~rank:[| 0; 1 |] () with
  | Error v -> Alcotest.failf "base: %s" (Fold_graph.violation_to_string v)
  | Ok g ->
      Alcotest.(check bool) "base stored" true
        (Isometry3.equal (Fold_graph.base g) tr);
      let p = Isometry3.apply_point (Fold_graph.face_iso g 0) (p3 0 0 0) in
      Alcotest.(check bool) "root shifted" true (i3eq p (p3 3 0 0))

let test_marks_carried () =
  let m =
    { Fold_graph.mgeom = Fold_graph.MPoint (gp 0 0);
      mline = vline 0; mintent = Fold_graph.M; mcrease_id = 3; mprov = None }
  in
  let g =
    match
      Fold_graph.make ~marks:[| m |] ~faces:[| strip_face 0 2 |] ~hinges:[||]
        ~root:0 ~rank:[| 0 |] ()
    with
    | Ok g -> g
    | Error v -> Alcotest.failf "marks: %s" (Fold_graph.violation_to_string v)
  in
  Alcotest.(check int) "one mark" 1 (Array.length (Fold_graph.marks g))

let test_fresh_ids () =
  Fold_graph.reset_ids ();
  let a = Fold_graph.fresh_crease_id () in
  let b = Fold_graph.fresh_crease_id () in
  Alcotest.(check int) "0" 0 a;
  Alcotest.(check int) "1" 1 b;
  Fold_graph.reset_ids ();
  Alcotest.(check int) "reset" 0 (Fold_graph.fresh_crease_id ())

(* --- Plan 3a Task 2: 2D access ------------------------------------------- *)

(* single fold: face1 = [1,2]x[0,1] folded across x=1 onto face0 = [0,1]x[0,1] *)
let folded_pair () =
  mk ~faces:(single_fold_faces ())
    ~hinges:[| mkh 0 1 (vline 1) (q 1) |] ~rank:[| 0; 1 |] ()

let test_face_iso2 () =
  let g = folded_pair () in
  (* face1's in-plane placement is the reflection across x=1: (2,0) ↦ (0,0) *)
  let p = Isometry.apply_point (Fold_graph.face_iso2 g 1) (gp 2 0) in
  Alcotest.(check bool) "reflected" true (Geom.point_equal p (gp 0 0));
  Alcotest.(check int) "det -1" (-1) (Isometry.det_sign (Fold_graph.face_iso2 g 1));
  Alcotest.(check int) "det +1" 1 (Isometry.det_sign (Fold_graph.face_iso2 g 0))

let test_table_polygon_and_rel () =
  let g = folded_pair () in
  let tp1 = Fold_graph.table_polygon g 1 in
  Alcotest.(check bool) "folded onto [0,1]^2" true
    (Array.for_all Geom.in_unit_square tp1);
  Alcotest.(check bool) "1 above 0" true (Fold_graph.rel g 1 0 = Fold_graph.Above);
  Alcotest.(check bool) "0 below 1" true (Fold_graph.rel g 0 1 = Fold_graph.Below);
  (* flat (unfolded) neighbours do not overlap -> Apart *)
  let flat =
    mk ~faces:(single_fold_faces ())
      ~hinges:[| mkh 0 1 (vline 1) (q 0) |] ~rank:[| 0; 1 |] ()
  in
  Alcotest.(check bool) "flat Apart" true (Fold_graph.rel flat 0 1 = Fold_graph.Apart)

let test_hinge_segments () =
  let g = folded_pair () in
  let a, b = Fold_graph.hinge_segment g 0 in
  Alcotest.(check bool) "paper seg on x=1" true
    (Num.equal a.Geom.x (q 1) && Num.equal b.Geom.x (q 1));
  let ta, tb = Fold_graph.hinge_table_segment g 0 in
  Alcotest.(check bool) "table seg on x=1" true
    (Num.equal ta.Geom.x (q 1) && Num.equal tb.Geom.x (q 1))

let test_point_queries () =
  let g = folded_pair () in
  (* paper (3/2, 1/2) lives on face1 -> table (1/2, 1/2) *)
  let half = Num.div Num.one (Num.of_int 2) in
  let three_half = Num.div (Num.of_int 3) (Num.of_int 2) in
  let tp = Fold_graph.table_position g { Geom.x = three_half; y = half } in
  Alcotest.(check bool) "table pos" true
    (Geom.point_equal tp { Geom.x = half; y = half });
  (* table (1/2,1/2) is covered by both layers -> two paper preimages *)
  let pre = Fold_graph.paper_preimages g { Geom.x = half; y = half } in
  Alcotest.(check int) "two layers" 2 (List.length pre);
  Alcotest.(check bool) "on paper" true
    (Fold_graph.on_paper g { Geom.x = three_half; y = half });
  Alcotest.(check bool) "off paper" false
    (Fold_graph.on_paper g { Geom.x = q 5; y = q 5 })

let () =
  Alcotest.run "fold_graph"
    [ ( "derive",
        [ Alcotest.test_case "single fold" `Quick test_single_fold;
          Alcotest.test_case "accordion path" `Quick test_accordion ] );
      ( "make-structure",
        [ Alcotest.test_case "bad angle" `Quick test_rejects_bad_angle;
          Alcotest.test_case "bad rank" `Quick test_rejects_bad_rank;
          Alcotest.test_case "bad index" `Quick test_rejects_bad_index;
          Alcotest.test_case "disconnected" `Quick test_rejects_disconnected;
          Alcotest.test_case "degenerate hinge line" `Quick
            test_rejects_degenerate_hinge_line ] );
      ( "sealing",
        [ Alcotest.test_case "faces accessor deep-copies" `Quick
            test_faces_accessor_deep_copies;
          Alcotest.test_case "make deep-copies input faces" `Quick
            test_make_deep_copies_input_faces ] );
      ( "make-adjacency",
        [ Alcotest.test_case "line cuts a face" `Quick
            test_rejects_hinge_line_not_between;
          Alcotest.test_case "gap between faces" `Quick test_rejects_hinge_gap;
          Alcotest.test_case "vertex touch only" `Quick
            test_rejects_hinge_vertex_touch ] );
      ( "make-closure",
        [ Alcotest.test_case "fold-in-quarters cycle closes" `Quick
            test_cycle_closes_fold_in_quarters;
          Alcotest.test_case "3-of-4 folded at a vertex tears" `Quick
            test_cycle_tear_rejected ] );
      ( "non-crossing",
        [ Alcotest.test_case "taco-tortilla fires when sandwiched" `Quick
            test_taco_tortilla_fires;
          Alcotest.test_case "taco-tortilla silent outside the taco" `Quick
            test_taco_tortilla_ok_outside;
          Alcotest.test_case "taco-tortilla fires on reflected (CW) tortilla"
            `Quick test_taco_tortilla_fires_reflected_root;
          Alcotest.test_case "taco-taco fires when pairs interleave" `Quick
            test_taco_taco_fires;
          Alcotest.test_case "taco-taco silent when nested" `Quick
            test_taco_taco_ok_nested;
          Alcotest.test_case "taco-taco silent when separated" `Quick
            test_taco_taco_ok_separated ] );
      ( "derived-mv",
        [ Alcotest.test_case "single fold valley" `Quick test_mv_single_fold_valley;
          Alcotest.test_case "single fold mountain" `Quick
            test_mv_single_fold_mountain;
          Alcotest.test_case "side-symmetric" `Quick test_mv_side_symmetric;
          Alcotest.test_case "flat hinge none" `Quick test_mv_flat_hinge_none;
          Alcotest.test_case "accordion zigzag V,M" `Quick test_mv_accordion_zigzag ] );
      ( "waterbomb",
        [ Alcotest.test_case "8-cycle constructs (closure + wrap)" `Quick
            test_waterbomb_constructs;
          Alcotest.test_case "derived MV satisfies Maekawa" `Quick
            test_waterbomb_mv_maekawa;
          Alcotest.test_case "illegal wrap order rejected" `Quick
            test_waterbomb_bad_wrap_rejected;
          Alcotest.test_case "7-of-8 folded tears" `Quick
            test_waterbomb_tear_rejected ] );
      ( "task1-metadata",
        [ Alcotest.test_case "metadata carried" `Quick test_metadata_carried;
          Alcotest.test_case "mv total" `Quick test_mv_total;
          Alcotest.test_case "base shifts placements" `Quick
            test_base_shifts_placements;
          Alcotest.test_case "marks carried" `Quick test_marks_carried;
          Alcotest.test_case "fresh ids" `Quick test_fresh_ids ] );
      ( "task2-2d-access",
        [ Alcotest.test_case "face_iso2" `Quick test_face_iso2;
          Alcotest.test_case "table polygon and rel" `Quick
            test_table_polygon_and_rel;
          Alcotest.test_case "hinge segments" `Quick test_hinge_segments;
          Alcotest.test_case "point queries" `Quick test_point_queries ] ) ]
