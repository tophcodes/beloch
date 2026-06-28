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

let test_clip_diagonal () =
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  match Geom.clip_to_unit_square l with
  | Some (p, q) ->
      let has a = Geom.point_equal p a || Geom.point_equal q a in
      Alcotest.(check bool) "endpoints are the two corners" true (has (pt 0 0) && has (pt 1 1))
  | None -> Alcotest.fail "diagonal should clip to a segment"

let test_segment_intersection_center () =
  let s1 = (pt 0 0, pt 1 1) in
  let s2 = (pt 1 0, pt 0 1) in
  match Geom.segment_intersection s1 s2 with
  | Some p ->
      Alcotest.(check bool) "cross at center" true
        (Geom.point_equal p { Geom.x = Q.of_ints 1 2; y = Q.of_ints 1 2 })
  | None -> Alcotest.fail "segments cross at center"

let test_segment_no_touch () =
  (* two boundary edges that share no interior point: bottom and top *)
  let s1 = (pt 0 0, pt 1 0) in
  let s2 = (pt 0 1, pt 1 1) in
  (match Geom.segment_intersection s1 s2 with
   | None -> ()
   | Some _ -> Alcotest.fail "parallel edges must not intersect")

let test_parse_named_and_anon () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d1: through .a .c\nfold .b to .d\n.center: cross --d1 --d2\n"
  in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [ Ast.Crease (Some "d1", Ast.Through _, _);
      Ast.Crease (None, Ast.FoldOnto _, _);
      Ast.Point ("center", Ast.Cross _, _) ] -> ()
  | _ -> Alcotest.fail "unexpected AST shape"

let test_parse_syntax_error () =
  try
    ignore (Beloch.parse ~filename:"t.bel" "paper square\nfold .a\n");
    Alcotest.fail "expected a syntax error"
  with Error.Beloch_error (_, _) -> ()

let test_vertex_dedup () =
  let st = State.create () in
  let i = State.add_vertex st (pt 0 0) in
  let j = State.add_vertex st (pt 1 1) in
  let k = State.add_vertex st (pt 0 0) in
  Alcotest.(check int) "first index 0" 0 i;
  Alcotest.(check int) "second index 1" 1 j;
  Alcotest.(check int) "dup returns 0" 0 k;
  Alcotest.(check int) "two vertices total" 2 (Dynarray.length st.State.verts)

let eval_src s = Eval.eval (Beloch.parse ~filename:"t.bel" s)

let expect_error msg_substr thunk =
  try
    ignore (thunk ());
    Alcotest.fail ("expected error containing: " ^ msg_substr)
  with Error.Beloch_error (_, m) ->
    Alcotest.(check bool) ("error mentions " ^ msg_substr) true
      (try ignore (Str.search_forward (Str.regexp_string msg_substr) m 0); true
       with Not_found -> false)

let test_eval_counts_creases () =
  let cs = eval_src "paper square\n--d1: through .a .c\nfold .b to .d\n" in
  Alcotest.(check int) "two creases" 2 (List.length cs)

let test_eval_cross_ok () =
  let cs =
    eval_src "paper square\n--d1: through .a .c\n--d2: through .b .d\n.m: cross --d1 --d2\nfold .a to .m\n"
  in
  Alcotest.(check int) "three creases" 3 (List.length cs)

let test_eval_identical_points () =
  expect_error "distinct" (fun () -> eval_src "paper square\nthrough .a .a\n")

let test_eval_undefined_point () =
  expect_error "undefined" (fun () -> eval_src "paper square\nfold .a to .z\n")

let test_eval_parallel_cross () =
  expect_error "parallel"
    (fun () -> eval_src "paper square\n--h1: through .a .b\n--h2: through .d .c\n.x: cross --h1 --h2\n")

let test_planarize_two_diagonals () =
  let cs = eval_src "paper square\nthrough .a .c\nthrough .b .d\n" in
  let st = Planarize.run cs in
  (* 4 corners + center = 5 vertices *)
  Alcotest.(check int) "five vertices" 5 (Dynarray.length st.State.verts);
  (* 4 boundary edges + each diagonal split into 2 = 4 crease edges = 8 *)
  Alcotest.(check int) "eight edges" 8 (Dynarray.length st.State.edges);
  let boundary =
    Dynarray.fold_left
      (fun acc e -> if e.State.assign = State.Boundary then acc + 1 else acc)
      0 st.State.edges
  in
  Alcotest.(check int) "four boundary edges" 4 boundary

let test_planarize_single_crease () =
  let cs = eval_src "paper square\nthrough .a .c\n" in
  let st = Planarize.run cs in
  Alcotest.(check int) "four corners" 4 (Dynarray.length st.State.verts);
  Alcotest.(check int) "4 boundary + 1 crease" 5 (Dynarray.length st.State.edges)

let () =
  Alcotest.run "beloch"
    [ ("error", [ Alcotest.test_case "span format" `Quick test_error_roundtrip ]);
      ("geom",
       [ Alcotest.test_case "diagonals meet at center" `Quick test_diagonals_intersect_center;
         Alcotest.test_case "perpendicular bisector" `Quick test_bisector_of_bottom_edge;
         Alcotest.test_case "parallel lines" `Quick test_parallel_lines;
         Alcotest.test_case "point in unit square" `Quick test_in_unit_square;
         Alcotest.test_case "clip diagonal" `Quick test_clip_diagonal;
         Alcotest.test_case "segment intersection" `Quick test_segment_intersection_center;
         Alcotest.test_case "segments do not touch" `Quick test_segment_no_touch ]);
      ("parse",
       [ Alcotest.test_case "named and anonymous" `Quick test_parse_named_and_anon;
         Alcotest.test_case "syntax error" `Quick test_parse_syntax_error ]);
      ("state", [ Alcotest.test_case "vertex dedup" `Quick test_vertex_dedup ]);
      ("eval",
       [ Alcotest.test_case "count creases" `Quick test_eval_counts_creases;
         Alcotest.test_case "cross ok" `Quick test_eval_cross_ok;
         Alcotest.test_case "identical points" `Quick test_eval_identical_points;
         Alcotest.test_case "undefined point" `Quick test_eval_undefined_point;
         Alcotest.test_case "parallel cross" `Quick test_eval_parallel_cross ]);
      ("planarize",
       [ Alcotest.test_case "two diagonals split" `Quick test_planarize_two_diagonals;
         Alcotest.test_case "single crease" `Quick test_planarize_single_crease ]) ]
