open Beloch

let test_error_roundtrip () =
  let pos =
    { Lexing.pos_fname = "x.bel"; pos_lnum = 3; pos_bol = 10; pos_cnum = 14 }
  in
  Alcotest.(check string)
    "span format" "x.bel:3:5"
    (Beloch.Error.span_to_string (pos, pos))

let q = Num.of_int
let half = Num.of_q (Q.of_ints 1 2)
let pt x y = { Geom.x = q x; y = q y }

let test_diagonals_intersect_center () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 1) in
  let l2 = Geom.line_through (pt 1 0) (pt 0 1) in
  match Geom.intersection l1 l2 with
  | Some p ->
      Alcotest.(check bool)
        "center is (1/2,1/2)" true
        (Geom.point_equal p { Geom.x = half; y = half })
  | None -> Alcotest.fail "expected an intersection"

let test_bisector_of_bottom_edge () =
  (* perpendicular bisector of a=(0,0) and b=(1,0) is the vertical line x=1/2 *)
  let l = Geom.perpendicular_bisector (pt 0 0) (pt 1 0) in
  let on p =
    Num.equal
      (Num.add (Num.mul l.Geom.a p.Geom.x) (Num.mul l.Geom.b p.Geom.y))
      l.Geom.c
  in
  Alcotest.(check bool)
    "(1/2,0) on bisector" true
    (on { Geom.x = half; y = q 0 });
  Alcotest.(check bool)
    "(1/2,1) on bisector" true
    (on { Geom.x = half; y = q 1 })

let test_perpendicular_through () =
  (* diagonal a-c is the line x = y; the perpendicular through b=(1,0) is the
     other diagonal x + y = 1 (through b and d) *)
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  let m = Geom.perpendicular_through l (pt 1 0) in
  let on ln p =
    Num.equal
      (Num.add (Num.mul ln.Geom.a p.Geom.x) (Num.mul ln.Geom.b p.Geom.y))
      ln.Geom.c
  in
  Alcotest.(check bool) "passes through P=(1,0)" true (on m (pt 1 0));
  Alcotest.(check bool) "passes through (0,1)" true (on m (pt 0 1));
  (* perpendicular: the two lines' normals are orthogonal *)
  Alcotest.(check bool)
    "normals orthogonal" true
    (Num.equal
       (Num.add (Num.mul l.Geom.a m.Geom.a) (Num.mul l.Geom.b m.Geom.b))
       Num.zero)

let test_parallel_lines () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 1) (pt 1 1) in
  Alcotest.(check bool) "parallel" true (Geom.parallel l1 l2);
  match Geom.intersection l1 l2 with
  | None -> ()
  | Some _ -> Alcotest.fail "expected none"

let test_in_unit_square () =
  Alcotest.(check bool) "center inside" true (Geom.in_unit_square (pt 0 0));
  Alcotest.(check bool)
    "corner inside (boundary)" true
    (Geom.in_unit_square { Geom.x = half; y = half });
  Alcotest.(check bool) "outside" false (Geom.in_unit_square (pt 2 2))

let test_clip_diagonal () =
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  match Geom.clip_to_unit_square l with
  | Some (p, q) ->
      let has a = Geom.point_equal p a || Geom.point_equal q a in
      Alcotest.(check bool)
        "endpoints are the two corners" true
        (has (pt 0 0) && has (pt 1 1))
  | None -> Alcotest.fail "diagonal should clip to a segment"

let test_segment_intersection_center () =
  let s1 = (pt 0 0, pt 1 1) in
  let s2 = (pt 1 0, pt 0 1) in
  match Geom.segment_intersection s1 s2 with
  | Some p ->
      Alcotest.(check bool)
        "cross at center" true
        (Geom.point_equal p { Geom.x = half; y = half })
  | None -> Alcotest.fail "segments cross at center"

let test_segment_no_touch () =
  (* two boundary edges that share no interior point: bottom and top *)
  let s1 = (pt 0 0, pt 1 0) in
  let s2 = (pt 0 1, pt 1 1) in
  match Geom.segment_intersection s1 s2 with
  | None -> ()
  | Some _ -> Alcotest.fail "parallel edges must not intersect"

let test_parse_named_and_anon () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --d1: through .a .c\n\
       map .b onto .d\n\
       .center: cross --d1 --d2\n"
  in
  Alcotest.(check int) "three statements" 3 (List.length prog);
  match prog with
  | [
   Ast.Crease (Some "d1", Ast.Through _, _, _);
   Ast.Crease (None, Ast.MapPoints _, _, _);
   Ast.Point ("center", Ast.Cross _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape"

let test_parse_syntax_error () =
  try
    ignore (Beloch.parse ~filename:"t.bel" "paper square\nmap .a\n");
    Alcotest.fail "expected a syntax error"
  with Error.Beloch_error (_, _) -> ()

let test_parse_perp () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d: through .a .c\nperp --d through .b\n"
  in
  match prog with
  | [
   Ast.Crease (Some "d", Ast.Through _, _, _);
   Ast.Crease (None, Ast.Perp ({ name = "b"; _ }, { cname = "d"; _ }), _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for perp"

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
    Alcotest.(check bool)
      ("error mentions " ^ msg_substr)
      true
      (try
         ignore (Str.search_forward (Str.regexp_string msg_substr) m 0);
         true
       with Not_found -> false)

let test_eval_counts_creases () =
  let cs = eval_src "paper square\n--d1: through .a .c\nmap .b onto .d\n" in
  Alcotest.(check int) "two creases" 2 (List.length cs)

let test_eval_cross_ok () =
  let cs =
    eval_src
      "paper square\n\
       --d1: through .a .c\n\
       --d2: through .b .d\n\
       .m: cross --d1 --d2\n\
       map .a onto .m\n"
  in
  Alcotest.(check int) "three creases" 3 (List.length cs)

let test_eval_identical_points () =
  expect_error "distinct" (fun () -> eval_src "paper square\nthrough .a .a\n")

let test_eval_undefined_point () =
  expect_error "undefined" (fun () -> eval_src "paper square\nmap .a onto .z\n")

let test_eval_parallel_cross () =
  expect_error "parallel" (fun () ->
      eval_src
        "paper square\n\
         --h1: through .a .b\n\
         --h2: through .d .c\n\
         .x: cross --h1 --h2\n")

let test_eval_perp_provenance () =
  let cs = eval_src "paper square\n--d: through .a .c\nperp --d through .b\n" in
  Alcotest.(check int) "two creases" 2 (List.length cs);
  let perp =
    List.find (fun (c : Eval.crease) -> c.Eval.prov.State.axiom = "axiom3") cs
  in
  Alcotest.(check string)
    "axiom3 provenance" "axiom3" perp.Eval.prov.State.axiom;
  Alcotest.(check (list string))
    "mixed point+crease sources" [ ".b"; "--d" ] perp.Eval.prov.State.sources

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
  Alcotest.(check int)
    "4 boundary + 1 crease" 5
    (Dynarray.length st.State.edges)

let test_planarize_boundary_split () =
  (* x-midpoint: bisector a->center hits bottom at (1/2,0) and left at (0,1/2),
     splitting two boundary edges; full planarization => 8 vertices, 13 edges *)
  let cs =
    eval_src
      "paper square\n\
       --d1: through .a .c\n\
       --d2: through .b .d\n\
       .m: cross --d1 --d2\n\
       map .a onto .m\n"
  in
  let st = Planarize.run cs in
  Alcotest.(check int) "eight vertices" 8 (Dynarray.length st.State.verts);
  Alcotest.(check int) "thirteen edges" 13 (Dynarray.length st.State.edges)

let test_planarize_edge_dedup () =
  (* the same diagonal twice must not produce a duplicate edge:
     4 boundary + 1 diagonal = 5 edges, not 6 *)
  let cs = eval_src "paper square\nthrough .a .c\nthrough .a .c\n" in
  let st = Planarize.run cs in
  Alcotest.(check int) "no duplicate edge" 5 (Dynarray.length st.State.edges)

let test_emit_fields () =
  let cs = eval_src "paper square\nthrough .a .c\n" in
  let st = Planarize.run cs in
  let json = Fold_emit.to_json st (Faces.extract st) in
  let open Yojson.Safe.Util in
  Alcotest.(check string)
    "creator" "beloch 0.3.0-dev"
    (json |> member "file_creator" |> to_string);
  Alcotest.(check int)
    "frame_classes is creasePattern" 1
    (json |> member "frame_classes" |> to_list |> List.length);
  let assigns =
    json |> member "edges_assignment" |> to_list |> List.map to_string
  in
  Alcotest.(check bool) "has a U crease" true (List.mem "U" assigns);
  Alcotest.(check bool) "has a B boundary" true (List.mem "B" assigns);
  (* one diagonal cuts the square into two faces *)
  Alcotest.(check int)
    "two faces" 2
    (json |> member "faces_vertices" |> to_list |> List.length)

let read_example name =
  In_channel.with_open_text ("../../../examples/" ^ name) In_channel.input_all

let test_e2e_diagonals () =
  let src = read_example "diagonals.bel" in
  let json = Beloch.fold_string ~filename:"diagonals.bel" src in
  let open Yojson.Safe.Util in
  (* 4 corners + center = 5 vertices; 4 boundary + 4 crease halves = 8 edges *)
  Alcotest.(check int)
    "vertices" 5
    (json |> member "vertices_coords" |> to_list |> List.length);
  Alcotest.(check int)
    "edges" 8
    (json |> member "edges_vertices" |> to_list |> List.length)

let test_e2e_anti_parallel () =
  expect_error "parallel" (fun () ->
      Beloch.fold_string ~filename:"parallel.bel" (read_example "parallel.bel"))

let test_e2e_anti_dup () =
  expect_error "distinct" (fun () ->
      Beloch.fold_string ~filename:"dup-point.bel"
        (read_example "dup-point.bel"))

let test_e2e_square_one_face () =
  let json =
    Beloch.fold_string ~filename:"square.bel" (read_example "square.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int)
    "one face" 1
    (json |> member "faces_vertices" |> to_list |> List.length);
  Alcotest.(check int)
    "face has four vertices" 4
    (json |> member "faces_vertices" |> to_list |> List.hd |> to_list
   |> List.length)

let test_e2e_diagonals_four_faces () =
  let json =
    Beloch.fold_string ~filename:"diagonals.bel" (read_example "diagonals.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check int)
    "four faces" 4
    (json |> member "faces_vertices" |> to_list |> List.length)

let test_e2e_perp () =
  let json =
    Beloch.fold_string ~filename:"perp.bel" (read_example "perp.bel")
  in
  let open Yojson.Safe.Util in
  (* perpendicular from b onto diagonal a-c is the diagonal b-d; the two
     diagonals cut the square into four faces *)
  Alcotest.(check int)
    "four faces" 4
    (json |> member "faces_vertices" |> to_list |> List.length);
  let axioms =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "axiom" |> to_string))
  in
  Alcotest.(check bool)
    "an axiom3 crease is present" true (List.mem "axiom3" axioms)

let test_ccw_order () =
  let o = pt 0 0 in
  (* East before North before West before South, going CCW *)
  Alcotest.(check int)
    "E before N" (-1)
    (Geom.ccw_compare ~center:o (pt 1 0) (pt 0 1));
  Alcotest.(check int)
    "N before W" (-1)
    (Geom.ccw_compare ~center:o (pt 0 1) (pt (-1) 0));
  Alcotest.(check int)
    "W before S" (-1)
    (Geom.ccw_compare ~center:o (pt (-1) 0) (pt 0 (-1)));
  Alcotest.(check int)
    "S after E" 1
    (Geom.ccw_compare ~center:o (pt 0 (-1)) (pt 1 0))

let test_signed_area () =
  let ccw = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let cw = [| pt 0 0; pt 0 1; pt 1 1; pt 1 0 |] in
  Alcotest.(check bool)
    "ccw positive (=1)" true
    (Num.equal (Geom.signed_area ccw) Num.one);
  Alcotest.(check bool)
    "cw negative (=-1)" true
    (Num.equal (Geom.signed_area cw) (Num.neg Num.one))

let test_faces_square () =
  let st = Planarize.run (eval_src "paper square\n") in
  match Faces.extract st with
  | [ f ] ->
      Alcotest.(check int) "single face has 4 vertices" 4 (Array.length f)
  | fs -> Alcotest.failf "expected one face, got %d" (List.length fs)

let test_faces_two_diagonals () =
  let st =
    Planarize.run (eval_src "paper square\nthrough .a .c\nthrough .b .d\n")
  in
  let fs = Faces.extract st in
  Alcotest.(check int) "four bounded faces" 4 (List.length fs);
  Alcotest.(check bool)
    "each face is a triangle" true
    (List.for_all (fun f -> Array.length f = 3) fs)

let test_eval_crease_name () =
  let cs = eval_src "paper square\n--d1: through .a .c\nthrough .b .d\n" in
  let named = List.nth cs 0 and anon = List.nth cs 1 in
  Alcotest.(check (option string))
    "named crease carries its name" (Some "d1") named.Eval.prov.State.name;
  Alcotest.(check (option string))
    "anonymous crease has no name" None anon.Eval.prov.State.name

let test_emit_crease_name () =
  let cs = eval_src "paper square\n--d1: through .a .c\n" in
  let st = Planarize.run cs in
  let json = Fold_emit.to_json st (Faces.extract st) in
  let open Yojson.Safe.Util in
  let names =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "name"))
  in
  Alcotest.(check bool)
    "a crease entry carries name \"d1\"" true
    (List.exists (fun n -> n = `String "d1") names)

let test_isometry_basics () =
  let i = Isometry.identity in
  Alcotest.(check bool)
    "identity fixes a point" true
    (Geom.point_equal (Isometry.apply_point i (pt 3 4)) (pt 3 4));
  Alcotest.(check int) "identity det +1" 1 (Isometry.det_sign i)

let test_isometry_reflection () =
  let l = { Geom.a = q 1; b = q 0; c = half } in
  let r = Isometry.reflect_across_line l in
  (* agrees with Geom.reflect_point *)
  Alcotest.(check bool)
    "reflection isometry matches reflect_point" true
    (Geom.point_equal
       (Isometry.apply_point r (pt 0 0))
       (Geom.reflect_point l (pt 0 0)));
  Alcotest.(check int) "a reflection has det -1" (-1) (Isometry.det_sign r);
  (* two reflections compose to a direct isometry *)
  let rr = Isometry.compose r r in
  Alcotest.(check int) "reflection twice has det +1" 1 (Isometry.det_sign rr);
  Alcotest.(check bool)
    "reflection twice is identity on a point" true
    (Geom.point_equal (Isometry.apply_point rr (pt 0 0)) (pt 0 0))

let test_isometry_inverse () =
  let l = { Geom.a = q 1; b = q 1; c = q 1 } in
  (* x + y = 1, a slanted mirror *)
  let r = Isometry.reflect_across_line l in
  let inv = Isometry.inverse r in
  let p = pt 2 5 in
  Alcotest.(check bool)
    "inverse undoes apply" true
    (Geom.point_equal (Isometry.apply_point inv (Isometry.apply_point r p)) p)

let n = Num.of_int

let test_num_rational () =
  Alcotest.(check bool) "2+3=5" true (Num.equal (Num.add (n 2) (n 3)) (n 5));
  Alcotest.(check bool) "2*3=6" true (Num.equal (Num.mul (n 2) (n 3)) (n 6));
  Alcotest.(check int) "sign(-2)" (-1) (Num.sign (n (-2)));
  Alcotest.(check int) "sign(0)" 0 (Num.sign Num.zero)

let test_num_sqrt () =
  Alcotest.(check bool)
    "sqrt2*sqrt2=2" true
    (Num.equal (Num.mul (Num.sqrt (n 2)) (Num.sqrt (n 2))) (n 2));
  Alcotest.(check bool)
    "sqrt4=2 (collapses)" true
    (Num.equal (Num.sqrt (n 4)) (n 2));
  Alcotest.(check bool)
    "sqrt of negative raises" true
    (try
       ignore (Num.sqrt (n (-1)));
       false
     with Invalid_argument _ -> true)

let test_num_sign_mixed () =
  let r2 = Num.sqrt (n 2) in
  Alcotest.(check int) "sqrt2 - 1 > 0" 1 (Num.sign (Num.sub r2 Num.one));
  Alcotest.(check int) "1 - sqrt2 < 0" (-1) (Num.sign (Num.sub Num.one r2));
  Alcotest.(check int) "1 < sqrt2" (-1) (Num.compare Num.one r2)

let test_num_equal_rewrites () =
  (* sqrt8 = 2*sqrt2, and sqrt8 - 2*sqrt2 = 0 exactly *)
  let lhs = Num.sqrt (n 8) and rhs = Num.mul (n 2) (Num.sqrt (n 2)) in
  Alcotest.(check bool) "sqrt8 = 2 sqrt2" true (Num.equal lhs rhs);
  Alcotest.(check int) "sqrt8 - 2 sqrt2 = 0" 0 (Num.sign (Num.sub lhs rhs))

let test_num_distributive () =
  (* a*(b+c) = a*b + a*c with a=sqrt2, b=sqrt3, c=1 — exercises cross-generator mul *)
  let a = Num.sqrt (n 2) and b = Num.sqrt (n 3) and c = Num.one in
  Alcotest.(check bool)
    "distributive" true
    (Num.equal (Num.mul a (Num.add b c)) (Num.add (Num.mul a b) (Num.mul a c)))

let test_num_inv_roundtrip () =
  let x = Num.sub (Num.sqrt (n 2)) (n 3) in
  (* √2 − 3, nonzero *)
  Alcotest.(check bool)
    "x * (1/x) = 1" true
    (Num.equal (Num.mul x (Num.div Num.one x)) Num.one);
  Alcotest.(check bool) "x / x = 1" true (Num.equal (Num.div x x) Num.one)

let test_num_nested_radical () =
  (* a = √(1 + √2); a² must equal 1 + √2 exactly *)
  let inner = Num.add Num.one (Num.sqrt (n 2)) in
  let a = Num.sqrt inner in
  Alcotest.(check bool) "(√(1+√2))² = 1+√2" true (Num.equal (Num.mul a a) inner)

let test_num_termination_guard () =
  (* a deliberately deep nesting; sign must return (no infinite recursion) *)
  let deep =
    Num.sqrt (Num.add Num.one (Num.sqrt (Num.add Num.one (Num.sqrt (n 2)))))
  in
  Alcotest.(check int) "deep nest is positive" 1 (Num.sign deep)

let test_num_to_float () =
  Alcotest.(check bool)
    "to_float sqrt2 ≈ 1.41421" true
    (Float.abs (Num.to_float (Num.sqrt (n 2)) -. 1.4142135623) < 1e-6)

let test_angle_bisectors () =
  (* l1 = x-axis (y=0), l2 = y=x. The 22.5° bisector through the origin has
     slope √2−1: the point (1, √2−1) lies on bis_opp (d1=−d2). *)
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 0) (pt 1 1) in
  match Geom.angle_bisectors l1 l2 with
  | None -> Alcotest.fail "intersecting lines must have bisectors"
  | Some (_, bis_opp) ->
      let s2m1 = Num.sub (Num.sqrt (q 2)) Num.one in
      (* √2 − 1 *)
      let p = { Geom.x = q 1; y = s2m1 } in
      let on l =
        Num.sign
          (Num.sub
             (Num.add (Num.mul l.Geom.a p.Geom.x) (Num.mul l.Geom.b p.Geom.y))
             l.Geom.c)
      in
      Alcotest.(check int) "(1,√2−1) on the 22.5° bisector" 0 (on bis_opp)

let test_parallel_midline () =
  (* left edge x=0 and right edge x=1 -> midline x=1/2 *)
  let l = Geom.line_through (pt 0 0) (pt 0 1) in
  let r = Geom.line_through (pt 1 0) (pt 1 1) in
  let m = Geom.parallel_midline l r in
  let on px py =
    Num.sign
      (Num.sub (Num.add (Num.mul m.Geom.a px) (Num.mul m.Geom.b py)) m.Geom.c)
  in
  Alcotest.(check int) "(1/2,0) on midline" 0 (on half (q 0));
  Alcotest.(check int) "(1/2,1) on midline" 0 (on half (q 1))

let test_reflect_point () =
  (* mirror line x = 1/2 is a=1,b=0,c=1/2 *)
  let l = { Geom.a = q 1; b = q 0; c = half } in
  Alcotest.(check bool)
    "(0,0) -> (1,0)" true
    (Geom.point_equal (Geom.reflect_point l (pt 0 0)) (pt 1 0));
  Alcotest.(check bool)
    "reflection is an involution" true
    (Geom.point_equal
       (Geom.reflect_point l (Geom.reflect_point l (pt 0 0)))
       (pt 0 0));
  Alcotest.(check bool)
    "a point on the line is fixed" true
    (Geom.point_equal
       (Geom.reflect_point l { Geom.x = half; y = q 7 })
       { Geom.x = half; y = q 7 })

let test_side_of_line () =
  let l = { Geom.a = q 1; b = q 0; c = half } in
  Alcotest.(check int) "right of x=1/2 is +1" 1 (Geom.side_of_line l (pt 1 0));
  Alcotest.(check int) "left of x=1/2 is -1" (-1) (Geom.side_of_line l (pt 0 0));
  Alcotest.(check int)
    "on x=1/2 is 0" 0
    (Geom.side_of_line l { Geom.x = half; y = q 9 })

let test_clip_halfplane () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let l = { Geom.a = q 1; b = q 0; c = half } in
  (* x = 1/2 *)
  let right = Geom.clip_convex_halfplane l 1 sq in
  let left = Geom.clip_convex_halfplane l (-1) sq in
  Alcotest.(check int) "right half has 4 vertices" 4 (Array.length right);
  Alcotest.(check int) "left half has 4 vertices" 4 (Array.length left);
  Alcotest.(check bool)
    "right half area = 1/2" true
    (Num.equal (Geom.signed_area right) half);
  Alcotest.(check bool)
    "left half area = 1/2" true
    (Num.equal (Geom.signed_area left) half)

let test_clip_halfplane_all_or_nothing () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let l = { Geom.a = q 1; b = q 0; c = q 2 } in
  (* x = 2, misses the square *)
  Alcotest.(check int)
    "whole square on the -1 side" 4
    (Array.length (Geom.clip_convex_halfplane l (-1) sq));
  Alcotest.(check int)
    "nothing on the +1 side" 0
    (Array.length (Geom.clip_convex_halfplane l 1 sq))

let test_in_convex_polygon () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  Alcotest.(check bool)
    "center inside" true
    (Geom.in_convex_polygon sq { Geom.x = half; y = half });
  Alcotest.(check bool)
    "corner on boundary counts" true
    (Geom.in_convex_polygon sq (pt 0 0));
  Alcotest.(check bool)
    "outside is outside" false
    (Geom.in_convex_polygon sq (pt 2 2))

let test_parse_bisect () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --v: map .a onto .b\n\
       --h: map .b onto .c\n\
       map --v onto --h toward .a\n"
  in
  match prog with
  | [
   _;
   _;
   Ast.Crease
     ( None,
       Ast.MapLines
         ({ cname = "v"; _ }, { cname = "h"; _ }, Some { name = "a"; _ }),
       _,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for bisect"

let test_eval_bisect_select () =
  (* v: x=1/2, h: y=1/2 (perpendicular, cross at centre). toward .a vs .b pick
     the two different diagonals through the centre -> different crease lines. *)
  let prog s =
    eval_src ("paper square\n--v: map .a onto .b\n--h: map .b onto .c\n" ^ s)
  in
  let line_of cs = (List.nth cs 2).Eval.line in
  let prog_a = prog "map --v onto --h toward .a" in
  let prog_b = prog "map --v onto --h toward .b" in
  let la = line_of prog_a in
  let lb = line_of prog_b in
  (* the two creases differ: they are not the same line (compare a-coefficient sign pattern) *)
  Alcotest.(check bool)
    "toward .a and .b give different bisectors" false
    (Num.equal la.Geom.a lb.Geom.a
    && Num.equal la.Geom.b lb.Geom.b
    && Num.equal la.Geom.c lb.Geom.c);
  (* Helper to check if a point lies exactly on a line: a·Px + b·Py = c *)
  let on l p =
    Num.sign
      (Num.sub
         (Num.add (Num.mul l.Geom.a p.Geom.x) (Num.mul l.Geom.b p.Geom.y))
         l.Geom.c)
  in
  (* toward .a must select a-c diagonal: passes through (0,0) and (1,1) *)
  Alcotest.(check int) "toward .a line through .a=(0,0)" 0 (on la (pt 0 0));
  Alcotest.(check int) "toward .a line through .c=(1,1)" 0 (on la (pt 1 1));
  (* toward .b must select b-d diagonal: passes through (1,0) and (0,1) *)
  Alcotest.(check int) "toward .b line through .b=(1,0)" 0 (on lb (pt 1 0));
  Alcotest.(check int) "toward .b line through .d=(0,1)" 0 (on lb (pt 0 1));
  let perp = List.nth prog_a 2 in
  Alcotest.(check string)
    "axiom5 provenance" "axiom5" perp.Eval.prov.State.axiom;
  Alcotest.(check (list string))
    "sources" [ "--v"; "--h"; ".a" ] perp.Eval.prov.State.sources

let test_parse_fold_action () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n@map .a onto .c moving .a mountain\n"
  in
  match prog with
  | [
   Ast.Crease
     ( None,
       Ast.MapPoints _,
       Some { moving = Some { name = "a"; _ }; direction = Ast.Mountain },
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST for @map fold action"

let test_parse_fold_valley_default () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\n@map .a onto .c\n" in
  match prog with
  | [
   Ast.Crease
     (None, Ast.MapPoints _, Some { moving = None; direction = Ast.Valley }, _);
  ] ->
      ()
  | _ -> Alcotest.fail "default fold is valley with no moving"

let test_parse_precrease_no_foldspec () =
  let prog = Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .c\n" in
  match prog with
  | [ Ast.Crease (None, Ast.MapPoints _, None, _) ] -> ()
  | _ -> Alcotest.fail "bare axiom must carry no fold_spec"

let test_eval_fold_not_implemented () =
  expect_error "not yet implemented" (fun () ->
      eval_src "paper square\n@map .a onto .c\n")

let test_eval_bisect_errors () =
  expect_error "identical" (fun () ->
      eval_src
        "paper square\n\
         --x: through .a .c\n\
         --y: through .a .c\n\
         map --x onto --y toward .b\n");
  expect_error "ambiguous" (fun () ->
      eval_src
        "paper square\n\
         --v: map .a onto .b\n\
         --h: map .b onto .c\n\
         map --v onto --h\n");
  expect_error "on a fold line" (fun () ->
      eval_src
        "paper square\n\
         --d: through .a .c\n\
         --h: map .b onto .c\n\
         map --d onto --h toward .a\n")

let test_e2e_bisect_select () =
  let open Yojson.Safe.Util in
  let creases json =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "axiom" |> to_string))
  in
  let ja =
    Beloch.fold_string ~filename:"bisect-a.bel" (read_example "bisect-a.bel")
  in
  let jb =
    Beloch.fold_string ~filename:"bisect-b.bel" (read_example "bisect-b.bel")
  in
  Alcotest.(check bool)
    "a has an axiom5 crease" true
    (List.mem "axiom5" (creases ja));
  Alcotest.(check bool)
    "b has an axiom5 crease" true
    (List.mem "axiom5" (creases jb));
  (* same config, different selector -> the FOLD outputs differ *)
  Alcotest.(check bool)
    "toward .a and .b produce different FOLD" false
    (Yojson.Safe.equal
       (ja |> member "vertices_coords")
       (jb |> member "vertices_coords")
    && Yojson.Safe.equal
         (ja |> member "edges_vertices")
         (jb |> member "edges_vertices"))

let test_e2e_bisect_parallel () =
  let json =
    Beloch.fold_string ~filename:"bisect-parallel.bel"
      (read_example "bisect-parallel.bel")
  in
  let open Yojson.Safe.Util in
  (* midline x=1/2 splits the square into two faces *)
  Alcotest.(check int)
    "two faces" 2
    (json |> member "faces_vertices" |> to_list |> List.length)

let fs_pt = pt (* reuse existing helper *)

let count_assign a recs =
  List.length
    (List.filter
       (fun (r : Fold_state.crease_record) -> r.Fold_state.assign = a)
       recs)

let test_fold_subdivide () =
  (* precrease the flat square along x=1/2: 2 faces, 1 crease record, assign U *)
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st, recs = Fold_state.subdivide Fold_state.init_square axis in
  Alcotest.(check int)
    "two faces after subdivide" 2
    (Array.length st.Fold_state.faces);
  Alcotest.(check int) "one crease record" 1 (List.length recs);
  Alcotest.(check int)
    "subdivide records are U" 1
    (count_assign Fold_state.U recs)

let test_fold_records_valley () =
  (* half fold valley: one V crease record *)
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let _, recs =
    Fold_state.fold_with_records Fold_state.init_square ~axis ~move_side:1
      ~valley:true
  in
  Alcotest.(check int) "one record" 1 (List.length recs);
  Alcotest.(check int)
    "the half fold is a valley" 1
    (count_assign Fold_state.V recs);
  Alcotest.(check int) "no mountain" 0 (count_assign Fold_state.M recs)

let test_fold_records_accordion () =
  (* quarter fold: fold 1 (x=1/2) gives a stay face (det +1) and a moved face
     (det -1) both in the left half; fold 2 (y=1/2) cuts both -> one V and one M *)
  let axis1 = { Geom.a = q 1; b = q 0; c = half } in
  let st1 =
    Fold_state.simple_fold Fold_state.init_square ~axis:axis1 ~move_side:1
      ~valley:true
  in
  let axis2 = { Geom.a = q 0; b = q 1; c = half } in
  let _, recs2 =
    Fold_state.fold_with_records st1 ~axis:axis2 ~move_side:1 ~valley:true
  in
  Alcotest.(check int)
    "two crease records from the second fold" 2 (List.length recs2);
  Alcotest.(check int)
    "one valley (accordion)" 1
    (count_assign Fold_state.V recs2);
  Alcotest.(check int)
    "one mountain (accordion)" 1
    (count_assign Fold_state.M recs2)

let test_fold_paper_preimages () =
  (* flat: a table point in the square has exactly one paper preimage.
     after a half fold, a point in the (overlapping) left half has two. *)
  let flat = Fold_state.paper_preimages Fold_state.init_square (fs_pt 1 0) in
  Alcotest.(check int) "one preimage when flat" 1 (List.length flat);
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st =
    Fold_state.simple_fold Fold_state.init_square ~axis ~move_side:1
      ~valley:true
  in
  let folded =
    Fold_state.paper_preimages st { Geom.x = Num.of_q (Q.of_ints 1 4); y = q 0 }
  in
  Alcotest.(check int)
    "two preimages in the folded overlap" 2 (List.length folded)

let test_fold_state_init () =
  let st = Fold_state.init_square in
  Alcotest.(check int) "one face" 1 (Array.length st.Fold_state.faces);
  Alcotest.(check int) "one layer" 1 (Array.length st.Fold_state.layers);
  Alcotest.(check bool)
    "corner .a at (0,0) on the table" true
    (Geom.point_equal (Fold_state.table_position st (fs_pt 0 0)) (fs_pt 0 0))

let test_fold_state_half () =
  (* fold the right half of the square onto the left, valley, along x = 1/2.
     map .b (1,0) onto .a (0,0): axis is x = 1/2; moving side is .b's side (+1). *)
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  Alcotest.(check int)
    "two faces after one fold" 2
    (Array.length st.Fold_state.faces);
  Alcotest.(check int) "two layers" 2 (Array.length st.Fold_state.layers);
  (* the material point .b = (1,0) now lands exactly on .a = (0,0) *)
  Alcotest.(check bool)
    ".b maps onto .a" true
    (Geom.point_equal (Fold_state.table_position st (fs_pt 1 0)) (fs_pt 0 0));
  (* both faces' table footprints lie in the left half (x ≤ 1/2) *)
  let all_left =
    Array.for_all
      (fun i ->
        Array.for_all
          (fun p -> Num.compare p.Geom.x half <= 0)
          (Fold_state.table_polygon st i))
      [| 0; 1 |]
  in
  Alcotest.(check bool) "folded footprint is the left half" true all_left

let test_fold_state_layer_order () =
  (* valley fold: the moved face is the top layer (last in `layers`). The moved
     face is the one whose isometry is a reflection (det -1). *)
  let st = Fold_state.init_square in
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st = Fold_state.simple_fold st ~axis ~move_side:1 ~valley:true in
  let top = st.Fold_state.layers.(Array.length st.Fold_state.layers - 1) in
  Alcotest.(check int)
    "top layer is the moved (reflected) face" (-1)
    (Isometry.det_sign st.Fold_state.faces.(top).Fold_state.iso);
  let bottom = st.Fold_state.layers.(0) in
  Alcotest.(check int)
    "bottom layer is stationary (det +1)" 1
    (Isometry.det_sign st.Fold_state.faces.(bottom).Fold_state.iso)

let test_convex_overlap () =
  let unit = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let shifted_overlap = [| pt 0 0; pt 2 0; pt 2 2; pt 0 2 |] in
  (* the right half overlaps the unit square in positive area *)
  let right_half =
    [| { Geom.x = half; y = q 0 }; pt 1 0; pt 1 1; { Geom.x = half; y = q 1 } |]
  in
  Alcotest.(check bool)
    "unit overlaps a bigger square covering it" true
    (Geom.convex_overlap unit shifted_overlap);
  Alcotest.(check bool)
    "unit overlaps its right half" true
    (Geom.convex_overlap unit right_half);
  (* a square fully to the right (x in [2,3]) is disjoint *)
  let far = [| pt 2 0; pt 3 0; pt 3 1; pt 2 1 |] in
  Alcotest.(check bool)
    "disjoint squares do not overlap" false
    (Geom.convex_overlap unit far);
  (* a square sharing only the edge x=1 touches but has no positive overlap *)
  let touching = [| pt 1 0; pt 2 0; pt 2 1; pt 1 1 |] in
  Alcotest.(check bool)
    "edge-touching is not overlap" false
    (Geom.convex_overlap unit touching)

let test_on_segment () =
  let s = (pt 0 0, pt 2 2) in
  Alcotest.(check bool)
    "midpoint is on the segment" true
    (Geom.on_segment s (pt 1 1));
  Alcotest.(check bool)
    "endpoint is on the segment" true
    (Geom.on_segment s (pt 0 0));
  Alcotest.(check bool)
    "collinear but outside is not on" false
    (Geom.on_segment s (pt 3 3));
  Alcotest.(check bool)
    "off the line is not on" false
    (Geom.on_segment s (pt 1 0))

let () =
  Alcotest.run "beloch"
    [
      ("error", [ Alcotest.test_case "span format" `Quick test_error_roundtrip ]);
      ( "geom",
        [
          Alcotest.test_case "diagonals meet at center" `Quick
            test_diagonals_intersect_center;
          Alcotest.test_case "perpendicular bisector" `Quick
            test_bisector_of_bottom_edge;
          Alcotest.test_case "perpendicular through a point" `Quick
            test_perpendicular_through;
          Alcotest.test_case "parallel lines" `Quick test_parallel_lines;
          Alcotest.test_case "point in unit square" `Quick test_in_unit_square;
          Alcotest.test_case "clip diagonal" `Quick test_clip_diagonal;
          Alcotest.test_case "segment intersection" `Quick
            test_segment_intersection_center;
          Alcotest.test_case "segments do not touch" `Quick
            test_segment_no_touch;
        ] );
      ( "fold_clip",
        [
          Alcotest.test_case "half-plane clip" `Quick test_clip_halfplane;
          Alcotest.test_case "clip all or nothing" `Quick
            test_clip_halfplane_all_or_nothing;
          Alcotest.test_case "point in convex polygon" `Quick
            test_in_convex_polygon;
        ] );
      ( "parse",
        [
          Alcotest.test_case "named and anonymous" `Quick
            test_parse_named_and_anon;
          Alcotest.test_case "syntax error" `Quick test_parse_syntax_error;
          Alcotest.test_case "perp parses" `Quick test_parse_perp;
          Alcotest.test_case "bisect parses" `Quick test_parse_bisect;
          Alcotest.test_case "fold action parses" `Quick test_parse_fold_action;
          Alcotest.test_case "fold valley default" `Quick
            test_parse_fold_valley_default;
          Alcotest.test_case "bare axiom has no fold_spec" `Quick
            test_parse_precrease_no_foldspec;
        ] );
      ("state", [ Alcotest.test_case "vertex dedup" `Quick test_vertex_dedup ]);
      ( "eval",
        [
          Alcotest.test_case "count creases" `Quick test_eval_counts_creases;
          Alcotest.test_case "cross ok" `Quick test_eval_cross_ok;
          Alcotest.test_case "identical points" `Quick
            test_eval_identical_points;
          Alcotest.test_case "undefined point" `Quick test_eval_undefined_point;
          Alcotest.test_case "parallel cross" `Quick test_eval_parallel_cross;
          Alcotest.test_case "perp provenance" `Quick test_eval_perp_provenance;
          Alcotest.test_case "crease name in provenance" `Quick
            test_eval_crease_name;
          Alcotest.test_case "bisect selection + provenance" `Quick
            test_eval_bisect_select;
          Alcotest.test_case "bisect errors" `Quick test_eval_bisect_errors;
          Alcotest.test_case "fold not yet implemented" `Quick
            test_eval_fold_not_implemented;
        ] );
      ( "planarize",
        [
          Alcotest.test_case "two diagonals split" `Quick
            test_planarize_two_diagonals;
          Alcotest.test_case "single crease" `Quick test_planarize_single_crease;
          Alcotest.test_case "boundary split" `Quick
            test_planarize_boundary_split;
          Alcotest.test_case "edge dedup" `Quick test_planarize_edge_dedup;
        ] );
      ( "emit",
        [
          Alcotest.test_case "fold fields" `Quick test_emit_fields;
          Alcotest.test_case "crease name in emit" `Quick test_emit_crease_name;
        ] );
      ( "e2e",
        [
          Alcotest.test_case "diagonals" `Quick test_e2e_diagonals;
          Alcotest.test_case "anti parallel" `Quick test_e2e_anti_parallel;
          Alcotest.test_case "anti dup point" `Quick test_e2e_anti_dup;
          Alcotest.test_case "square one face" `Quick test_e2e_square_one_face;
          Alcotest.test_case "diagonals four faces" `Quick
            test_e2e_diagonals_four_faces;
          Alcotest.test_case "perp end-to-end" `Quick test_e2e_perp;
          Alcotest.test_case "bisect selector" `Quick test_e2e_bisect_select;
          Alcotest.test_case "bisect parallel midline" `Quick
            test_e2e_bisect_parallel;
        ] );
      ( "geom2",
        [
          Alcotest.test_case "ccw order" `Quick test_ccw_order;
          Alcotest.test_case "signed area" `Quick test_signed_area;
        ] );
      ( "faces",
        [
          Alcotest.test_case "square is one face" `Quick test_faces_square;
          Alcotest.test_case "two diagonals -> 4 triangles" `Quick
            test_faces_two_diagonals;
        ] );
      ( "num",
        [
          Alcotest.test_case "rational arithmetic" `Quick test_num_rational;
          Alcotest.test_case "sqrt" `Quick test_num_sqrt;
          Alcotest.test_case "sign mixed" `Quick test_num_sign_mixed;
          Alcotest.test_case "equal rewrites" `Quick test_num_equal_rewrites;
          Alcotest.test_case "distributive" `Quick test_num_distributive;
          Alcotest.test_case "inv roundtrip" `Quick test_num_inv_roundtrip;
          Alcotest.test_case "nested radical" `Quick test_num_nested_radical;
          Alcotest.test_case "termination guard" `Quick
            test_num_termination_guard;
          Alcotest.test_case "to_float" `Quick test_num_to_float;
        ] );
      ( "bisect",
        [
          Alcotest.test_case "angle bisectors" `Quick test_angle_bisectors;
          Alcotest.test_case "parallel midline" `Quick test_parallel_midline;
        ] );
      ( "fold_geom",
        [
          Alcotest.test_case "reflect point" `Quick test_reflect_point;
          Alcotest.test_case "side of line" `Quick test_side_of_line;
        ] );
      ( "isometry",
        [
          Alcotest.test_case "basics" `Quick test_isometry_basics;
          Alcotest.test_case "reflection" `Quick test_isometry_reflection;
          Alcotest.test_case "inverse" `Quick test_isometry_inverse;
        ] );
      ( "fold_state",
        [
          Alcotest.test_case "init square" `Quick test_fold_state_init;
          Alcotest.test_case "half fold geometry" `Quick test_fold_state_half;
          Alcotest.test_case "valley layer order" `Quick
            test_fold_state_layer_order;
          Alcotest.test_case "subdivide" `Quick test_fold_subdivide;
          Alcotest.test_case "fold records valley" `Quick
            test_fold_records_valley;
          Alcotest.test_case "fold records accordion" `Quick
            test_fold_records_accordion;
          Alcotest.test_case "paper preimages" `Quick test_fold_paper_preimages;
        ] );
      ( "fold_geom2",
        [
          Alcotest.test_case "convex overlap" `Quick test_convex_overlap;
          Alcotest.test_case "on segment" `Quick test_on_segment;
        ] );
    ]
