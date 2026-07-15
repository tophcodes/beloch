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

let mk ?(root = 0) ~faces ~hinges ~rank () =
  match Fold_graph.make ~faces ~hinges ~root ~rank with
  | Ok g -> g
  | Error v -> Alcotest.failf "expected Ok, got: %s" (Fold_graph.violation_to_string v)

let expect_error label pred ~faces ~hinges ~root ~rank =
  match Fold_graph.make ~faces ~hinges ~root ~rank with
  | Ok _ -> Alcotest.fail (label ^ ": expected a violation, got Ok")
  | Error v ->
      Alcotest.(check bool)
        (label ^ ": " ^ Fold_graph.violation_to_string v)
        true (pred v)

(* strip of unit squares [k,k+1]x[0,1] *)
let strip_face k w = sq (gp k 0) (gp (k + w) 0) (gp (k + w) 1) (gp k 1)

(* SINGLE FOLD: square split at x=1; face1 folded across x=1 onto face0. *)
let single_fold_faces () = [| strip_face 0 1; strip_face 1 1 |]
let single_fold_hinges () =
  [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 } |]

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
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
       { Fold_graph.fa = 1; fb = 2; line = vline 2; angle = q 1 } |]
  in
  let g = mk ~faces ~hinges ~rank:[| 0; 1; 2 |] () in
  let isos = Fold_graph.face_isos g in
  let half = Num.of_q (Q.of_ints 1 2) in
  Alcotest.(check bool) "face2 folds back to x=1/2" true
    (i3eq
       (Isometry3.apply_point isos.(2)
          { Isometry3.x = Num.of_q (Q.of_ints 5 2); y = half; z = q 0 })
       { Isometry3.x = half; y = half; z = q 0 })

let test_rejects_bad_angle () =
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = Num.of_q (Q.of_ints 1 2) } |]
  in
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
    ~hinges:[| { Fold_graph.fa = 0; fb = 5; line = vline 1; angle = q 1 } |]
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
    [| { Fold_graph.fa = 0; fb = 1;
         line = { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 1 2) };
         angle = q 1 } |]
  in
  expect_error "line cuts a face"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces:(single_fold_faces ()) ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_gap () =
  (* faces [0,1]² and [2,3]²: opposite sides of x=3/2, but no shared edge *)
  let faces = [| strip_face 0 1; strip_face 2 1 |] in
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1;
         line = { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 3 2) };
         angle = q 1 } |]
  in
  expect_error "faces do not touch the line"
    (function Fold_graph.Hinge_not_shared 0 -> true | _ -> false)
    ~faces ~hinges ~root:0 ~rank:[| 0; 1 |]

let test_rejects_hinge_vertex_touch () =
  (* [0,1]² and [1,2]×[1,2] share only the corner (1,1) on line x=1 *)
  let faces =
    [| strip_face 0 1; sq (gp 1 1) (gp 2 1) (gp 2 2) (gp 1 2) |]
  in
  let hinges =
    [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 } |]
  in
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
  [| { Fold_graph.fa = 0; fb = 1; line = vline 1; angle = q 1 };
     { Fold_graph.fa = 1; fb = 2; line = hline 1; angle = q 1 };
     { Fold_graph.fa = 2; fb = 3; line = vline 1; angle = q 1 };
     { Fold_graph.fa = 3; fb = 0; line = hline 1; angle = last_angle } |]

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

let () =
  Alcotest.run "fold_graph"
    [ ( "derive",
        [ Alcotest.test_case "single fold" `Quick test_single_fold;
          Alcotest.test_case "accordion path" `Quick test_accordion ] );
      ( "make-structure",
        [ Alcotest.test_case "bad angle" `Quick test_rejects_bad_angle;
          Alcotest.test_case "bad rank" `Quick test_rejects_bad_rank;
          Alcotest.test_case "bad index" `Quick test_rejects_bad_index;
          Alcotest.test_case "disconnected" `Quick test_rejects_disconnected ] );
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
            test_cycle_tear_rejected ] ) ]
