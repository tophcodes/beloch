open Beloch

let test_error_roundtrip () =
  let pos = { Lexing.pos_fname = "x.bel"; pos_lnum = 3; pos_bol = 10; pos_cnum = 14 } in
  Alcotest.(check string) "span format" "x.bel:3:5" (Beloch.Error.span_to_string (pos, pos))

let q = Q.of_int
let pt x y = { Geom.x = q x; y = q y }

let test_diagonals_intersect_center () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 1) in
  let l2 = Geom.line_through (pt 1 0) (pt 0 1) in
  match Geom.intersection l1 l2 with
  | Some p ->
      Alcotest.(check bool) "center is (1/2,1/2)" true
        (Geom.point_equal p { Geom.x = Q.of_ints 1 2; y = Q.of_ints 1 2 })
  | None -> Alcotest.fail "expected an intersection"

let test_bisector_of_bottom_edge () =
  (* perpendicular bisector of a=(0,0) and b=(1,0) is the vertical line x=1/2 *)
  let l = Geom.perpendicular_bisector (pt 0 0) (pt 1 0) in
  let on p = Q.equal (Q.add (Q.mul l.Geom.a p.Geom.x) (Q.mul l.Geom.b p.Geom.y)) l.Geom.c in
  Alcotest.(check bool) "(1/2,0) on bisector" true (on { Geom.x = Q.of_ints 1 2; y = q 0 });
  Alcotest.(check bool) "(1/2,1) on bisector" true (on { Geom.x = Q.of_ints 1 2; y = q 1 })

let test_parallel_lines () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 1) (pt 1 1) in
  Alcotest.(check bool) "parallel" true (Geom.parallel l1 l2);
  (match Geom.intersection l1 l2 with None -> () | Some _ -> Alcotest.fail "expected none")

let test_in_unit_square () =
  Alcotest.(check bool) "center inside" true (Geom.in_unit_square (pt 0 0));
  Alcotest.(check bool) "corner inside (boundary)" true
    (Geom.in_unit_square { Geom.x = Q.of_ints 1 2; y = Q.of_ints 1 2 });
  Alcotest.(check bool) "outside" false (Geom.in_unit_square (pt 2 2))

let () =
  Alcotest.run "beloch"
    [ ("error", [ Alcotest.test_case "span format" `Quick test_error_roundtrip ]);
      ("geom",
       [ Alcotest.test_case "diagonals meet at center" `Quick test_diagonals_intersect_center;
         Alcotest.test_case "perpendicular bisector" `Quick test_bisector_of_bottom_edge;
         Alcotest.test_case "parallel lines" `Quick test_parallel_lines;
         Alcotest.test_case "point in unit square" `Quick test_in_unit_square ]) ]
