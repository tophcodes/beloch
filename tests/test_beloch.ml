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

let test_project_basic () =
  (* project P=(0,1) onto l1 = x-axis (y=0) with crease ⊥ l2 = y-axis (x=0).
     Crease ⊥ y-axis ⟹ horizontal; P moves vertically (∥ y-axis) onto y=0,
     landing Q=(0,0). Crease = perp-bisector of (0,1)-(0,0) = line y=1/2. *)
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 0) (pt 0 1) in
  match Geom.project_crease (pt 0 1) l1 l2 with
  | None -> Alcotest.fail "expected a crease"
  | Some c ->
      let on l (p : Geom.point) =
        Num.equal (Num.add (Num.mul l.Geom.a p.Geom.x) (Num.mul l.Geom.b p.Geom.y)) l.Geom.c
      in
      Alcotest.(check bool) "crease through (0,1/2)" true (on c { Geom.x = q 0; y = half });
      Alcotest.(check bool) "crease through (1,1/2)" true (on c { Geom.x = q 1; y = half });
      (* crease ⊥ l2: dot of normals (c.a,c.b)·(l2.a,l2.b) = 0 *)
      Alcotest.(check bool) "crease ⊥ l2" true
        (Num.sign (Num.add (Num.mul c.Geom.a l2.Geom.a) (Num.mul c.Geom.b l2.Geom.b)) = 0)

let test_project_parallel_none () =
  (* l1 (y=0) ∥ l2 (y=1): no fold exists *)
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 1) (pt 1 1) in
  Alcotest.(check bool) "parallel ⟹ None" true (Geom.project_crease (pt 0 2) l1 l2 = None)

let test_project_on_l1 () =
  (* P=(0,0) already on l1 (y=0), l2 = y-axis (x=0), not parallel.
     Q = P ⟹ degenerate bisector; crease = perpendicular to l2 through P,
     i.e. the line y=0 (horizontal through the origin). *)
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 0) (pt 0 1) in
  match Geom.project_crease (pt 0 0) l1 l2 with
  | None -> Alcotest.fail "expected a crease"
  | Some c ->
      let expected = Geom.perpendicular_through l2 (pt 0 0) in
      (* same line: cross-products of (a,b,c) vanish *)
      Alcotest.(check bool) "crease = perp-through-l2 at P" true
        (Num.sign (Num.sub (Num.mul c.Geom.a expected.Geom.b) (Num.mul expected.Geom.a c.Geom.b)) = 0
         && Num.sign (Num.sub (Num.mul c.Geom.a expected.Geom.c) (Num.mul expected.Geom.a c.Geom.c)) = 0)

(* axiom 6: circle (centre (0,0), r²=1) ∩ x-axis (y=0) = (1,0) and (-1,0). *)
let test_circle_line_two () =
  let d = Geom.line_through (pt 0 0) (pt 1 0) in
  let pts = Geom.circle_line_intersection (pt 0 0) (q 1) d in
  Alcotest.(check int) "two intersections" 2 (List.length pts);
  let has px py =
    List.exists (fun (p : Geom.point) -> Geom.point_equal p (pt px py)) pts
  in
  Alcotest.(check bool) "(1,0) present" true (has 1 0);
  Alcotest.(check bool) "(-1,0) present" true (has (-1) 0)

(* axiom 6 two-solution case: fold p=(0,1) onto d=(y=0) through p'=(0,0).
   Landings (1,0),(-1,0); creases y=x and y=-x, both through the origin. *)
let test_beloch_two_solutions () =
  let d = Geom.line_through (pt 0 0) (pt 1 0) in
  let creases = Geom.beloch_creases (pt 0 1) d (pt 0 0) in
  Alcotest.(check int) "two creases" 2 (List.length creases);
  List.iter
    (fun c ->
      (* each crease passes through the pivot p'=(0,0) *)
      Alcotest.(check int) "crease through pivot" 0
        (Geom.side_of_line c (pt 0 0));
      (* reflecting p across the crease lands it on d (y=0) *)
      Alcotest.(check int) "landing on d" 0
        (Geom.side_of_line d (Geom.reflect_point c (pt 0 1))))
    creases

(* tangent: fold p=(1,0) onto d=(y=1) through p'=(0,0). Circle r=1 touches y=1
   at (0,1)≠p ⟹ exactly one crease (y=x). *)
let test_beloch_tangent () =
  let d = Geom.line_through (pt 0 1) (pt 1 1) in
  let creases = Geom.beloch_creases (pt 1 0) d (pt 0 0) in
  Alcotest.(check int) "one crease" 1 (List.length creases);
  (match creases with
   | [ c ] ->
       Alcotest.(check int) "crease through pivot" 0 (Geom.side_of_line c (pt 0 0));
       Alcotest.(check int) "landing on d" 0
         (Geom.side_of_line d (Geom.reflect_point c (pt 1 0)))
   | _ -> Alcotest.fail "expected exactly one crease")

(* out of reach: d=(y=2) is distance 2 from p'=(0,0) but r=1 ⟹ no crease. *)
let test_beloch_out_of_reach () =
  let d = Geom.line_through (pt 0 2) (pt 1 2) in
  Alcotest.(check int) "no creases" 0
    (List.length (Geom.beloch_creases (pt 1 0) d (pt 0 0)))

(* p already on d: landing q=p is the identity and is dropped; the mirror
   landing (-1,0) survives ⟹ exactly one crease (x=0). *)
let test_beloch_p_on_line_dropped () =
  let d = Geom.line_through (pt 0 0) (pt 1 0) in
  let creases = Geom.beloch_creases (pt 1 0) d (pt 0 0) in
  Alcotest.(check int) "identity landing dropped" 1 (List.length creases);
  (match creases with
   | [ c ] -> Alcotest.(check int) "crease through pivot" 0 (Geom.side_of_line c (pt 0 0))
   | _ -> Alcotest.fail "expected exactly one crease")

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
   Ast.Crease
     ( None,
       Ast.Perp (Ast.PNamed { name = "b"; _ }, Ast.LNamed { cname = "d"; _ }),
       _,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for perp"

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

let test_parse_inline_line () =
  match
    Beloch.parse ~filename:"t.bel" "paper square\nperp --(.a .b) through .c\n"
  with
  | [
   Ast.Crease
     (None, Ast.Perp (Ast.PNamed { name = "c"; _ }, Ast.LThrough _), _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "expected an inline-line Perp operand"

let test_parse_inline_point_nested () =
  (* nested: a line through an inline cross-point and a named point *)
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n\
       --d1: through .a .c\n\
       --d2: through .b .d\n\
       perp --( .(--d1 --d2) .a ) through .b\n"
  with
  | [
   _;
   _;
   Ast.Crease
     (None, Ast.Perp (_, Ast.LThrough (Ast.PCross _, Ast.PNamed _, _)), _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "expected a nested inline operand"

let test_eval_identical_points () =
  expect_error "same place" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel" "paper square\nthrough .a .a\n")))

let test_eval_undefined_point () =
  expect_error "undefined" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .z\n")))

let test_eval_parallel_cross () =
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --h1: through .a .b\n\
               --h2: through .d .c\n\
               .x: cross --h1 --h2\n")))

let read_example name =
  In_channel.with_open_text ("../../../examples/" ^ name) In_channel.input_all

let test_e2e_inline_equiv () =
  (* inline operands produce the same crease geometry as the named-binding
     equivalent; beloch:edges sources differ (name vs inline text) so we
     compare only the structural FOLD fields *)
  let geom j =
    let open Yojson.Safe.Util in
    ( j |> member "vertices_coords",
      j |> member "edges_vertices",
      j |> member "edges_assignment",
      j |> member "faces_vertices" )
  in
  let named =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\n\
       --d1: through .a .c\n\
       --d2: through .b .d\n\
       .m: cross --d1 --d2\n\
       map .a onto .m\n"
  in
  let inline =
    Beloch.fold_string ~filename:"t.bel"
      "paper square\n\
       --d1: through .a .c\n\
       --d2: through .b .d\n\
       map .a onto .(--d1 --d2)\n"
  in
  Alcotest.(check bool)
    "inline cross-point matches the named binding" true
    (geom named = geom inline)

let test_e2e_inline_error () =
  (* an inline line through one repeated point has no direction *)
  expect_error "same place" (fun () ->
      Beloch.fold_string ~filename:"t.bel"
        "paper square\nperp --(.a .a) through .b\n")

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
  expect_error "same place" (fun () ->
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

let test_parse_map_onto_line () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l1: through .a .b\n--l2: through .a .d\nmap .c onto --l1 perp --l2\n"
  in
  match prog with
  | [
   Ast.Crease (Some "l1", Ast.Through _, _, _);
   Ast.Crease (Some "l2", Ast.Through _, _, _);
   Ast.Crease
     ( None,
       Ast.MapOntoLine
         (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "l1"; _ }, Ast.LNamed { cname = "l2"; _ }),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-onto-line"

let test_parse_map_onto_line_inline () =
  match
    Beloch.parse ~filename:"t.bel"
      "paper square\n--l2: through .a .d\nmap .c onto --(.a .b) perp --l2\n"
  with
  | [
   _;
   Ast.Crease
     (None, Ast.MapOntoLine (Ast.PNamed { name = "c"; _ }, Ast.LThrough _, Ast.LNamed { cname = "l2"; _ }), _, _);
  ] ->
      ()
  | _ -> Alcotest.fail "expected an inline target line in map-onto-line"

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
         ( Ast.LNamed { cname = "v"; _ },
           Ast.LNamed { cname = "h"; _ },
           Some (Ast.PNamed { name = "a"; _ }) ),
       _,
       _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for bisect"

let test_parse_map_through () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d: through .a .b\nmap .c onto --d through .a\n"
  in
  match prog with
  | [
   Ast.Crease (Some "d", Ast.Through _, _, _);
   Ast.Crease
     ( None,
       Ast.MapThrough
         (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "d"; _ },
          Ast.PNamed { name = "a"; _ }, None),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through"

let test_parse_map_through_toward () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\n--d: through .a .b\nmap .c onto --d through .a toward .b\n"
  in
  match prog with
  | [
   Ast.Crease (Some "d", Ast.Through _, _, _);
   Ast.Crease
     ( None,
       Ast.MapThrough
         (Ast.PNamed { name = "c"; _ }, Ast.LNamed { cname = "d"; _ },
          Ast.PNamed { name = "a"; _ }, Some (Ast.PNamed { name = "b"; _ })),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through-toward"

(* spec Test 7: axiom 6 composes with an inline line operand --(.a .b) *)
let test_parse_map_through_inline () =
  let prog =
    Beloch.parse ~filename:"t.bel"
      "paper square\nmap .c onto --(.a .b) through .d\n"
  in
  match prog with
  | [
   Ast.Crease
     ( None,
       Ast.MapThrough
         ( Ast.PNamed { name = "c"; _ },
           Ast.LThrough (Ast.PNamed { name = "a"; _ }, Ast.PNamed { name = "b"; _ }, _),
           Ast.PNamed { name = "d"; _ }, None ),
       _, _ );
  ] ->
      ()
  | _ -> Alcotest.fail "unexpected AST shape for map-through inline operand"

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
       Some
         {
           moving = Some (Ast.PNamed { name = "a"; _ });
           direction = Ast.Mountain;
         },
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

let test_eval_bisect_errors () =
  expect_error "identical" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --x: through .a .c\n\
               --y: through .a .c\n\
               map --x onto --y toward .b\n")));
  expect_error "ambiguous" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --v: map .a onto .b\n\
               --h: map .b onto .c\n\
               map --v onto --h\n")));
  expect_error "on a fold line" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --d: through .a .c\n\
               --h: map .b onto .c\n\
               map --d onto --h toward .a\n")))

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

let test_parse_flip () =
  match Beloch.parse ~filename:"t.bel" "paper square\nflip\n" with
  | [ Ast.Flip _ ] -> ()
  | _ -> Alcotest.fail "expected a single Flip statement"

let test_e2e_flip_mountain () =
  (* turn the blank sheet over, then a valley command folds a MOUNTAIN *)
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\nflip\n@map .a onto .b moving .a\n")
  in
  Alcotest.(check int)
    "fold after flip is a mountain" 1
    (count_assign Fold_state.M fd.Eval.creases);
  Alcotest.(check int)
    "and not a valley" 0
    (count_assign Fold_state.V fd.Eval.creases);
  (* without the flip the same fold is a valley *)
  let fd2 =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .a onto .b moving .a\n")
  in
  Alcotest.(check int)
    "without flip it is a valley" 1
    (count_assign Fold_state.V fd2.Eval.creases)

let test_e2e_flip_cp_counts () =
  (* flip alone leaves the crease pattern geometrically unchanged: same
     vertex/edge/face counts (emit order may differ, so compare counts) *)
  let open Yojson.Safe.Util in
  let counts s =
    let j = Beloch.fold_string ~filename:"t.bel" s in
    ( List.length (member "vertices_coords" j |> to_list),
      List.length (member "edges_vertices" j |> to_list),
      List.length (member "faces_vertices" j |> to_list) )
  in
  Alcotest.(check bool)
    "flip preserves the crease-pattern size" true
    (counts "paper square\n--c: map .a onto .b\n"
    = counts "paper square\n--c: map .a onto .b\nflip\n")

let test_fold_subdivide () =
  (* precrease the flat square along x=1/2: 2 faces, 1 crease record, assign U *)
  let axis = { Geom.a = q 1; b = q 0; c = half } in
  let st, recs = Fold_state.subdivide Fold_state.init_square axis ~prov:None in
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
      ~valley:true ~prov:None
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
      ~prov:None
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

let test_fold_state_flip () =
  (* fold the right half over (valley) -> 2 faces; flipping the sheet inverts
     every face's orientation and reverses the layer order *)
  let st =
    Fold_state.simple_fold Fold_state.init_square
      ~axis:{ Geom.a = q 1; b = q 0; c = half }
      ~move_side:1 ~valley:true
  in
  let n = Array.length st.Fold_state.faces in
  let det_before =
    Array.map
      (fun (f : Fold_state.face) -> Isometry.det_sign f.Fold_state.iso)
      st.Fold_state.faces
  in
  let fl = Fold_state.flip st in
  Alcotest.(check int)
    "face count preserved" n
    (Array.length fl.Fold_state.faces);
  Array.iteri
    (fun i (f : Fold_state.face) ->
      Alcotest.(check int)
        "det flipped and order reversed"
        (-det_before.(n - 1 - i))
        (Isometry.det_sign f.Fold_state.iso))
    fl.Fold_state.faces

let test_fold_state_flip_involution () =
  let st =
    Fold_state.simple_fold Fold_state.init_square
      ~axis:{ Geom.a = q 1; b = q 0; c = half }
      ~move_side:1 ~valley:true
  in
  let twice = Fold_state.flip (Fold_state.flip st) in
  Alcotest.(check bool)
    "flip twice restores .a's table position" true
    (Geom.point_equal
       (Fold_state.table_position st (pt 0 0))
       (Fold_state.table_position twice (pt 0 0)))

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

let test_eval_folded_half () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .b onto .a moving .b\n")
  in
  Alcotest.(check int)
    "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int)
    "one valley record" 1
    (count_assign Fold_state.V fd.Eval.creases);
  (* .b lands exactly on .a = (0,0) *)
  Alcotest.(check bool)
    ".b maps onto .a" true
    (Geom.point_equal
       (Fold_state.table_position fd.Eval.state (pt 1 0))
       (pt 0 0))

let test_eval_folded_precrease () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\nmap .a onto .c\n")
  in
  Alcotest.(check int)
    "two faces" 2
    (Array.length fd.Eval.state.Fold_state.faces);
  Alcotest.(check int)
    "one U record" 1
    (count_assign Fold_state.U fd.Eval.creases)

let test_eval_folded_moving_required () =
  expect_error "moving" (fun () ->
      Eval.eval_folded
        (Beloch.parse ~filename:"t.bel"
           "paper square\n--d: through .a .c\n@perp --d through .b\n"))

let test_eval_folded_quarter_accordion () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .b onto .a moving .b\n@map .d onto .a moving .d\n")
  in
  Alcotest.(check int)
    "four faces after quarter fold" 4
    (Array.length fd.Eval.state.Fold_state.faces);
  (* second fold cuts two layers of alternating orientation -> one V, one M *)
  Alcotest.(check int)
    "an accordion mountain appears" 1
    (count_assign Fold_state.M fd.Eval.creases)

let test_eval_map_onto_line_parallel () =
  (* l1 = bottom edge (a-b), l2 = top edge (d-c): parallel ⟹ no fold *)
  expect_error "parallel" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --l1: through .a .b\n\
               --l2: through .d .c\n\
               map .c onto --l1 perp --l2\n")))

let test_eval_map_onto_line_ok () =
  (* l1 = bottom edge (y=0), l2 = left edge (x=0); project corner c=(1,1).
     c moves parallel to l2 (vertically) onto y=0 ⟹ Q=(1,0);
     crease = perp-bisector of (1,1)-(1,0) = line y=1/2.
     Smoke-test the eval path, then verify the crease geometry. *)
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          --l1: through .a .b\n\
          --l2: through .a .d\n\
          map .c onto --l1 perp --l2\n")
  in
  (* The crease record's endpoints lie on the crease line; reconstruct and test
     that (0,1/2) and (1,1/2) are on it. *)
  match fd.Eval.creases with
  | [] -> Alcotest.fail "expected at least one crease record"
  | cr :: _ ->
      let c = Geom.line_through cr.Fold_state.ra cr.Fold_state.rb in
      let on (p : Geom.point) =
        Num.equal
          (Num.add (Num.mul c.Geom.a p.Geom.x) (Num.mul c.Geom.b p.Geom.y))
          c.Geom.c
      in
      Alcotest.(check bool)
        "axiom-4 crease passes through (0,1/2)" true
        (on { Geom.x = q 0; y = half });
      Alcotest.(check bool)
        "axiom-4 crease passes through (1,1/2)" true
        (on { Geom.x = q 1; y = half })

(* axiom 6 e2e: fold .d=(0,1) onto bottom edge (y=0) through pivot .a=(0,0).
   Landings (1,0) and (-1,0); `toward .b` selects (1,0) ⟹ crease y=x (the main
   diagonal), passing through (0,0) and (1,1). *)
let test_eval_map_through_toward () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          --bottom: through .a .b\n\
          map .d onto --bottom through .a toward .b\n")
  in
  match fd.Eval.creases with
  | [] -> Alcotest.fail "expected at least one crease record"
  | cr :: _ ->
      let c = Geom.line_through cr.Fold_state.ra cr.Fold_state.rb in
      let on (p : Geom.point) =
        Num.equal
          (Num.add (Num.mul c.Geom.a p.Geom.x) (Num.mul c.Geom.b p.Geom.y))
          c.Geom.c
      in
      Alcotest.(check bool) "axiom-6 crease through (0,0)" true (on (pt 0 0));
      Alcotest.(check bool) "axiom-6 crease through (1,1)" true (on (pt 1 1))

(* two solutions without `toward` ⟹ ambiguity error mentioning the selector *)
let test_eval_map_through_ambiguous () =
  expect_error "toward" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --bottom: through .a .b\n\
               map .d onto --bottom through .a\n")))

(* p = p' (here both .a, which lies on the line) ⟹ no fold exists *)
let test_eval_map_through_same_point () =
  expect_error "same point" (fun () ->
      ignore
        (Eval.eval_folded
           (Beloch.parse ~filename:"t.bel"
              "paper square\n\
               --bottom: through .a .b\n\
               map .a onto --bottom through .a\n")))

let test_eval_folded_cross_topmost () =
  (* Q2-B: after the diagonal fold the lower-left triangle is 2-layer; crossing
     two precrease lines there must resolve to the top layer, not error *)
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n\
          @map .c onto .a moving .c\n\
          --b: through .a .b\n\
          --v: map .b onto .a\n\
          .mid: cross --b --v\n")
  in
  (* eval completed without an ambiguity error; the --v precrease subdivided
     both layers of the diagonally-folded triangle, so four faces remain *)
  Alcotest.(check int)
    "cross in a folded overlap resolves to the top layer" 4
    (Array.length fd.Eval.state.Fold_state.faces)

let test_emit_folded_frames () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel"
         "paper square\n@map .b onto .a moving .b\n")
  in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  Alcotest.(check string)
    "frame 0 is creasePattern" "creasePattern"
    (json |> member "frame_classes" |> to_list |> List.hd |> to_string);
  let frames = json |> member "file_frames" |> to_list in
  Alcotest.(check int) "one extra frame" 1 (List.length frames);
  let folded = List.hd frames in
  Alcotest.(check string)
    "extra frame is foldedForm" "foldedForm"
    (folded |> member "frame_classes" |> to_list |> List.hd |> to_string);
  Alcotest.(check bool)
    "folded frame inherits" true
    (folded |> member "frame_inherit" |> to_bool);
  (* the single crease is a valley *)
  let assigns =
    json |> member "edges_assignment" |> to_list |> List.map to_string
  in
  Alcotest.(check bool) "has a V crease" true (List.mem "V" assigns);
  Alcotest.(check bool) "has B boundary" true (List.mem "B" assigns);
  (* two overlapping faces -> one faceOrders triple *)
  Alcotest.(check int)
    "one faceOrders triple" 1
    (folded |> member "faceOrders" |> to_list |> List.length)

let test_emit_folded_crease_name () =
  let fd =
    Eval.eval_folded
      (Beloch.parse ~filename:"t.bel" "paper square\n--m: map .a onto .c\n")
  in
  let json = Fold_emit.to_json_folded fd in
  let open Yojson.Safe.Util in
  let names =
    json |> member "beloch:edges" |> to_list
    |> List.filter_map (function
      | `Null -> None
      | e -> Some (e |> member "name"))
  in
  Alcotest.(check bool)
    "crease carries name m" true
    (List.exists (fun n -> n = `String "m") names)

let test_e2e_fold_half () =
  let json =
    Beloch.fold_string ~filename:"fold-half.bel" (read_example "fold-half.bel")
  in
  let open Yojson.Safe.Util in
  Alcotest.(check string)
    "frame 0 creasePattern" "creasePattern"
    (json |> member "frame_classes" |> to_list |> List.hd |> to_string);
  Alcotest.(check int)
    "a foldedForm frame is present" 1
    (json |> member "file_frames" |> to_list |> List.length);
  let assigns =
    json |> member "edges_assignment" |> to_list |> List.map to_string
  in
  Alcotest.(check bool)
    "the fold crease is a valley" true (List.mem "V" assigns)

let test_e2e_fold_quarter () =
  let json =
    Beloch.fold_string ~filename:"fold-quarter.bel"
      (read_example "fold-quarter.bel")
  in
  let open Yojson.Safe.Util in
  let folded = json |> member "file_frames" |> to_list |> List.hd in
  (* four layers -> overlapping pairs -> several faceOrders triples *)
  Alcotest.(check bool)
    "faceOrders present for the folded stack" true
    (List.length (folded |> member "faceOrders" |> to_list) > 0);
  let assigns =
    json |> member "edges_assignment" |> to_list |> List.map to_string
  in
  Alcotest.(check bool)
    "accordion produced a mountain crease" true (List.mem "M" assigns)

let test_isometry_inverse_rotation () =
  (* compose two distinct reflections -> a rotation (det +1, not self-inverse);
     inverse must still undo it *)
  let r1 = Isometry.reflect_across_line { Geom.a = q 1; b = q 0; c = half } in
  let r2 = Isometry.reflect_across_line { Geom.a = q 0; b = q 1; c = half } in
  let rot = Isometry.compose r1 r2 in
  let inv = Isometry.inverse rot in
  Alcotest.(check int)
    "composed reflections give a rotation" 1 (Isometry.det_sign rot);
  Alcotest.(check bool)
    "inverse undoes the rotation" true
    (Geom.point_equal
       (Isometry.apply_point inv (Isometry.apply_point rot (pt 3 5)))
       (pt 3 5))

let test_clip_on_vertex () =
  (* clip the unit square by its own diagonal a-c (x = y): the line passes
     exactly through two vertices; each half is a triangle of 3 vertices *)
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let diag = Geom.line_through (pt 0 0) (pt 1 1) in
  Alcotest.(check int)
    "lower triangle has 3 vertices" 3
    (Array.length (Geom.clip_convex_halfplane diag 1 sq));
  Alcotest.(check int)
    "upper triangle has 3 vertices" 3
    (Array.length (Geom.clip_convex_halfplane diag (-1) sq))

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
          Alcotest.test_case "project onto line" `Quick test_project_basic;
          Alcotest.test_case "project parallel none" `Quick test_project_parallel_none;
          Alcotest.test_case "project point on l1" `Quick test_project_on_l1;
          Alcotest.test_case "parallel lines" `Quick test_parallel_lines;
          Alcotest.test_case "point in unit square" `Quick test_in_unit_square;
          Alcotest.test_case "clip diagonal" `Quick test_clip_diagonal;
          Alcotest.test_case "segment intersection" `Quick
            test_segment_intersection_center;
          Alcotest.test_case "segments do not touch" `Quick
            test_segment_no_touch;
          Alcotest.test_case "circle line two" `Quick test_circle_line_two;
          Alcotest.test_case "beloch two solutions" `Quick test_beloch_two_solutions;
          Alcotest.test_case "beloch tangent" `Quick test_beloch_tangent;
          Alcotest.test_case "beloch out of reach" `Quick test_beloch_out_of_reach;
          Alcotest.test_case "beloch p on line" `Quick test_beloch_p_on_line_dropped;
        ] );
      ( "fold_clip",
        [
          Alcotest.test_case "half-plane clip" `Quick test_clip_halfplane;
          Alcotest.test_case "clip all or nothing" `Quick
            test_clip_halfplane_all_or_nothing;
          Alcotest.test_case "point in convex polygon" `Quick
            test_in_convex_polygon;
          Alcotest.test_case "clip through vertices" `Quick test_clip_on_vertex;
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
          Alcotest.test_case "flip parses" `Quick test_parse_flip;
          Alcotest.test_case "parse map onto line" `Quick test_parse_map_onto_line;
          Alcotest.test_case "parse map onto line inline" `Quick test_parse_map_onto_line_inline;
          Alcotest.test_case "parse map through" `Quick test_parse_map_through;
          Alcotest.test_case "parse map through toward" `Quick
            test_parse_map_through_toward;
          Alcotest.test_case "parse map through inline" `Quick
            test_parse_map_through_inline;
          Alcotest.test_case "inline line operand" `Quick test_parse_inline_line;
          Alcotest.test_case "nested inline operand" `Quick
            test_parse_inline_point_nested;
        ] );
      ( "eval",
        [
          Alcotest.test_case "identical points" `Quick
            test_eval_identical_points;
          Alcotest.test_case "undefined point" `Quick test_eval_undefined_point;
          Alcotest.test_case "parallel cross" `Quick test_eval_parallel_cross;
          Alcotest.test_case "bisect errors" `Quick test_eval_bisect_errors;
          Alcotest.test_case "map through ambiguous" `Quick
            test_eval_map_through_ambiguous;
          Alcotest.test_case "map through same point" `Quick
            test_eval_map_through_same_point;
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
          Alcotest.test_case "map through toward selects diagonal" `Quick
            test_eval_map_through_toward;
          Alcotest.test_case "fold half end-to-end" `Quick test_e2e_fold_half;
          Alcotest.test_case "fold quarter accordion" `Quick
            test_e2e_fold_quarter;
          Alcotest.test_case "flip makes a mountain" `Quick
            test_e2e_flip_mountain;
          Alcotest.test_case "flip keeps the CP size" `Quick
            test_e2e_flip_cp_counts;
          Alcotest.test_case "inline equals named" `Quick test_e2e_inline_equiv;
          Alcotest.test_case "inline off-paper errors" `Quick
            test_e2e_inline_error;
        ] );
      ( "geom2",
        [
          Alcotest.test_case "ccw order" `Quick test_ccw_order;
          Alcotest.test_case "signed area" `Quick test_signed_area;
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
          Alcotest.test_case "inverse of a rotation" `Quick
            test_isometry_inverse_rotation;
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
          Alcotest.test_case "flip det + layer reversal" `Quick
            test_fold_state_flip;
          Alcotest.test_case "flip is an involution" `Quick
            test_fold_state_flip_involution;
        ] );
      ( "fold_geom2",
        [
          Alcotest.test_case "convex overlap" `Quick test_convex_overlap;
          Alcotest.test_case "on segment" `Quick test_on_segment;
        ] );
      ( "eval_folded",
        [
          Alcotest.test_case "half fold" `Quick test_eval_folded_half;
          Alcotest.test_case "precrease subdivide" `Quick
            test_eval_folded_precrease;
          Alcotest.test_case "moving required" `Quick
            test_eval_folded_moving_required;
          Alcotest.test_case "quarter accordion" `Quick
            test_eval_folded_quarter_accordion;
          Alcotest.test_case "cross resolves to top layer" `Quick
            test_eval_folded_cross_topmost;
          Alcotest.test_case "map onto line parallel error" `Quick test_eval_map_onto_line_parallel;
          Alcotest.test_case "map onto line evaluates" `Quick test_eval_map_onto_line_ok;
        ] );
      ( "emit_folded",
        [
          Alcotest.test_case "dual frames" `Quick test_emit_folded_frames;
          Alcotest.test_case "crease name preserved" `Quick
            test_emit_folded_crease_name;
        ] );
    ]
