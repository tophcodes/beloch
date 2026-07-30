open Beloch

let q = Num.of_int
let gp x y : Geom.point = { Geom.x = q x; y = q y }
let sq a b c d : Fold_state.face = [| a; b; c; d |]

let i3eq (a : Isometry3.point) (b : Isometry3.point) =
  Num.equal a.Isometry3.x b.Isometry3.x
  && Num.equal a.Isometry3.y b.Isometry3.y
  && Num.equal a.Isometry3.z b.Isometry3.z

let p3 x y z : Isometry3.point = { Isometry3.x = q x; y = q y; z = q z }

(* line x = k : a=1,b=0,c=k *)
let vline k : Geom.line = { Geom.a = q 1; b = q 0; c = q k }
(* line y = k : a=0,b=1,c=k *)
let hline k : Geom.line = { Geom.a = q 0; b = q 1; c = q k }
(* line x = 1/2 *)
let vline_half : Geom.line = { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 1 2) }

(* Task 1 helper: metadata-carrying hinge literal with defaults *)
let mkh ?(cid = -1) ?(prov = None) fa fb line angle =
  { Fold_state.fa; fb; line; angle; crease_id = cid; prov }

let mk ?(root = 0) ~faces ~hinges ~rank () =
  match Fold_state.make ~faces ~hinges ~root ~rank () with
  | Ok g -> g
  | Error v -> Alcotest.failf "expected Ok, got: %s" (Fold_state.violation_to_string v)

let expect_error label pred ~faces ~hinges ~root ~rank =
  match Fold_state.make ~faces ~hinges ~root ~rank () with
  | Ok _ -> Alcotest.fail (label ^ ": expected a violation, got Ok")
  | Error v ->
      Alcotest.(check bool)
        (label ^ ": " ^ Fold_state.violation_to_string v)
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
  let isos = Fold_state.face_isos g in
  Alcotest.(check bool) "root at identity" true
    (i3eq (Isometry3.apply_point isos.(0) (p3 3 5 0)) (p3 3 5 0));
  Alcotest.(check bool) "face1 reflects across x=1" true
    (i3eq (Isometry3.apply_point isos.(1) (p3 2 0 0)) (p3 0 0 0));
  Alcotest.(check bool) "face1 above face0" true (Fold_state.above g 1 0);
  Alcotest.(check bool) "face0 not above face1" false (Fold_state.above g 0 1)

(* ACCORDION: strip [0,1],[1,2],[2,3]; hinges at x=1 and x=2, both folded. *)
let test_accordion () =
  let faces = [| strip_face 0 1; strip_face 1 1; strip_face 2 1 |] in
  let hinges = [| mkh 0 1 (vline 1) (q 1); mkh 1 2 (vline 2) (q 1) |] in
  let g = mk ~faces ~hinges ~rank:[| 0; 1; 2 |] () in
  let isos = Fold_state.face_isos g in
  let half = Num.of_q (Q.of_ints 1 2) in
  Alcotest.(check bool) "face2 folds back to x=1/2" true
    (i3eq
       (Isometry3.apply_point isos.(2)
          { Isometry3.x = Num.of_q (Q.of_ints 5 2); y = half; z = q 0 })
       { Isometry3.x = half; y = half; z = q 0 })

(* DEFAULT SCOPE: single fold gives face0 (rank 0) under face1 (rank 1), both
   overlapping [0,1]x[0,1]. Axis x=1/2 cuts both; move_side = +1 (x>1/2 side).
   Seed on the bottom flap grows to the whole stack; seed on the top flap stays
   a singleton — the outside-prefix-down-to-anchor rule. *)
let test_default_scope () =
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  let axis = vline_half in
  let scope seed =
    Fold_state.default_scope g ~axis ~move_side:1 ~valley:true ~seed
    |> Array.to_list
  in
  Alcotest.(check (list bool)) "seed bottom flap -> whole stack moves"
    [ true; true ] (scope [ 0 ]);
  Alcotest.(check (list bool)) "seed top flap -> only it moves"
    [ false; true ] (scope [ 1 ])

let test_rejects_bad_angle () =
  let hinges = [| mkh 0 1 (vline 1) (Num.of_q (Q.of_ints 1 2)) |] in
  expect_error "angle 1/2 outside flat-first domain"
    (function Fold_state.Bad_angle 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_bad_rank () =
  expect_error "duplicate rank"
    (function Fold_state.Bad_rank -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:0 ~rank:[| 0; 0 |];
  expect_error "rank length mismatch"
    (function Fold_state.Bad_rank -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:0 ~rank:[| 0 |]

let test_rejects_bad_index () =
  expect_error "hinge face out of range"
    (function Fold_state.Bad_index _ -> true | _ -> false)
    ~faces:(single_fold_faces ())
    ~hinges:[| mkh 0 5 (vline 1) (q 1) |]
    ~root:0 ~rank:[| 0; 1 |];
  expect_error "root out of range"
    (function Fold_state.Bad_index _ -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
    ~root:7 ~rank:[| 0; 1 |]

let test_rejects_disconnected () =
  expect_error "two faces, no hinges"
    (function Fold_state.Disconnected _ -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges:[||] ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_line_not_between () =
  (* line x=1/2 cuts face0 instead of separating the faces *)
  let hinges =
    [| mkh 0 1
         { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 1 2) }
         (q 1) |]
  in
  expect_error "line cuts a face"
    (function Fold_state.Hinge_not_shared 0 -> true | _ -> false)
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
    (function Fold_state.Hinge_not_shared 0 -> true | _ -> false)
    ~faces ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_vertex_touch () =
  (* [0,1]² and [1,2]×[1,2] share only the corner (1,1) on line x=1 *)
  let faces =
    [| strip_face 0 1; sq (gp 1 1) (gp 2 1) (gp 2 2) (gp 1 2) |]
  in
  let hinges = [| mkh 0 1 (vline 1) (q 1) |] in
  expect_error "zero-length shared boundary"
    (function Fold_state.Hinge_not_shared 0 -> true | _ -> false)
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
  let isos = Fold_state.face_isos g in
  Alcotest.(check bool) "far corner (2,2) lands on (0,0)" true
    (i3eq (Isometry3.apply_point isos.(2) (p3 2 2 0)) (p3 0 0 0))

let test_cycle_tear_rejected () =
  (* only 3 of the 4 creases at an interior vertex folded: the cycle cannot
     close — the sheet would tear along the remaining hinge *)
  expect_error "3-of-4 folded tears"
    (function Fold_state.Hinge_not_closed _ -> true | _ -> false)
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
      | Fold_state.Taco_tortilla { tortilla = 0; hinge = 1 } -> true
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
      | Fold_state.Taco_tortilla { tortilla = 0; hinge = 1 } -> true
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
    (function Fold_state.Taco_taco (0, 2) -> true | _ -> false)
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
  let returned = Fold_state.faces g in
  returned.(0).(0) <- gp 9 9;
  let again = Fold_state.faces g in
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
  let seen = Fold_state.faces g in
  Alcotest.(check bool) "face 0 vertex 0 unchanged after mutating input" true
    (Geom.point_equal seen.(0).(0) (gp 0 0))

let test_rejects_degenerate_hinge_line () =
  let hinges =
    [| mkh 0 1 { Geom.a = q 0; b = q 0; c = q 1 } (q 1) |]
  in
  expect_error "degenerate hinge line a=b=0"
    (function Fold_state.Bad_line 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_mv_single_fold_valley () =
  (* f1 folded on TOP of face-up f0: the crease is a valley — the calibration
     case (old evaluator: valley folds stack the mover above; fold_state.ml
     assign rule V ⟺ valley XOR reflected). *)
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 0; 1 |] ()
  in
  Alcotest.(check bool) "f0 is face-up" true (Fold_state.face_up g 0);
  Alcotest.(check bool) "f1 is face-down" false (Fold_state.face_up g 1);
  Alcotest.(check bool) "hinge 0 is V" true (Fold_state.mv g 0 = Fold_state.V)

let test_mv_single_fold_mountain () =
  (* same fold, f1 tucked UNDER f0: mountain *)
  let g =
    mk ~faces:(single_fold_faces ()) ~hinges:(single_fold_hinges ())
      ~rank:[| 1; 0 |] ()
  in
  Alcotest.(check bool) "hinge 0 is M" true (Fold_state.mv g 0 = Fold_state.M)

let test_mv_side_symmetric () =
  (* swapping fa/fb in the hinge record must not change the derived MV *)
  let hinges = [| mkh 1 0 (vline 1) (q 1) |] in
  let g = mk ~faces:(single_fold_faces ()) ~hinges ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "still V with fa/fb swapped" true
    (Fold_state.mv g 0 = Fold_state.V)

let test_mv_flat_hinge_none () =
  (* two coplanar faces joined by an unfolded crease: no M/V *)
  let hinges = [| mkh 0 1 (vline 1) (q 0) |] in
  let g = mk ~faces:(single_fold_faces ()) ~hinges ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "flat hinge has no MV" true (Fold_state.mv g 0 = Fold_state.F)

let test_mv_accordion_zigzag () =
  (* accordion bottom-to-top f0,f1,f2: the two creases alternate V then M *)
  let faces = [| strip_face 0 1; strip_face 1 1; strip_face 2 1 |] in
  let hinges = [| mkh 0 1 (vline 1) (q 1); mkh 1 2 (vline 2) (q 1) |] in
  let g = mk ~faces ~hinges ~rank:[| 0; 1; 2 |] () in
  Alcotest.(check bool) "hinge 0 is V" true (Fold_state.mv g 0 = Fold_state.V);
  Alcotest.(check bool) "hinge 1 is M" true (Fold_state.mv g 1 = Fold_state.M)

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
  let isos = Fold_state.face_isos g in
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
    [| Fold_state.V; M; V; M; V; M; V; V |]
  in
  Array.iteri
    (fun i e ->
      Alcotest.(check bool)
        (Printf.sprintf "hinge %d assignment" i)
        true
        (Fold_state.mv g i = e))
    expected;
  let m, v =
    Array.fold_left
      (fun (m, v) i ->
        match Fold_state.mv g i with
        | Fold_state.M -> (m + 1, v)
        | Fold_state.V -> (m, v + 1)
        | Fold_state.F -> (m, v))
      (0, 0)
      (Array.init 8 (fun i -> i))
  in
  Alcotest.(check int) "Maekawa: |M - V| = 2" 2 (abs (m - v))

let test_waterbomb_bad_wrap_rejected () =
  (* swapping the heights of f1 and f2 interleaves tacos {0,1} and {2,3} on
     the y=x ray: rank intervals [0,2] and [1,3] cross — taco-taco *)
  expect_error "illegal wrap order"
    (function Fold_state.Taco_taco _ -> true | _ -> false)
    ~faces:(wb_faces ()) ~hinges:(wb_hinges ())
    ~root:0 ~rank:[| 0; 2; 1; 3; 4; 5; 6; 7 |]

let test_waterbomb_tear_rejected () =
  (* unfolding one crease of the 8-cycle (angle 0 on h4) breaks Kawasaki
     closure: 7 folded creases at an interior vertex cannot close *)
  let hinges = wb_hinges () in
  hinges.(4) <- { (hinges.(4)) with Fold_state.angle = q 0 };
  expect_error "7-of-8 folded tears"
    (function Fold_state.Hinge_not_closed _ -> true | _ -> false)
    ~faces:(wb_faces ()) ~hinges ~root:0 ~rank:[| 0; 1; 2; 3; 4; 5; 6; 7 |]

(* --- Plan 3a Task 1: metadata, marks, base ------------------------------- *)

let test_metadata_carried () =
  let faces = single_fold_faces () in
  let hinges = [| mkh ~cid:7 0 1 (vline 1) (q 1) |] in
  let g = mk ~faces ~hinges ~rank:[| 0; 1 |] () in
  let h = (Fold_state.hinges g).(0) in
  Alcotest.(check int) "crease_id" 7 h.Fold_state.crease_id

let test_mv_total () =
  (* folded hinge derives M or V; flat hinge derives F *)
  let faces = single_fold_faces () in
  let folded = mk ~faces ~hinges:[| mkh 0 1 (vline 1) (q 1) |] ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "folded = V" true (Fold_state.mv folded 0 = Fold_state.V);
  let flat = mk ~faces ~hinges:[| mkh 0 1 (vline 1) (q 0) |] ~rank:[| 0; 1 |] () in
  Alcotest.(check bool) "flat = F" true (Fold_state.mv flat 0 = Fold_state.F)

let test_base_shifts_placements () =
  (* base = translation by (3,0): derived table coords shift; invariants hold *)
  let tr =
    { Isometry3.identity with Isometry3.tx = q 3 }
  in
  let faces = single_fold_faces () in
  let hinges = [| mkh 0 1 (vline 1) (q 1) |] in
  match Fold_state.make ~base:tr ~faces ~hinges ~root:0 ~rank:[| 0; 1 |] () with
  | Error v -> Alcotest.failf "base: %s" (Fold_state.violation_to_string v)
  | Ok g ->
      Alcotest.(check bool) "base stored" true
        (Isometry3.equal (Fold_state.base g) tr);
      let p = Isometry3.apply_point (Fold_state.face_iso g 0) (p3 0 0 0) in
      Alcotest.(check bool) "root shifted" true (i3eq p (p3 3 0 0))

let test_marks_carried () =
  let m =
    { Fold_state.mgeom = Fold_state.MPoint (gp 0 0);
      mline = vline 0; mintent = Fold_state.M; mcrease_id = 3; mprov = None }
  in
  let g =
    match
      Fold_state.make ~marks:[| m |] ~faces:[| strip_face 0 2 |] ~hinges:[||]
        ~root:0 ~rank:[| 0 |] ()
    with
    | Ok g -> g
    | Error v -> Alcotest.failf "marks: %s" (Fold_state.violation_to_string v)
  in
  Alcotest.(check int) "one mark" 1 (Array.length (Fold_state.marks g))

let test_fresh_ids () =
  Fold_state.reset_ids ();
  let a = Fold_state.fresh_crease_id () in
  let b = Fold_state.fresh_crease_id () in
  Alcotest.(check int) "0" 0 a;
  Alcotest.(check int) "1" 1 b;
  Fold_state.reset_ids ();
  Alcotest.(check int) "reset" 0 (Fold_state.fresh_crease_id ())

let test_next_id_roundtrip () =
  Fold_state.reset_ids ();
  Alcotest.(check int) "starts at 0" 0 (Fold_state.next_id_value ());
  let _ = Fold_state.fresh_crease_id () in
  let _ = Fold_state.fresh_crease_id () in
  Alcotest.(check int) "advanced to 2" 2 (Fold_state.next_id_value ());
  Fold_state.set_next_id 7;
  Alcotest.(check int) "set to 7" 7 (Fold_state.next_id_value ());
  Alcotest.(check int) "next alloc is 7" 7 (Fold_state.fresh_crease_id ())

(* --- Plan 3a Task 2: 2D access ------------------------------------------- *)

(* single fold: face1 = [1,2]x[0,1] folded across x=1 onto face0 = [0,1]x[0,1] *)
let folded_pair () =
  mk ~faces:(single_fold_faces ())
    ~hinges:[| mkh 0 1 (vline 1) (q 1) |] ~rank:[| 0; 1 |] ()

let test_face_iso2 () =
  let g = folded_pair () in
  (* face1's in-plane placement is the reflection across x=1: (2,0) ↦ (0,0) *)
  let p = Isometry.apply_point (Fold_state.face_iso2 g 1) (gp 2 0) in
  Alcotest.(check bool) "reflected" true (Geom.point_equal p (gp 0 0));
  Alcotest.(check int) "det -1" (-1) (Isometry.det_sign (Fold_state.face_iso2 g 1));
  Alcotest.(check int) "det +1" 1 (Isometry.det_sign (Fold_state.face_iso2 g 0))

let test_table_polygon_and_rel () =
  let g = folded_pair () in
  let tp1 = Fold_state.table_polygon g 1 in
  Alcotest.(check bool) "folded onto [0,1]^2" true
    (Array.for_all Geom.in_unit_square tp1);
  Alcotest.(check bool) "1 above 0" true (Fold_state.rel g 1 0 = Fold_state.Above);
  Alcotest.(check bool) "0 below 1" true (Fold_state.rel g 0 1 = Fold_state.Below);
  (* flat (unfolded) neighbours do not overlap -> Apart *)
  let flat =
    mk ~faces:(single_fold_faces ())
      ~hinges:[| mkh 0 1 (vline 1) (q 0) |] ~rank:[| 0; 1 |] ()
  in
  Alcotest.(check bool) "flat Apart" true (Fold_state.rel flat 0 1 = Fold_state.Apart)

let test_hinge_segments () =
  let g = folded_pair () in
  let a, b = Fold_state.hinge_segment g 0 in
  Alcotest.(check bool) "paper seg on x=1" true
    (Num.equal a.Geom.x (q 1) && Num.equal b.Geom.x (q 1));
  let ta, tb = Fold_state.hinge_table_segment g 0 in
  Alcotest.(check bool) "table seg on x=1" true
    (Num.equal ta.Geom.x (q 1) && Num.equal tb.Geom.x (q 1))

let test_point_queries () =
  let g = folded_pair () in
  (* paper (3/2, 1/2) lives on face1 -> table (1/2, 1/2) *)
  let half = Num.div Num.one (Num.of_int 2) in
  let three_half = Num.div (Num.of_int 3) (Num.of_int 2) in
  let tp = Fold_state.table_position g { Geom.x = three_half; y = half } in
  Alcotest.(check bool) "table pos" true
    (Geom.point_equal tp { Geom.x = half; y = half });
  (* table (1/2,1/2) is covered by both layers -> two paper preimages *)
  let pre = Fold_state.paper_preimages g { Geom.x = half; y = half } in
  Alcotest.(check int) "two layers" 2 (List.length pre);
  Alcotest.(check bool) "on paper" true
    (Fold_state.on_paper g { Geom.x = three_half; y = half });
  Alcotest.(check bool) "off paper" false
    (Fold_state.on_paper g { Geom.x = q 5; y = q 5 })

(* --- Plan 3a Task 3: subdivision ------------------------------------------ *)

let test_subdivide_parity () =
  Fold_state.reset_ids ();
  let diag = { Geom.a = q 1; b = q 1; c = q 1 } in  (* diagonal x+y=1 *)
  let g = Fold_state.subdivide Fold_state.init_square diag ~prov:None in
  (* the new F hinge exists and carries the id *)
  let hs = Fold_state.hinges g in
  Alcotest.(check int) "one hinge" 1 (Array.length hs);
  Alcotest.(check bool) "flat" true (Num.sign hs.(0).Fold_state.angle = 0)

let test_subdivide_paper_parity () =
  (* through subdivide_paper: paper-space clipping. *)
  Fold_state.reset_ids ();
  let diag = { Geom.a = q 1; b = q 1; c = q 1 } in  (* diagonal x+y=1 *)
  let g = Fold_state.subdivide_paper Fold_state.init_square diag ~prov:None in
  let hs = Fold_state.hinges g in
  Alcotest.(check int) "one hinge" 1 (Array.length hs);
  Alcotest.(check bool) "flat" true (Num.sign hs.(0).Fold_state.angle = 0);
  (* second cut, exercising carried-hinge re-attachment under paper clipping *)
  let d2 = { Geom.a = q 1; b = q (-1); c = q 0 } in  (* x - y = 0 *)
  let g2 = Fold_state.subdivide_paper g d2 ~prov:None in
  let hs2 = Fold_state.hinges g2 in
  let pieces_of cid =
    Array.to_list hs2 |> List.filter (fun h -> h.Fold_state.crease_id = cid)
  in
  Alcotest.(check int) "crease 0 split in two" 2 (List.length (pieces_of 0));
  Alcotest.(check int) "crease 1 in two" 2 (List.length (pieces_of 1))

let test_subdivide_carried_split () =
  (* two crossing subdivisions: the first crease's hinge splits into two *)
  Fold_state.reset_ids ();
  let d1 = { Geom.a = q 1; b = q 1; c = q 1 } in
  let d2 = { Geom.a = q 1; b = q (-1); c = q 0 } in
  let g = Fold_state.subdivide (Fold_state.subdivide Fold_state.init_square d1 ~prov:None) d2 ~prov:None in
  (* 4 faces; first crease now two hinge pieces sharing crease_id 0 *)
  let hs = Fold_state.hinges g in
  let pieces_of cid =
    Array.to_list hs |> List.filter (fun h -> h.Fold_state.crease_id = cid)
  in
  Alcotest.(check int) "crease 0 split in two" 2 (List.length (pieces_of 0));
  Alcotest.(check int) "crease 1 in two" 2 (List.length (pieces_of 1))

(* Was a parity test against the old model (Task 3); the old model is gone
   (Plan 3c Task 6), so the concrete face/hinge layout it proved equal is
   inlined directly, computed from THIS construction (verified via a scratch
   run of the same fold graph, git history has the parity-checked provenance):
   the guard confines the axis crease to the y>1/2 side, leaving the whole
   bottom strip (face 2) unsplit and un-hinged to the axis crease. *)
let test_subdivide_keep_side () =
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let axis = { Geom.a = q 1; b = q 0; c = half } in    (* x = 1/2 *)
  let guard = { Geom.a = q 0; b = q 1; c = half } in   (* y = 1/2 *)
  (* pre-split horizontally so the guard has faces on both sides *)
  let base_new = Fold_state.subdivide Fold_state.init_square guard ~prov:None in
  let g = Fold_state.subdivide base_new axis ~keep_side:(guard, 1) ~prov:None in
  Alcotest.(check int) "3 faces (bottom strip stays whole)" 3
    (Array.length (Fold_state.faces g));
  (* the axis crease (cid 1) only hinges the two ABOVE faces, never the
     unsplit bottom strip *)
  let hs = Fold_state.hinges g in
  let axis_hinges =
    Array.to_list hs |> List.filter (fun h -> h.Fold_state.crease_id = 1)
  in
  Alcotest.(check int) "one axis hinge" 1 (List.length axis_hinges);
  let ax_h = List.hd axis_hinges in
  Alcotest.(check bool) "axis hinge doesn't touch the bottom strip" true
    (let below_faces =
       Array.to_list (Fold_state.faces g)
       |> List.mapi (fun i f -> (i, f))
       |> List.filter (fun (_, f) ->
              Array.for_all (fun (p : Geom.point) -> Num.compare p.Geom.y half <= 0) f
              && Array.exists (fun (p : Geom.point) -> Num.sign p.Geom.y = 0) f)
       |> List.map fst
     in
     not (List.mem ax_h.Fold_state.fa below_faces)
     && not (List.mem ax_h.Fold_state.fb below_faces))

(* --- Plan 3a Task 4: fold -------------------------------------------------- *)

let vfold_new g ax = Fold_state.fold g ~axis:ax ~move_side:1 ~valley:true ~prov:None

(* The following fold tests were parity tests against the old model (Task 4);
   the old model is gone (Plan 3c Task 6). Each now asserts the concrete
   face/hinge facts the parity previously proved equal — computed straight
   from [Fold_state.fold] itself (a scratch run pinned these, git history has
   the parity-checked provenance) — instead of re-deriving them by hand. *)

let test_fold_parity_single () =
  Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g = vfold_new Fold_state.init_square ax in
  Alcotest.(check int) "2 faces" 2 (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "hinge 0 is V" true (Fold_state.mv g 0 = Fold_state.V);
  Alcotest.(check bool) "face 1 reflected onto face 0" true
    (Array.exists (Geom.point_equal (gp 0 0)) (Fold_state.table_polygon g 1))

let test_fold_parity_mountain () =
  Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g = Fold_state.fold Fold_state.init_square ~axis:ax ~move_side:1
      ~valley:false ~prov:None in
  Alcotest.(check int) "2 faces" 2 (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "hinge 0 is M" true (Fold_state.mv g 0 = Fold_state.M)

let test_fold_parity_pleat () =
  (* second fold refolds the packet — movers include previously-moved AND
     previously-stationary material, so carried folded hinges move as a block
     (nontrivial base is exercised separately by the flip tests in Task 5) *)
  Fold_state.reset_ids ();
  let quarter = Num.div Num.one (Num.of_int 4) in
  let ax1 = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let ax2 = { Geom.a = q 1; b = q 0; c = quarter } in
  (* fold right half left over x=1/2, then fold everything right of x=1/4
     back over x=1/4, moving the packet to the left *)
  let g = vfold_new (vfold_new Fold_state.init_square ax1) ax2 in
  Alcotest.(check int) "4 faces" 4 (Array.length (Fold_state.faces g));
  let letters =
    Array.to_list (Fold_state.hinges g)
    |> List.mapi (fun i _ -> Fold_state.mv g i)
    |> List.sort compare
  in
  Alcotest.(check bool) "letters are [V;V;M]" true
    (letters = [ Fold_state.M; Fold_state.V; Fold_state.V ])

let test_fold_precrease_upgrade () =
  (* subdivide (F) then fold on the same axis: the F hinge toggles to angle 1
     (old #27 upgrade path) *)
  Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g0 = Fold_state.subdivide Fold_state.init_square ax ~prov:None in
  let g = vfold_new g0 ax in
  (* the upgraded hinge is folded and keeps its crease id 0 *)
  let hs = Fold_state.hinges g in
  let folded =
    Array.to_list hs |> List.filter (fun h -> Num.sign h.Fold_state.angle <> 0)
  in
  Alcotest.(check int) "one folded hinge" 1 (List.length folded);
  Alcotest.(check int) "kept id" 0 (List.hd folded).Fold_state.crease_id

let test_fold_scoped_parity () =
  (* two layers via a book fold, then a scoped fold of ONLY the top layer's
     free edge: fold the material LEFT of x=1/4 back to the right (move_side
     -1). The mover's only hinge to the stationary material is the book crease
     at table x=1/2 — on the stay side, so the scoped fold is hinge-closed
     (folding the x>1/4 side instead would tear at that hinge). *)
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax1 = { Geom.a = q 1; b = q 0; c = half } in
  let g1 = vfold_new Fold_state.init_square ax1 in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let ax2 = { Geom.a = q 1; b = q 0; c = quarter } in
  let top =
    (* face with the highest rank among those overlapping face 0 *)
    let n = Array.length (Fold_state.faces g1) in
    let best = ref 0 in
    for i = 1 to n - 1 do
      if Fold_state.rel g1 i !best = Fold_state.Above then best := i
    done;
    !best
  in
  match
    Fold_state.select_scope g1 ~axis:ax2 ~move_side:(-1) ~valley:true
      ~anchor:top ~target:(Fold_state.TargetFace top)
  with
  | Error e -> Alcotest.fail e
  | Ok moving ->
      let g = Fold_state.fold g1 ~axis:ax2 ~move_side:(-1) ~valley:true
          ~moving_parents:moving ~prov:None in
      Alcotest.(check int) "3 faces" 3 (Array.length (Fold_state.faces g));
      Alcotest.(check int) "moving = 1 face" 1
        (Array.to_list moving |> List.filter Fun.id |> List.length)

let test_fold_then_subdivide_parity () =
  (* subdivide with a TABLE-space axis on a state whose moved faces have
     det -1 placements *)
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax = { Geom.a = q 1; b = q 0; c = half } in
  let g1 = vfold_new Fold_state.init_square ax in
  let diag = { Geom.a = q 1; b = q 1; c = half } in  (* cuts both layers *)
  let g = Fold_state.subdivide g1 diag ~prov:None in
  Alcotest.(check int) "4 faces (both layers cut)" 4
    (Array.length (Fold_state.faces g))

(* --- Task 4 coverage: unfold toggle, root/base branches ------------------ *)

let test_fold_unfold_toggle () =
  (* book fold, then re-fold along the SAME axis moving only the top layer
     back: the on-axis hinge toggles 1 -> 0 (physical unfold) *)
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax = { Geom.a = q 1; b = q 0; c = half } in
  let g1 = Fold_state.fold Fold_state.init_square ~axis:ax ~move_side:1
      ~valley:true ~prov:None in
  (* find the folded hinge and its moved-side face (the face that is Above) *)
  let hs = Fold_state.hinges g1 in
  Alcotest.(check int) "one hinge" 1 (Array.length hs);
  let h = hs.(0) in
  Alcotest.(check bool) "folded" true (Num.sign h.Fold_state.angle <> 0);
  let top = if Fold_state.rel g1 h.Fold_state.fa h.Fold_state.fb = Fold_state.Above
            then h.Fold_state.fa else h.Fold_state.fb in
  let moving = Array.make (Array.length (Fold_state.faces g1)) false in
  moving.(top) <- true;
  (* the top layer's material lies on side -1 of the axis; folding it back *)
  let g2 = Fold_state.fold g1 ~axis:ax ~move_side:(-1) ~valley:true
      ~moving_parents:moving ~prov:None in
  let hs2 = Fold_state.hinges g2 in
  Alcotest.(check int) "still one hinge" 1 (Array.length hs2);
  Alcotest.(check bool) "unfolded: angle 0" true
    (Num.sign hs2.(0).Fold_state.angle = 0);
  Alcotest.(check bool) "derived mv is F" true
    (Fold_state.mv g2 0 = Fold_state.F);
  Alcotest.(check bool) "faces apart again" true
    (Fold_state.rel g2 0 1 = Fold_state.Apart);
  (* the sheet is the open unit square again: every table vertex in [0,1]^2 *)
  Array.iteri
    (fun i _ ->
      Alcotest.(check bool) (Printf.sprintf "face %d back on sheet" i) true
        (Array.for_all Geom.in_unit_square (Fold_state.table_polygon g2 i)))
    (Fold_state.faces g2)

(* A valley fold on a face-up sheet derives V, a mountain fold M; the letter
   is read from rank and orientation, never stored. *)
let test_fold_derived_letters () =
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax = { Geom.a = q 1; b = q 0; c = half } in
  let gv = Fold_state.fold Fold_state.init_square ~axis:ax ~move_side:1
      ~valley:true ~prov:None in
  Alcotest.(check bool) "valley derives V" true
    (Fold_state.mv gv 0 = Fold_state.V);
  Fold_state.reset_ids ();
  let gm = Fold_state.fold Fold_state.init_square ~axis:ax ~move_side:1
      ~valley:false ~prov:None in
  Alcotest.(check bool) "mountain derives M" true
    (Fold_state.mv gm 0 = Fold_state.M)

let test_fold_root_moves_parity () =
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax = { Geom.a = q 1; b = q 0; c = half } in
  let g0 = Fold_state.subdivide Fold_state.init_square ax ~prov:None in
  let root = Fold_state.root g0 in
  let moving = Array.make (Array.length (Fold_state.faces g0)) false in
  moving.(root) <- true;
  let mv_side =
    let p = (Fold_state.faces g0).(root).(0) in
    let s = Geom.side_of_line ax p in
    if s <> 0 then s
    else Geom.side_of_line ax (Fold_state.faces g0).(root).(2)
  in
  let g = Fold_state.fold g0 ~axis:ax ~move_side:mv_side ~valley:true
      ~moving_parents:moving ~prov:None in
  Alcotest.(check int) "2 faces" 2 (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "the fold's single hinge is V" true (Fold_state.mv g 0 = Fold_state.V)

let test_fold_nothing_stationary_parity () =
  (* whole-sheet fold across a boundary line: every face moves (branch 3) *)
  Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = q 1 } in  (* x = 1, right edge *)
  let g = Fold_state.fold Fold_state.init_square ~axis:ax ~move_side:(-1)
      ~valley:true ~prov:None in
  Alcotest.(check int) "1 face (whole sheet moved, no stationary child)" 1
    (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "reflected across x=1" true
    (Geom.point_equal (Fold_state.table_polygon g 0).(0) (gp 2 0))

(* --- Plan 3a Task 5: flip + add_mark -------------------------------------- *)

let test_flip_parity () =
  Fold_state.reset_ids ();
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g = Fold_state.flip (vfold_new Fold_state.init_square ax) in
  Alcotest.(check int) "2 faces" 2 (Array.length (Fold_state.faces g));
  (* flip doesn't change the derived letter (adjudicated — see
     test_flip_leaves_derived_assignment_unchanged in test_collapse.ml for the
     collapse-kernel analogue of this same finding) *)
  Alcotest.(check bool) "hinge 0 still V after flip" true (Fold_state.mv g 0 = Fold_state.V)

let test_fold_after_flip_parity () =
  (* spec §4.7: a fold after flip inverts the letter relative to the front *)
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let ax1 = { Geom.a = q 1; b = q 0; c = half } in
  let ax2 = { Geom.a = q 0; b = q 1; c = half } in
  let g = vfold_new (Fold_state.flip (vfold_new Fold_state.init_square ax1)) ax2 in
  Alcotest.(check int) "4 faces" 4 (Array.length (Fold_state.faces g));
  (* ax2 runs perpendicular to ax1 and cuts BOTH layers of the folded packet,
     so the original x=1/2 hinge splits into two pieces alongside the two new
     y=1/2 pieces — 4 hinges total *)
  let letters =
    Array.to_list (Fold_state.hinges g)
    |> List.mapi (fun i _ -> Fold_state.mv g i)
    |> List.sort compare
  in
  Alcotest.(check bool) "letters are [V;V;V;M]" true
    (letters = [ Fold_state.M; Fold_state.V; Fold_state.V; Fold_state.V ])

let test_flip_nontrivial_base_parity () =
  (* the final flip's base compose has a NON-identity right operand (the root
     carries the first flip's reflection), and its axis (x=3/8) differs from
     that reflection's axis (x=1/4): the two compose orders differ by a
     translation — the earlier flip tests cannot exercise this (their root
     placement is the identity). *)
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let ax1 = { Geom.a = q 1; b = q 0; c = half } in
  let ax2 = { Geom.a = q 1; b = q 0; c = quarter } in
  let g = Fold_state.flip
      (Fold_state.fold
         (Fold_state.flip (vfold_new Fold_state.init_square ax1))
         ~axis:ax2 ~move_side:(-1) ~valley:true ~prov:None) in
  Alcotest.(check int) "4 faces" 4 (Array.length (Fold_state.faces g));
  let letters =
    Array.to_list (Fold_state.hinges g)
    |> List.mapi (fun i _ -> Fold_state.mv g i)
    |> List.sort compare
  in
  Alcotest.(check bool) "letters are [V;V;M]" true
    (letters = [ Fold_state.M; Fold_state.V; Fold_state.V ]);
  (* sanity: the pre-flip root placement really is non-identity — the guard
     that makes this test order-sensitive; if this ever fails the test has
     silently degenerated to the order-insensitive case *)
  let pre =
    Fold_state.fold (Fold_state.flip (vfold_new Fold_state.init_square ax1))
      ~axis:ax2 ~move_side:(-1) ~valley:true ~prov:None
  in
  Alcotest.(check bool) "pre-flip root placement non-identity" false
    (Isometry3.equal (Fold_state.face_iso pre (Fold_state.root pre))
       Isometry3.identity)

(* --- Plan 3a Task 6: cross-op old-vs-new parity battery -------------------- *)

type battery_op =
  | OSub of Geom.line
  | OSubPaper of Geom.line
  | OFoldV of Geom.line * int
  | OFoldM of Geom.line * int
  | OFlip

let replay ops =
  Fold_state.reset_ids ();
  List.fold_left
    (fun g op ->
      match op with
      | OSub l -> Fold_state.subdivide g l ~prov:None
      | OSubPaper l -> Fold_state.subdivide_paper g l ~prov:None
      | OFoldV (l, s) -> Fold_state.fold g ~axis:l ~move_side:s ~valley:true ~prov:None
      | OFoldM (l, s) -> Fold_state.fold g ~axis:l ~move_side:s ~valley:false ~prov:None
      | OFlip -> Fold_state.flip g)
    Fold_state.init_square
    ops

let battery_frac a b = Num.div (Num.of_int a) (Num.of_int b)
let battery_vl c : Geom.line = { Geom.a = Num.one; b = Num.zero; c }
let battery_hl c : Geom.line = { Geom.a = Num.zero; b = Num.one; c }

(* This battery was a cross-op parity regression against the old model (Task
   6); the old model is gone (Plan 3c Task 6). Each scenario now asserts the
   concrete face count + derived letters the parity previously proved equal
   — pinned from a scratch run of the same op sequence (git history has the
   parity-checked provenance) — as a smoke-test that the op chain still
   produces the same shape. *)
let letters_of g =
  Array.to_list (Fold_state.hinges g)
  |> List.mapi (fun i _ -> Fold_state.mv g i)
  |> List.sort compare

let test_battery () =
  (* book fold + cross fold *)
  let g = replay [ OFoldV (battery_vl (battery_frac 1 2), 1);
                   OFoldV (battery_hl (battery_frac 1 2), 1) ] in
  Alcotest.(check int) "book+cross: 4 faces" 4 (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "book+cross: letters [V;V;M;V]" true
    (letters_of g = [ Fold_state.M; Fold_state.V; Fold_state.V; Fold_state.V ]);
  (* mountain pleat, three panels *)
  let g = replay [ OFoldV (battery_vl (battery_frac 2 3), 1);
                   OFoldM (battery_vl (battery_frac 1 3), 1) ] in
  Alcotest.(check int) "pleat3: 3 faces" 3 (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "pleat3: letters [V;M]" true
    (letters_of g = [ Fold_state.M; Fold_state.V ]);
  (* precrease both directions, then fold one of them *)
  let g = replay [ OSub (battery_vl (battery_frac 1 2));
                   OSub (battery_hl (battery_frac 1 2));
                   OFoldV (battery_vl (battery_frac 1 2), 1) ] in
  Alcotest.(check int) "precrease then fold: 4 faces" 4
    (Array.length (Fold_state.faces g));
  Alcotest.(check int) "precrease then fold: 2 folded hinges" 2
    (Array.to_list (Fold_state.hinges g)
     |> List.filter (fun h -> Num.sign h.Fold_state.angle <> 0)
     |> List.length);
  (* flip sandwich: fold, flip, fold, flip *)
  let g = replay [ OFoldV (battery_vl (battery_frac 1 2), 1);
                   OFlip;
                   OFoldV (battery_hl (battery_frac 1 2), 1);
                   OFlip ] in
  Alcotest.(check int) "flip sandwich: 4 faces" 4 (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "flip sandwich: letters [V;V;M;V]" true
    (letters_of g = [ Fold_state.M; Fold_state.V; Fold_state.V; Fold_state.V ]);
  (* paper-space mark graduation path: subdivide_paper on a folded state *)
  let g = replay [ OFoldV (battery_vl (battery_frac 1 2), 1);
                   OSubPaper (battery_hl (battery_frac 1 4)) ] in
  Alcotest.(check int) "subdivide_paper folded: 4 faces" 4
    (Array.length (Fold_state.faces g));
  (* diagonal on a folded packet *)
  let g = replay [ OFoldV (battery_vl (battery_frac 1 2), 1);
                   OFoldV ({ Geom.a = Num.one; b = Num.one; c = battery_frac 1 2 }, 1) ] in
  Alcotest.(check int) "diag on packet: 4 faces" 4 (Array.length (Fold_state.faces g));
  Alcotest.(check bool) "diag on packet: letters [V;V;M]" true
    (letters_of g = [ Fold_state.M; Fold_state.V; Fold_state.V ])

(* mark-then-fold: book fold, mark a segment on the STATIONARY region, fold
   again, then check the mark's current table axis is a line that actually
   passes through the mark's own current table position — self-consistency,
   in place of the old cross-model chord check. *)
let test_battery_mark_then_fold () =
  let half = battery_frac 1 2 in
  let quarter = battery_frac 1 4 in
  let seg_a = gph (q 0) quarter and seg_b = gph half quarter in
  let mnew =
    { Fold_state.mgeom = Fold_state.MSeg (seg_a, seg_b);
      mline = battery_hl quarter; mintent = Fold_state.V; mcrease_id = 99;
      mprov = None }
  in
  let ops = [ OFoldV (battery_vl half, 1) ] in
  let g = Fold_state.add_mark (replay ops) mnew in
  let g = Fold_state.fold g ~axis:(battery_hl half) ~move_side:1 ~valley:true ~prov:None in
  Alcotest.(check int) "4 faces" 4 (Array.length (Fold_state.faces g));
  let str = function `Line _ -> "line" | `Bent -> "bent" | `Empty -> "empty" | `Collapsed -> "collapsed" in
  Alcotest.(check string) "mark axis class" "line" (str (Fold_state.mark_axis_current g 99));
  (match Fold_state.mark_axis_current g 99 with
  | `Line l ->
      (* self-consistency: the reported axis must contain the mark's own two
         paper endpoints' CURRENT table positions (was checked against the
         old model's chords; the invariant is model-independent) *)
      Alcotest.(check int) "axis contains seg_a's table position" 0
        (Geom.side_of_line l (Fold_state.table_position g seg_a));
      Alcotest.(check int) "axis contains seg_b's table position" 0
        (Geom.side_of_line l (Fold_state.table_position g seg_b))
  | _ -> Alcotest.fail "expected `Line")

let test_add_mark () =
  let m =
    { Fold_state.mgeom = Fold_state.MSeg (gp 0 0, gp 1 1);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_state.V; mcrease_id = 9; mprov = None }
  in
  let g = Fold_state.add_mark Fold_state.init_square m in
  Alcotest.(check int) "one mark" 1 (Array.length (Fold_state.marks g));
  (* marks ride through a fold *)
  let ax = { Geom.a = q 1; b = q 0; c = Num.div Num.one (Num.of_int 2) } in
  let g' = Fold_state.fold g ~axis:ax ~move_side:1 ~valley:true ~prov:None in
  Alcotest.(check int) "mark carried" 1 (Array.length (Fold_state.marks g'))

(* mark_graduates: a corner-to-corner seg mark graduates immediately (both
   endpoints are already face-boundary vertices on the flat single-face
   sheet); an interior point mark never graduates. *)
let test_mark_graduates () =
  let corner_seg =
    { Fold_state.mgeom = Fold_state.MSeg (gp 0 0, gp 1 1);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_state.V; mcrease_id = 0; mprov = None }
  in
  Alcotest.(check bool) "corner-to-corner seg graduates immediately" true
    (Fold_state.mark_graduates Fold_state.init_square corner_seg);
  let half = Num.div (q 1) (q 2) in
  let interior_seg =
    { Fold_state.mgeom = Fold_state.MSeg (gp 0 0, gph half half);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_state.V; mcrease_id = 1; mprov = None }
  in
  Alcotest.(check bool) "seg ending mid-face does not graduate" false
    (Fold_state.mark_graduates Fold_state.init_square interior_seg);
  let point =
    { Fold_state.mgeom = Fold_state.MPoint (gp 0 0);
      mline = { Geom.a = q 1; b = q (-1); c = q 0 };
      mintent = Fold_state.V; mcrease_id = 2; mprov = None }
  in
  Alcotest.(check bool) "point marks never graduate" false
    (Fold_state.mark_graduates Fold_state.init_square point)

(* --- Plan 3b Task 1: crease queries --------------------------------------- *)

(* build a precrease + fold state (was matched old/new states) *)
let pair_precrease_fold () =
  Fold_state.reset_ids ();
  let half = Num.div Num.one (Num.of_int 2) in
  let vhalf = { Geom.a = q 1; b = q 0; c = half } in
  let hhalf = { Geom.a = q 0; b = q 1; c = half } in
  Fold_state.fold
    (Fold_state.subdivide Fold_state.init_square hhalf ~prov:None)
    ~axis:vhalf ~move_side:1 ~valley:true ~prov:None

(* Was a parity test against the old model (Plan 3b Task 1); the old model is
   gone (Plan 3c Task 6). Asserts the concrete crease ids/segment counts the
   parity previously proved equal — pinned from a scratch run of this exact
   construction (git history has the parity-checked provenance). *)
let test_crease_segments_parity () =
  let g = pair_precrease_fold () in
  let ids = List.sort compare (Fold_state.all_crease_ids g) in
  Alcotest.(check (list int)) "crease ids" [ 0; 1 ] ids;
  List.iter
    (fun cid ->
      Alcotest.(check int) (Printf.sprintf "cid %d has 2 segments" cid) 2
        (List.length (Fold_state.crease_segments g cid)))
    ids

let test_crease_axes_parity () =
  let g = pair_precrease_fold () in
  let string_of = function `Line _ -> "line" | `Bent -> "bent" | `Empty -> "empty" | `Collapsed -> "collapsed" in
  List.iter
    (fun cid ->
      (* probe with a line unrelated to the crease, so a `Line result is
         reconstructed from the actual segment endpoints, not echoed back *)
      let n = Fold_state.crease_axis g cid { Geom.a = q 1; b = q 0; c = q 0 } in
      Alcotest.(check string) (Printf.sprintf "axis class cid %d" cid) "line"
        (string_of n);
      (* self-consistency: the reconstructed line must contain every one of
         the crease's OWN segment table endpoints (was checked against the
         old model's endpoints; the invariant is model-independent) *)
      (match n with
      | `Line nl ->
          List.iter
            (fun (s : Fold_state.crease_segment) ->
              Alcotest.(check int)
                (Printf.sprintf "axis line contains own table endpoint, cid %d" cid)
                0 (Geom.side_of_line nl s.Fold_state.ta);
              Alcotest.(check int)
                (Printf.sprintf "axis line contains own table endpoint, cid %d" cid)
                0 (Geom.side_of_line nl s.Fold_state.tb))
            (Fold_state.crease_segments g cid)
      | _ -> ());
      let np = Fold_state.crease_paper_axis g cid in
      Alcotest.(check string) (Printf.sprintf "paper axis class cid %d" cid) "line"
        (string_of np))
    (List.sort compare (Fold_state.all_crease_ids g))

let test_boundary_segments_parity () =
  let g = pair_precrease_fold () in
  (* the sheet's bottom edge y = 0 *)
  let bottom = { Geom.a = q 0; b = q 1; c = q 0 } in
  let segs = Fold_state.edge_boundary_segments g bottom in
  Alcotest.(check int) "boundary y=0: 2 segments" 2 (List.length segs);
  List.iter
    (fun (s : Fold_state.crease_segment) ->
      Alcotest.(check bool) "boundary segment lies on y=0" true
        (Num.sign s.Fold_state.ta.Geom.y = 0 && Num.sign s.Fold_state.tb.Geom.y = 0))
    segs

let test_neighbors_hinge_between () =
  let g = pair_precrease_fold () in
  let n = Array.length (Fold_state.faces g) in
  (* every hinge appears in both endpoints' neighbor lists, and
     hinge_between finds it from its segment *)
  Array.iteri
    (fun i (h : Fold_state.hinge) ->
      Alcotest.(check bool) (Printf.sprintf "nb fa %d" i) true
        (List.mem h.Fold_state.fb (Fold_state.neighbors g h.Fold_state.fa));
      let a, b = Fold_state.hinge_segment g i in
      match Fold_state.hinge_between g h.Fold_state.fa a b with
      | Some j -> Alcotest.(check int) (Printf.sprintf "hb %d" i) i j
      | None -> Alcotest.failf "hinge_between missed hinge %d" i)
    (Fold_state.hinges g);
  ignore n

(* --- Plan 3b Task 2: clusters/flaps ---------------------------------------- *)

(* Was a parity test against the old model (Plan 3b Task 2); the old model is
   gone (Plan 3c Task 6). The partition it proved equal, pinned from a
   scratch run: faces 0,1 (the unmoved bottom-ish faces) cluster together,
   faces 2,3 (the moved ones) cluster together, and the two groups differ. *)
let test_clusters_parity () =
  let g = pair_precrease_fold () in
  let cn = Fold_state.coplanar_clusters g in
  Alcotest.(check int) "4 faces" 4 (Array.length cn);
  Alcotest.(check bool) "0,1 same cluster" true (cn.(0) = cn.(1));
  Alcotest.(check bool) "2,3 same cluster" true (cn.(2) = cn.(3));
  Alcotest.(check bool) "the two clusters differ" true (cn.(0) <> cn.(2))

let test_flap_of_points_parity () =
  let g = pair_precrease_fold () in
  let string_of = function
    | `Cluster fs -> "cluster:" ^ String.concat "," (List.map string_of_int (List.sort compare fs))
    | `Zero -> "zero"
    | `Ambiguous -> "ambiguous"
  in
  let probe pts expect label =
    Alcotest.(check string) label expect (string_of (Fold_state.flap_of_points g pts))
  in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let three_q = Num.div (Num.of_int 3) (Num.of_int 4) in
  probe [ { Geom.x = quarter; y = quarter } ] "cluster:0,1" "interior stationary";
  probe [ { Geom.x = three_q; y = quarter } ] "cluster:2,3" "interior moved flap";
  probe [ { Geom.x = quarter; y = quarter }; { Geom.x = three_q; y = quarter } ]
    "zero" "spanning two flaps";
  probe [ { Geom.x = q 5; y = q 5 } ] "zero" "off paper"

(* ambiguous-branch probe (carried minor from Task 2): a point exactly on the
   shared paper-space boundary between the stationary and moved clusters of
   pair_precrease_fold's BL/BR faces belongs to both -> Ambiguous. *)
let test_flap_of_points_ambiguous () =
  let g = pair_precrease_fold () in
  let string_of = function
    | `Cluster fs ->
        "cluster:" ^ String.concat "," (List.map string_of_int (List.sort compare fs))
    | `Zero -> "zero"
    | `Ambiguous -> "ambiguous"
  in
  let half = Num.div Num.one (Num.of_int 2) in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let p = { Geom.x = half; y = quarter } in
  Alcotest.(check string) "boundary point is Ambiguous" "ambiguous"
    (string_of (Fold_state.flap_of_points g [ p ]))

(* --- Plan 3b Task 3: line material + scope ---------------------------------- *)

let test_line_material_parity () =
  let g = pair_precrease_fold () in
  let l = { Geom.a = q 0; b = q 1; c = Num.div Num.one (Num.of_int 4) } in
  Alcotest.(check int) "2 material segments" 2
    (List.length (Fold_state.line_material_segments g l));
  Alcotest.(check bool) "line cuts the paper" true (Fold_state.line_cuts_paper g l)

(* select_scope parity on a 3-layer state (pleat then check scoping) *)
(* Was a parity test against the old model (Plan 3b Task 3); the old model is
   gone (Plan 3c Task 6). The moving-set result it proved equal, pinned from
   a scratch run of this construction (git history has the parity-checked
   provenance), is asserted directly. *)
let test_select_scope_parity () =
  Fold_state.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  (* book fold then fold the packet edge back: 3 overlapping layers on part
     of the sheet *)
  let g = Fold_state.fold
      (vfold_new Fold_state.init_square (vl (frac 1 2)))
      ~axis:(vl (frac 1 4)) ~move_side:(-1) ~valley:true ~prov:None in
  (* the top face over x in (1/4,1/2): this construction leaves all 4 faces
     spanning EXACTLY [1/4,1/2] on the table (a book fold's two layers have
     identical footprints, and cutting both again at 1/4 folds each one's
     [0,1/4] piece exactly onto [1/4,1/2] too — verified: every face's table
     polygon has vertices ONLY at x=1/4 and x=1/2, none strictly between).
     The brief's vertex-based candidacy check (a vertex strictly inside the
     open interval) therefore never matches ANY face and always yields
     anchor=-1 — a test-construction bug, not a parity divergence (both
     models crash identically on the out-of-range anchor). Judge candidacy
     by positive-area overlap with the open strip instead: all 4 faces
     qualify here, so this reduces to "the highest-ranked face", but stays
     correct for a genuinely partial-overlap construction too. *)
  let top =
    let n = Array.length (Fold_state.faces g) in
    let strip_lo = { Geom.a = q 1; b = q 0; c = frac 1 4 } in
    let strip_hi = { Geom.a = q 1; b = q 0; c = frac 1 2 } in
    let has_material i =
      let tp = Fold_state.table_polygon g i in
      let c1 = Geom.clip_convex_halfplane strip_lo 1 tp in
      Array.length c1 >= 3
      && Array.length (Geom.clip_convex_halfplane strip_hi (-1) c1) >= 3
    in
    let best = ref (-1) in
    for i = 0 to n - 1 do
      if has_material i then
        if !best < 0 || Fold_state.rel g i !best = Fold_state.Above then best := i
    done;
    !best
  in
  let axis = vl (frac 3 8) in
  match Fold_state.select_scope g ~axis ~move_side:(-1) ~valley:true
      ~anchor:top ~target:(Fold_state.TargetFace top) with
  | Ok m -> Alcotest.(check (array bool)) "moving set" [| false; false; false; true |] m
  | Error e -> Alcotest.failf "expected Ok, got: %s" e

(* Plan 3c Task 1: TargetHinged select_scope (frontier BFS + predicate — the
   `up to <named crease>` machinery). Reuses test_select_scope_parity's
   3-layer pleat construction verbatim: book fold (axis 1/2, move_side 1)
   then a second fold at axis 1/4, move_side -1, leaving 3 overlapping
   layers. cid 0 is the book fold's crease, so the predicate below asks "is
   this face hinged on the book-fold crease", built from crease_segments.
   Axis 3/8 (same as the TargetFace test): the anchor (face 3) is not itself
   hinged on cid 0, so the `pred anchor` short-circuit is skipped and the
   frontier loop runs; the hinged faces 0/1 are hits in the FIRST frontier
   round (the visited-expansion multi-round branch remains uncovered here;
   end-to-end up-to cases cover it in 3c Task 4). An Ok case, as required. A
   second call with an unsatisfiable predicate then exercises the
   frontier-exhausted error path. Was a parity test against the old model;
   the moving-set/error-string results it proved equal are now asserted
   directly, pinned from a scratch run (git history has the provenance). *)
let test_select_scope_target_hinged_parity () =
  Fold_state.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  let g = Fold_state.fold
      (vfold_new Fold_state.init_square (vl (frac 1 2)))
      ~axis:(vl (frac 1 4)) ~move_side:(-1) ~valley:true ~prov:None in
  let top =
    let n = Array.length (Fold_state.faces g) in
    let strip_lo = { Geom.a = q 1; b = q 0; c = frac 1 4 } in
    let strip_hi = { Geom.a = q 1; b = q 0; c = frac 1 2 } in
    let has_material i =
      let tp = Fold_state.table_polygon g i in
      let c1 = Geom.clip_convex_halfplane strip_lo 1 tp in
      Array.length c1 >= 3
      && Array.length (Geom.clip_convex_halfplane strip_hi (-1) c1) >= 3
    in
    let best = ref (-1) in
    for i = 0 to n - 1 do
      if has_material i then
        if !best < 0 || Fold_state.rel g i !best = Fold_state.Above then best := i
    done;
    !best
  in
  let cid = 0 in
  let pred fi =
    Fold_state.crease_segments g cid
    |> List.exists (fun (s : Fold_state.crease_segment) ->
        fst s.faces = fi || snd s.faces = fi)
  in
  let axis = vl (frac 3 8) in
  (match Fold_state.select_scope g ~axis ~move_side:(-1) ~valley:true
      ~anchor:top ~target:(Fold_state.TargetHinged pred) with
  | Ok m -> Alcotest.(check (array bool)) "moving set" [| true; true; true; true |] m
  | Error e -> Alcotest.failf "expected Ok, got: %s" e);
  (* error path: a predicate no face satisfies must exhaust the frontier *)
  let never _ = false in
  match Fold_state.select_scope g ~axis ~move_side:(-1) ~valley:true
      ~anchor:top ~target:(Fold_state.TargetHinged never) with
  | Error e ->
      let contains hay needle =
        let nh = String.length hay and nn = String.length needle in
        let rec go i = i + nn <= nh && (String.sub hay i nn = needle || go (i + 1)) in
        go 0
      in
      Alcotest.(check bool) "unsatisfiable pred: no-flap-hinged message" true
        (contains e "no flap hinged")
  | Ok _ -> Alcotest.fail "expected Error for unsatisfiable predicate"

(* Was a parity test against the old model (Plan 3b Task 3); the old model is
   gone (Plan 3c Task 6). Both branches' Ok/Error outcome is now asserted
   directly. *)
let test_scoped_hinge_closed_parity () =
  Fold_state.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  let g = vfold_new Fold_state.init_square (vl (frac 1 2)) in
  let top = if Fold_state.rel g 0 1 = Fold_state.Above then 0 else 1 in
  let moving = Array.make 2 false in
  moving.(top) <- true;
  (* legal: axis through the mover's free region *)
  let ok = Fold_state.scoped_fold_hinge_closed g ~axis:(vl (frac 1 4))
      ~move_side:(-1) ~moving_parents:moving in
  Alcotest.(check bool) "legal" true (Result.is_ok ok);
  (* tear: moving the +1 side lifts the mover off its book hinge *)
  let bad = Fold_state.scoped_fold_hinge_closed g ~axis:(vl (frac 1 4))
      ~move_side:1 ~moving_parents:moving in
  Alcotest.(check bool) "tear" true (Result.is_error bad)

(* 3a carry-in: on-axis hinge with BOTH sides moving must NOT toggle (D8);
   old model upgraded eassign here — accepted divergence, so assert the NEW
   behaviour directly, no parity. Corrected book-fold construction (see
   task-3-brief.md correction note — the original 4-face sketch does not
   actually reach both-sides-moving). *)
let test_both_sides_moving_no_toggle () =
  Fold_state.reset_ids ();
  let frac a b = Num.div (Num.of_int a) (Num.of_int b) in
  let vl c = { Geom.a = Num.one; b = Num.zero; c } in
  let g1 = vfold_new Fold_state.init_square (vl (frac 1 2)) in
  let movers = Array.make (Array.length (Fold_state.faces g1)) true in
  let g = Fold_state.fold g1 ~axis:(vl (frac 1 2)) ~move_side:(-1)
      ~valley:true ~moving_parents:movers ~prov:None in
  let hs = Fold_state.hinges g in
  Alcotest.(check int) "one hinge" 1 (Array.length hs);
  Alcotest.(check bool) "still folded (no toggle)" true
    (Num.sign hs.(0).Fold_state.angle <> 0);
  Array.iteri
    (fun i _ ->
      Alcotest.(check bool) (Printf.sprintf "face %d at x>=1/2" i) true
        (Array.for_all
           (fun (p : Geom.point) -> Num.compare p.Geom.x (frac 1 2) >= 0)
           (Fold_state.table_polygon g i)))
    (Fold_state.faces g)

(* --- Plan 3b Task 4: marks -------------------------------------------------- *)

let mclass_str = function
  | `Sub -> "subdivide" | `Rec -> "record" | `Cross -> "crossesfold"

(* Was a parity test against the old model (Plan 3b Task 4); the old model is
   gone (Plan 3c Task 6). Each case's classification, pinned from a scratch
   run (git history has the parity-checked provenance), is asserted
   directly. *)
let test_classify_parity () =
  let g = pair_precrease_fold () in
  (* flap = the moved packet cluster: probe from a point on it *)
  let three_q = Num.div (Num.of_int 3) (Num.of_int 4) in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let flap =
    match Fold_state.flap_of_points g [ { Geom.x = three_q; y = quarter } ] with
    | `Cluster fs -> fs | _ -> Alcotest.fail "flap"
  in
  let case label axis geom expect =
    let simplify = function
      | Fold_state.CSubdivide _ -> `Sub
      | Fold_state.CRecord _ -> `Rec
      | Fold_state.CCrossesFold _ -> `Cross
    in
    Alcotest.(check string) label (mclass_str expect)
      (mclass_str (simplify (Fold_state.classify_mark_extent g ~flap ~axis ~extent_geom:geom)))
  in
  (* full chord across the moved packet: subdivide *)
  let a = { Geom.x = Num.div Num.one (Num.of_int 2); y = quarter }
  and b = { Geom.x = Num.one; y = quarter } in
  case "full chord" { Geom.a = q 0; b = q 1; c = quarter } (Fold_state.MSeg (a, b)) `Sub;
  (* stub ending mid-face: record *)
  let mid = { Geom.x = three_q; y = quarter } in
  case "stub" { Geom.a = q 0; b = q 1; c = quarter } (Fold_state.MSeg (a, mid)) `Rec;
  (* point: record *)
  case "point" { Geom.a = q 0; b = q 1; c = quarter } (Fold_state.MPoint mid) `Rec

(* Was a parity test against the old model (Plan 3b Task 4); the old model is
   gone (Plan 3c Task 6). The mark's two paper endpoints happen to map to the
   SAME table point on this fixture (the book fold at x=1/2 reflects x=1 onto
   x=0, and both endpoints sit at y=1/4), so the mark has a chord but it has
   folded onto a single point: [mark_axis_current] reports `Collapsed (a
   present-but-degenerate mark, distinct from `Empty's nothing-to-name). *)
let test_mark_axis_current_parity () =
  let g = pair_precrease_fold () in
  let quarter = Num.div Num.one (Num.of_int 4) in
  let mnew = { Fold_state.mgeom = Fold_state.MSeg
                  ({ Geom.x = q 0; y = quarter }, { Geom.x = q 1; y = quarter });
               mline = { Geom.a = q 0; b = q 1; c = quarter };
               mintent = Fold_state.V; mcrease_id = 77; mprov = None } in
  let g = Fold_state.add_mark g mnew in
  let str = function `Line _ -> "line" | `Bent -> "bent" | `Empty -> "empty" | `Collapsed -> "collapsed" in
  Alcotest.(check string) "mark axis class" "collapsed" (str (Fold_state.mark_axis_current g 77))

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
          Alcotest.test_case "fresh ids" `Quick test_fresh_ids;
          Alcotest.test_case "next-id-roundtrip" `Quick
            test_next_id_roundtrip ] );
      ( "task2-2d-access",
        [ Alcotest.test_case "face_iso2" `Quick test_face_iso2;
          Alcotest.test_case "table polygon and rel" `Quick
            test_table_polygon_and_rel;
          Alcotest.test_case "hinge segments" `Quick test_hinge_segments;
          Alcotest.test_case "point queries" `Quick test_point_queries ] );
      ( "task3-subdivide",
        [ Alcotest.test_case "subdivide parity" `Quick test_subdivide_parity;
          Alcotest.test_case "subdivide_paper parity" `Quick
            test_subdivide_paper_parity;
          Alcotest.test_case "carried split parity" `Quick
            test_subdivide_carried_split;
          Alcotest.test_case "keep_side parity" `Quick
            test_subdivide_keep_side ] );
      ( "task4-fold",
        [ Alcotest.test_case "single fold parity" `Quick test_fold_parity_single;
          Alcotest.test_case "mountain parity" `Quick test_fold_parity_mountain;
          Alcotest.test_case "pleat parity" `Quick test_fold_parity_pleat;
          Alcotest.test_case "precrease upgrade parity" `Quick
            test_fold_precrease_upgrade;
          Alcotest.test_case "scoped fold parity" `Quick test_fold_scoped_parity;
          Alcotest.test_case "fold then subdivide parity" `Quick
            test_fold_then_subdivide_parity ] );
      ( "task4-coverage",
        [ Alcotest.test_case "unfold toggle" `Quick test_fold_unfold_toggle;
          Alcotest.test_case "derived letters" `Quick test_fold_derived_letters;
          Alcotest.test_case "root moves parity" `Quick
            test_fold_root_moves_parity;
          Alcotest.test_case "nothing stationary parity" `Quick
            test_fold_nothing_stationary_parity ] );
      ( "task5-flip",
        [ Alcotest.test_case "flip parity" `Quick test_flip_parity;
          Alcotest.test_case "fold after flip parity" `Quick
            test_fold_after_flip_parity;
          Alcotest.test_case "flip nontrivial base parity" `Quick
            test_flip_nontrivial_base_parity;
          Alcotest.test_case "add_mark" `Quick test_add_mark;
          Alcotest.test_case "mark_graduates" `Quick test_mark_graduates ] );
      ( "task6-parity-battery",
        [ Alcotest.test_case "cross-op battery" `Quick test_battery;
          Alcotest.test_case "mark then fold then mark_axis_current" `Quick
            test_battery_mark_then_fold ] );
      ( "plan3b-task1-selectors",
        [ Alcotest.test_case "crease segments parity" `Quick
            test_crease_segments_parity;
          Alcotest.test_case "crease axes parity" `Quick
            test_crease_axes_parity;
          Alcotest.test_case "boundary segments parity" `Quick
            test_boundary_segments_parity;
          Alcotest.test_case "neighbors and hinge_between" `Quick
            test_neighbors_hinge_between ] );
      ( "plan3b-task2-clusters",
        [ Alcotest.test_case "coplanar clusters parity" `Quick
            test_clusters_parity;
          Alcotest.test_case "flap_of_points parity" `Quick
            test_flap_of_points_parity;
          Alcotest.test_case "flap_of_points ambiguous branch" `Quick
            test_flap_of_points_ambiguous ] );
      ( "plan3b-task3-scope",
        [ Alcotest.test_case "line material parity" `Quick
            test_line_material_parity;
          Alcotest.test_case "select_scope parity" `Quick
            test_select_scope_parity;
          Alcotest.test_case "scoped hinge closed parity" `Quick
            test_scoped_hinge_closed_parity;
          Alcotest.test_case "both sides moving no toggle" `Quick
            test_both_sides_moving_no_toggle;
          Alcotest.test_case "default_scope" `Quick test_default_scope ] );
      ( "plan3b-task4-marks",
        [ Alcotest.test_case "classify_mark_extent parity" `Quick
            test_classify_parity;
          Alcotest.test_case "mark_axis_current parity" `Quick
            test_mark_axis_current_parity ] );
      ( "plan3c-task1-target-hinged",
        [ Alcotest.test_case "TargetHinged select_scope parity" `Quick
            test_select_scope_target_hinged_parity ] )
    ]
