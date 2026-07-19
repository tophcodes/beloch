open Beloch

let q = Num.of_int
let half = Num.of_q (Q.of_ints 1 2)
let pt x y = { Geom.x = q x; y = q y }

(* ---- Geom: lines and intersections ---- *)

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
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  let m = Geom.perpendicular_through l (pt 1 0) in
  let on ln p =
    Num.equal
      (Num.add (Num.mul ln.Geom.a p.Geom.x) (Num.mul ln.Geom.b p.Geom.y))
      ln.Geom.c
  in
  Alcotest.(check bool) "passes through P=(1,0)" true (on m (pt 1 0));
  Alcotest.(check bool) "passes through (0,1)" true (on m (pt 0 1));
  Alcotest.(check bool)
    "normals orthogonal" true
    (Num.equal
       (Num.add (Num.mul l.Geom.a m.Geom.a) (Num.mul l.Geom.b m.Geom.b))
       Num.zero)

let test_project_basic () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 0) (pt 0 1) in
  match Geom.project_crease (pt 0 1) l1 l2 with
  | None -> Alcotest.fail "expected a crease"
  | Some c ->
      let on l (p : Geom.point) =
        Num.equal
          (Num.add (Num.mul l.Geom.a p.Geom.x) (Num.mul l.Geom.b p.Geom.y))
          l.Geom.c
      in
      Alcotest.(check bool) "crease through (0,1/2)" true
        (on c { Geom.x = q 0; y = half });
      Alcotest.(check bool) "crease through (1,1/2)" true
        (on c { Geom.x = q 1; y = half });
      Alcotest.(check bool) "crease ⊥ l2" true
        (Num.sign (Num.add (Num.mul c.Geom.a l2.Geom.a) (Num.mul c.Geom.b l2.Geom.b)) = 0)

let test_project_parallel_none () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 1) (pt 1 1) in
  Alcotest.(check bool) "parallel ⟹ None" true
    (Geom.project_crease (pt 0 2) l1 l2 = None)

let test_project_on_l1 () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 0) (pt 0 1) in
  match Geom.project_crease (pt 0 0) l1 l2 with
  | None -> Alcotest.fail "expected a crease"
  | Some c ->
      let expected = Geom.perpendicular_through l2 (pt 0 0) in
      Alcotest.(check bool) "crease = perp-through-l2 at P" true
        (Num.sign (Num.sub (Num.mul c.Geom.a expected.Geom.b)
                           (Num.mul expected.Geom.a c.Geom.b)) = 0
         && Num.sign (Num.sub (Num.mul c.Geom.a expected.Geom.c)
                              (Num.mul expected.Geom.a c.Geom.c)) = 0)

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
  | Some (p, qq) ->
      let has a = Geom.point_equal p a || Geom.point_equal qq a in
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
  let s1 = (pt 0 0, pt 1 0) in
  let s2 = (pt 0 1, pt 1 1) in
  match Geom.segment_intersection s1 s2 with
  | None -> ()
  | Some _ -> Alcotest.fail "parallel edges must not intersect"

let test_circle_line_two () =
  let d = Geom.line_through (pt 0 0) (pt 1 0) in
  let pts = Geom.circle_line_intersection (pt 0 0) (q 1) d in
  Alcotest.(check int) "two intersections" 2 (List.length pts);
  let has px py =
    List.exists (fun (p : Geom.point) -> Geom.point_equal p (pt px py)) pts
  in
  Alcotest.(check bool) "(1,0) present" true (has 1 0);
  Alcotest.(check bool) "(-1,0) present" true (has (-1) 0)

let test_beloch_two_solutions () =
  let d = Geom.line_through (pt 0 0) (pt 1 0) in
  let creases = Geom.beloch_creases (pt 0 1) d (pt 0 0) in
  Alcotest.(check int) "two creases" 2 (List.length creases);
  List.iter
    (fun c ->
      Alcotest.(check int) "crease through pivot" 0
        (Geom.side_of_line c (pt 0 0));
      Alcotest.(check int) "landing on d" 0
        (Geom.side_of_line d (Geom.reflect_point c (pt 0 1))))
    creases

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

let test_beloch_out_of_reach () =
  let d = Geom.line_through (pt 0 2) (pt 1 2) in
  Alcotest.(check int) "no creases" 0
    (List.length (Geom.beloch_creases (pt 1 0) d (pt 0 0)))

let test_beloch_p_on_line_dropped () =
  let d = Geom.line_through (pt 0 0) (pt 1 0) in
  let creases = Geom.beloch_creases (pt 1 0) d (pt 0 0) in
  Alcotest.(check int) "identity landing dropped" 1 (List.length creases);
  (match creases with
   | [ c ] -> Alcotest.(check int) "crease through pivot" 0 (Geom.side_of_line c (pt 0 0))
   | _ -> Alcotest.fail "expected exactly one crease")

let test_beloch7_lands_on_both () =
  let p = pt 0 2 and qq = pt 2 0 in
  let d = { Geom.a = q 0; b = q 1; c = q 0 } in
  let e = { Geom.a = q 1; b = q 0; c = q 0 } in
  let creases = Geom.beloch7_creases p d qq e in
  Alcotest.(check bool) "at least one crease" true (List.length creases >= 1);
  List.iter
    (fun c ->
      let pim = Geom.reflect_point c p and qim = Geom.reflect_point c qq in
      Alcotest.(check int) "p lands on d" 0 (Geom.side_of_line d pim);
      Alcotest.(check int) "q lands on e" 0 (Geom.side_of_line e qim))
    creases

let test_messer_cube_root () =
  let cC = pt 1 1 in
  let ab = { Geom.a = q 0; b = q 1; c = q 0 } in
  let sS = { Geom.x = Num.of_q (Q.of_ints 2 3); y = q 1 } in
  let pq = { Geom.a = q 1; b = q 0; c = Num.of_q (Q.of_ints 1 3) } in
  match Geom.beloch7_creases cC ab sS pq with
  | [ c ] ->
      let img = Geom.reflect_point c cC in
      Alcotest.(check int) "C lands on AB" 0 (Geom.side_of_line ab img);
      let ac = img.Geom.x in
      let cb = Num.sub (q 1) ac in
      let ratio = Num.div ac cb in
      Alcotest.(check bool) "(AC/CB)^3 = 2 exactly" true
        (Num.equal (Num.mul ratio (Num.mul ratio ratio)) (q 2))
  | creases -> Alcotest.failf "expected one crease, got %d" (List.length creases)

let test_axiom7_irrational_crease_folds_fast () =
  let p = pt 0 1 and qq = pt 1 1 in
  let d = { Geom.a = q 0; b = q 1; c = q 0 } in
  let e = { Geom.a = q 1; b = q 0; c = q 0 } in
  let creases = Geom.beloch7_creases p d qq e in
  Alcotest.(check bool) "at least one crease" true (List.length creases >= 1);
  List.iter
    (fun c ->
      Alcotest.(check int) "p lands on d" 0
        (Geom.side_of_line d (Geom.reflect_point c p));
      Alcotest.(check int) "q lands on e" 0
        (Geom.side_of_line e (Geom.reflect_point c qq)))
    creases

(* ---- Geom2: ccw and area ---- *)

let test_ccw_order () =
  let o = pt 0 0 in
  Alcotest.(check int) "E before N" (-1)
    (Geom.ccw_compare ~center:o (pt 1 0) (pt 0 1));
  Alcotest.(check int) "N before W" (-1)
    (Geom.ccw_compare ~center:o (pt 0 1) (pt (-1) 0));
  Alcotest.(check int) "W before S" (-1)
    (Geom.ccw_compare ~center:o (pt (-1) 0) (pt 0 (-1)));
  Alcotest.(check int) "S after E" 1
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

(* ---- Fold_clip: half-plane clipping ---- *)

let test_clip_halfplane () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let l = { Geom.a = q 1; b = q 0; c = half } in
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
  Alcotest.(check int) "whole square on the -1 side" 4
    (Array.length (Geom.clip_convex_halfplane l (-1) sq));
  Alcotest.(check int) "nothing on the +1 side" 0
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

let test_clip_on_vertex () =
  let sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let diag = Geom.line_through (pt 0 0) (pt 1 1) in
  Alcotest.(check int) "lower triangle has 3 vertices" 3
    (Array.length (Geom.clip_convex_halfplane diag 1 sq));
  Alcotest.(check int) "upper triangle has 3 vertices" 3
    (Array.length (Geom.clip_convex_halfplane diag (-1) sq))

(* ---- Fold_geom: reflect and side ---- *)

let test_reflect_point () =
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
  Alcotest.(check int) "on x=1/2 is 0" 0
    (Geom.side_of_line l { Geom.x = half; y = q 9 })

(* ---- Isometry ---- *)

let test_isometry_basics () =
  let i = Isometry.identity in
  Alcotest.(check bool)
    "identity fixes a point" true
    (Geom.point_equal (Isometry.apply_point i (pt 3 4)) (pt 3 4));
  Alcotest.(check int) "identity det +1" 1 (Isometry.det_sign i)

let test_isometry_reflection () =
  let l = { Geom.a = q 1; b = q 0; c = half } in
  let r = Isometry.reflect_across_line l in
  Alcotest.(check bool)
    "reflection isometry matches reflect_point" true
    (Geom.point_equal
       (Isometry.apply_point r (pt 0 0))
       (Geom.reflect_point l (pt 0 0)));
  Alcotest.(check int) "a reflection has det -1" (-1) (Isometry.det_sign r);
  let rr = Isometry.compose r r in
  Alcotest.(check int) "reflection twice has det +1" 1 (Isometry.det_sign rr);
  Alcotest.(check bool)
    "reflection twice is identity on a point" true
    (Geom.point_equal (Isometry.apply_point rr (pt 0 0)) (pt 0 0))

let test_isometry_inverse () =
  let l = { Geom.a = q 1; b = q 1; c = q 1 } in
  let r = Isometry.reflect_across_line l in
  let inv = Isometry.inverse r in
  let p = pt 2 5 in
  Alcotest.(check bool)
    "inverse undoes apply" true
    (Geom.point_equal (Isometry.apply_point inv (Isometry.apply_point r p)) p)

let test_isometry_inverse_rotation () =
  let r1 = Isometry.reflect_across_line { Geom.a = q 1; b = q 0; c = half } in
  let r2 = Isometry.reflect_across_line { Geom.a = q 0; b = q 1; c = half } in
  let rot = Isometry.compose r1 r2 in
  let inv = Isometry.inverse rot in
  Alcotest.(check int) "composed reflections give a rotation" 1 (Isometry.det_sign rot);
  Alcotest.(check bool)
    "inverse undoes the rotation" true
    (Geom.point_equal
       (Isometry.apply_point inv (Isometry.apply_point rot (pt 3 5)))
       (pt 3 5))

(* ---- Bisect: angle bisectors and midline ---- *)

let test_angle_bisectors () =
  let l1 = Geom.line_through (pt 0 0) (pt 1 0) in
  let l2 = Geom.line_through (pt 0 0) (pt 1 1) in
  match Geom.angle_bisectors l1 l2 with
  | None -> Alcotest.fail "intersecting lines must have bisectors"
  | Some (_, bis_opp) ->
      let s2m1 = Num.sub (Num.sqrt (q 2)) Num.one in
      let p = { Geom.x = q 1; y = s2m1 } in
      let on l =
        Num.sign
          (Num.sub
             (Num.add (Num.mul l.Geom.a p.Geom.x) (Num.mul l.Geom.b p.Geom.y))
             l.Geom.c)
      in
      Alcotest.(check int) "(1,√2−1) on the 22.5° bisector" 0 (on bis_opp)

let test_parallel_midline () =
  let l = Geom.line_through (pt 0 0) (pt 0 1) in
  let r = Geom.line_through (pt 1 0) (pt 1 1) in
  let m = Geom.parallel_midline l r in
  let on px py =
    Num.sign
      (Num.sub (Num.add (Num.mul m.Geom.a px) (Num.mul m.Geom.b py)) m.Geom.c)
  in
  Alcotest.(check int) "(1/2,0) on midline" 0 (on half (q 0));
  Alcotest.(check int) "(1/2,1) on midline" 0 (on half (q 1))

(* ---- Fold_geom2: convex overlap and segment containment ---- *)

let test_convex_overlap () =
  let unit = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |] in
  let shifted_overlap = [| pt 0 0; pt 2 0; pt 2 2; pt 0 2 |] in
  let right_half =
    [| { Geom.x = half; y = q 0 }; pt 1 0; pt 1 1; { Geom.x = half; y = q 1 } |]
  in
  Alcotest.(check bool) "unit overlaps a bigger square covering it" true
    (Geom.convex_overlap unit shifted_overlap);
  Alcotest.(check bool) "unit overlaps its right half" true
    (Geom.convex_overlap unit right_half);
  let far = [| pt 2 0; pt 3 0; pt 3 1; pt 2 1 |] in
  Alcotest.(check bool) "disjoint squares do not overlap" false
    (Geom.convex_overlap unit far);
  let touching = [| pt 1 0; pt 2 0; pt 2 1; pt 1 1 |] in
  Alcotest.(check bool) "edge-touching is not overlap" false
    (Geom.convex_overlap unit touching)

let test_on_segment () =
  let s = (pt 0 0, pt 2 2) in
  Alcotest.(check bool) "midpoint is on the segment" true (Geom.on_segment s (pt 1 1));
  Alcotest.(check bool) "endpoint is on the segment" true (Geom.on_segment s (pt 0 0));
  Alcotest.(check bool) "collinear but outside is not on" false
    (Geom.on_segment s (pt 3 3));
  Alcotest.(check bool) "off the line is not on" false (Geom.on_segment s (pt 1 0))

(* ---- Fold_geom3: line ∩ convex polygon clipping and the strict fold test ---- *)

let unit_sq = [| pt 0 0; pt 1 0; pt 1 1; pt 0 1 |]

let check_segment name expected_p expected_q = function
  | None -> Alcotest.failf "%s: expected a segment, got None" name
  | Some (p, q) ->
      let matches =
        (Geom.point_equal p expected_p && Geom.point_equal q expected_q)
        || (Geom.point_equal p expected_q && Geom.point_equal q expected_p)
      in
      Alcotest.(check bool) name true matches

let test_clip_line_diagonal () =
  let l = Geom.line_through (pt 0 0) (pt 1 1) in
  check_segment "diagonal clips to (0,0)-(1,1)" (pt 0 0) (pt 1 1)
    (Geom.clip_line_to_convex l unit_sq)

let test_clip_line_miss () =
  let l = { Geom.a = q 1; b = q 0; c = q 2 } in
  Alcotest.(check bool) "x=2 misses the unit square" true
    (Geom.clip_line_to_convex l unit_sq = None)

let test_clip_line_corner_touch () =
  let l = { Geom.a = q 1; b = q 1; c = q 2 } in
  Alcotest.(check bool) "x+y=2 touches only the (1,1) corner: zero length" true
    (Geom.clip_line_to_convex l unit_sq = None)

let test_clip_line_edge_collinear () =
  let l = Geom.line_through (pt 0 0) (pt 1 0) in
  check_segment "y=0 clips to the bottom edge (0,0)-(1,0)" (pt 0 0) (pt 1 0)
    (Geom.clip_line_to_convex l unit_sq)

let test_clip_line_horizontal () =
  let l = { Geom.a = q 0; b = q 1; c = half } in
  check_segment "y=1/2 clips to (0,1/2)-(1,1/2)" { Geom.x = q 0; y = half }
    { Geom.x = q 1; y = half }
    (Geom.clip_line_to_convex l unit_sq)

let test_line_cuts_polygon_true () =
  let l = { Geom.a = q 0; b = q 1; c = half } in
  Alcotest.(check bool) "y=1/2 cuts the square" true
    (Geom.line_cuts_polygon l unit_sq)

let test_line_cuts_polygon_edge_false () =
  let l = Geom.line_through (pt 0 0) (pt 1 0) in
  Alcotest.(check bool) "y=0 (an edge) does not cut" false
    (Geom.line_cuts_polygon l unit_sq)

let test_line_cuts_polygon_corner_false () =
  let l = { Geom.a = q 1; b = q 1; c = q 2 } in
  Alcotest.(check bool) "x+y=2 (corner touch) does not cut" false
    (Geom.line_cuts_polygon l unit_sq)

let test_line_cuts_polygon_miss_false () =
  let l = { Geom.a = q 1; b = q 0; c = q 2 } in
  Alcotest.(check bool) "x=2 (misses) does not cut" false
    (Geom.line_cuts_polygon l unit_sq)

let () =
  Alcotest.run "beloch-geom"
    [
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
          Alcotest.test_case "segments do not touch" `Quick test_segment_no_touch;
          Alcotest.test_case "circle line two" `Quick test_circle_line_two;
          Alcotest.test_case "beloch two solutions" `Quick test_beloch_two_solutions;
          Alcotest.test_case "beloch tangent" `Quick test_beloch_tangent;
          Alcotest.test_case "beloch out of reach" `Quick test_beloch_out_of_reach;
          Alcotest.test_case "beloch p on line" `Quick test_beloch_p_on_line_dropped;
          Alcotest.test_case "beloch7 lands on both lines" `Quick
            test_beloch7_lands_on_both;
          Alcotest.test_case "beloch7 irrational crease folds fast" `Quick
            test_axiom7_irrational_crease_folds_fast;
          Alcotest.test_case "messer cube root of two (AC/CB = cbrt 2)" `Quick
            test_messer_cube_root;
        ] );
      ( "geom2",
        [
          Alcotest.test_case "ccw order" `Quick test_ccw_order;
          Alcotest.test_case "signed area" `Quick test_signed_area;
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
      ( "bisect",
        [
          Alcotest.test_case "angle bisectors" `Quick test_angle_bisectors;
          Alcotest.test_case "parallel midline" `Quick test_parallel_midline;
        ] );
      ( "fold_geom2",
        [
          Alcotest.test_case "convex overlap" `Quick test_convex_overlap;
          Alcotest.test_case "on segment" `Quick test_on_segment;
        ] );
      ( "fold_geom3",
        [
          Alcotest.test_case "clip line: diagonal" `Quick test_clip_line_diagonal;
          Alcotest.test_case "clip line: miss" `Quick test_clip_line_miss;
          Alcotest.test_case "clip line: corner touch is zero length" `Quick
            test_clip_line_corner_touch;
          Alcotest.test_case "clip line: edge-collinear" `Quick
            test_clip_line_edge_collinear;
          Alcotest.test_case "clip line: horizontal" `Quick
            test_clip_line_horizontal;
          Alcotest.test_case "line cuts polygon: true" `Quick
            test_line_cuts_polygon_true;
          Alcotest.test_case "line cuts polygon: edge is not a cut" `Quick
            test_line_cuts_polygon_edge_false;
          Alcotest.test_case "line cuts polygon: corner touch is not a cut" `Quick
            test_line_cuts_polygon_corner_false;
          Alcotest.test_case "line cuts polygon: miss is not a cut" `Quick
            test_line_cuts_polygon_miss_false;
        ] );
    ]
