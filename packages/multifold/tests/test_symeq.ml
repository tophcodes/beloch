(* Tests for Symeq: symbolic two-fold alignment equations [alperin2006, §3–4].
   Cross-checks the symbolic reflection formulas against Beloch's exact
   geometry (Geom), verifies the involution F∘F = id at rational fold lines,
   and spot-checks assembled alignment equations on constructed solutions. *)

open Multifold
open Alignment
module M = Beloch.Mpoly
module Geom = Beloch.Geom
module Num = Beloch.Num

let q = Q.of_string
let al k s = Alignment.{ kind = k; suffix = s }

(* Full evaluation of a sparse Mpoly at a rational point (one value per
   variable). Mpoly.specialize returns a univariate coefficient array, so a
   plain fold over the term list is the direct way to evaluate completely. *)
let eval (p : M.t) (vals : Q.t array) : Q.t =
  List.fold_left
    (fun acc (m, c) ->
      let t = ref c in
      Array.iteri
        (fun i e ->
          for _ = 1 to e do
            t := Q.mul !t vals.(i)
          done)
        m;
      Q.add acc !t)
    Q.zero p

(* (X,Y) line representation [alperin2006, Def. 2] to Geom: Xx + Yy + 1 = 0
   is ax + by = c with a = X, b = Y, c = -1. *)
let geom_line ((lx, ly) : Q.t * Q.t) : Geom.line =
  { Geom.a = Num.of_q lx; b = Num.of_q ly; c = Num.of_int (-1) }

let gpoint ((px, py) : Q.t * Q.t) : Geom.point =
  { Geom.x = Num.of_q px; y = Num.of_q py }

(* All test data is rational, so Geom stays on the Num.Rat fast path. *)
let num_q (n : Num.t) : Q.t =
  match n with Num.Rat r -> r | _ -> Alcotest.fail "expected rational Num"

(* Geom line ax + by = c back to the (X,Y) representation: divide ax+by-c=0
   by -c, giving X = -a/c, Y = -b/c. Requires c <> 0 (line not through the
   origin), which holds for generic data. *)
let rep_of_geom_line (l : Geom.line) : Q.t * Q.t =
  let a = num_q l.Geom.a and b = num_q l.Geom.b and c = num_q l.Geom.c in
  if Q.equal c Q.zero then Alcotest.fail "line through origin: no (X,Y) rep";
  (Q.div (Q.neg a) c, Q.div (Q.neg b) c)

(* Three distinct generic rational fold lines for specialization checks. *)
let fold_lines = [ (q "1/3", q "-7/5"); (q "-2", q "9/4"); (q "5/7", q "11/2") ]

(* --- Group 1: reflection formulas vs exact geometry ------------------- *)

(* Brief example: line (X,Y) = (0,-1/2) is y = 2; reflecting (3,5) across
   y = 2 gives (3,-1). *)
let test_reflect_point_example () =
  let num_x, num_y, den =
    Symeq.reflect_point_raw ~nvars:2 ~fold:0 (q "3", q "5")
  in
  let at p = eval p [| q "0"; q "-1/2" |] in
  Alcotest.(check bool) "x" true (Q.equal (Q.div (at num_x) (at den)) (q "3"));
  Alcotest.(check bool) "y" true (Q.equal (Q.div (at num_y) (at den)) (q "-1"))

let test_reflect_point_vs_geom () =
  let points =
    [ (q "3", q "5"); (q "-1/2", q "7/3"); (q "22/7", q "-13/11") ]
  in
  List.iter
    (fun ((fx, fy) as fl) ->
      List.iter
        (fun ((px, py) as p) ->
          let nx, ny, d = Symeq.reflect_point_raw ~nvars:2 ~fold:0 (px, py) in
          let at m = eval m [| fx; fy |] in
          let sx = Q.div (at nx) (at d) and sy = Q.div (at ny) (at d) in
          let g = Geom.reflect_point (geom_line fl) (gpoint p) in
          Alcotest.(check bool) "x" true (Q.equal sx (num_q g.Geom.x));
          Alcotest.(check bool) "y" true (Q.equal sy (num_q g.Geom.y)))
        points)
    fold_lines

(* Folded line vs Geom: reflect two sample points of L, take the line through
   the images, convert back to the (X,Y) representation. *)
let test_reflect_line_vs_geom () =
  let lines = [ (q "2/3", q "-5/4"); (q "-7/2", q "1/6") ] in
  List.iter
    (fun ((fx, fy) as fl) ->
      List.iter
        (fun (lx, ly) ->
          let nX, nY, d = Symeq.reflect_line_raw ~nvars:2 ~fold:0 (lx, ly) in
          let at m = eval m [| fx; fy |] in
          let sX = Q.div (at nX) (at d) and sY = Q.div (at nY) (at d) in
          (* point of L at abscissa t: (t, -(1 + X*t)/Y); needs Y <> 0 *)
          let pt t = gpoint (t, Q.div (Q.neg (Q.add Q.one (Q.mul lx t))) ly) in
          let g = geom_line fl in
          let p1 = Geom.reflect_point g (pt (q "0")) in
          let p2 = Geom.reflect_point g (pt (q "1")) in
          let gX, gY = rep_of_geom_line (Geom.line_through p1 p2) in
          Alcotest.(check bool) "X" true (Q.equal sX gX);
          Alcotest.(check bool) "Y" true (Q.equal sY gY))
        lines)
    fold_lines

(* Involution: folding a line twice across the same fold returns it,
   specialized at three distinct rational fold lines. *)
let test_reflect_line_involution () =
  let lines =
    [ (q "2/3", q "-5/4"); (q "-7/2", q "1/6"); (q "17/13", q "3") ]
  in
  List.iter
    (fun (fx, fy) ->
      let refl (lx, ly) =
        let nX, nY, d = Symeq.reflect_line_raw ~nvars:2 ~fold:0 (lx, ly) in
        let at m = eval m [| fx; fy |] in
        (Q.div (at nX) (at d), Q.div (at nY) (at d))
      in
      List.iter
        (fun (lx, ly) ->
          let lx', ly' = refl (refl (lx, ly)) in
          Alcotest.(check bool) "X" true (Q.equal lx' lx);
          Alcotest.(check bool) "Y" true (Q.equal ly' ly))
        lines)
    fold_lines

(* --- Group 2: equation counts ---------------------------------------- *)

let test_equation_counts_symbolic () =
  List.iter
    (fun a ->
      let eqs = Symeq.equations_of ~nvars:4 ~stream:Symeq.stream_a [ a ] in
      Alcotest.(check int)
        (Alignment.combo_to_symbol [ a ])
        (Alignment.equations a) (List.length eqs);
      (* generic parameters: no equation degenerates to 0 = 0 *)
      List.iter
        (fun e -> Alcotest.(check bool) "nonzero" false (M.is_zero e))
        eqs)
    Alignment.all_twofold

(* --- Group 3: variable occurrence ------------------------------------ *)

let test_var_occurrence_al2a () =
  let eqs = Symeq.equations_of ~nvars:4 ~stream:Symeq.stream_a [ al AL2 A ] in
  List.iter
    (fun e ->
      Alcotest.(check int) "no x_b" 0 (M.degree_in e 2);
      Alcotest.(check int) "no y_b" 0 (M.degree_in e 3))
    eqs

let test_var_occurrence_al5a () =
  match Symeq.equations_of ~nvars:4 ~stream:Symeq.stream_a [ al AL5 A ] with
  | [ e ] ->
      let mentions f =
        M.degree_in e (2 * f) > 0 || M.degree_in e ((2 * f) + 1) > 0
      in
      Alcotest.(check bool) "fold a" true (mentions 0);
      Alcotest.(check bool) "fold b" true (mentions 1)
  | _ -> Alcotest.fail "AL5a: expected exactly 1 equation"

(* --- Group 4: semantic spot-checks on constructed solutions ----------- *)

let solve_eqs combo = Symeq.equations_of ~nvars:4 ~stream:Symeq.stream_a combo

(* AL1: fold lines (1,0) [x = -1, vertical] and (0,1) [y = -1, horizontal]
   are perpendicular, so the equation vanishes; (1,0) and (2,0) are parallel
   distinct verticals, so it must not. *)
let test_al1_semantic () =
  match solve_eqs [ al AL1 Sym ] with
  | [ e ] ->
      Alcotest.(check bool)
        "perpendicular" true
        (Q.equal (eval e [| q "1"; q "0"; q "0"; q "1" |]) Q.zero);
      Alcotest.(check bool)
        "parallel" false
        (Q.equal (eval e [| q "1"; q "0"; q "2"; q "0" |]) Q.zero)
  | _ -> Alcotest.fail "AL1: expected exactly 1 equation"

(* AL5a: F_a(P) on fold line b. Construct a solution: fix fold a, compute the
   image of the stream's point P with Geom, pick fold line b through it. *)
let test_al5a_semantic () =
  let prm, _ =
    Symeq.alignment_params ~stream:Symeq.stream_a ~start:0 (al AL5 A)
  in
  let p =
    match prm.Symeq.points with [ p ] -> p | _ -> Alcotest.fail "params"
  in
  let fx, fy = (q "1/3", q "-7/5") in
  let img = Geom.reflect_point (geom_line (fx, fy)) (gpoint p) in
  let ix = num_q img.Geom.x and iy = num_q img.Geom.y in
  (* fold line b through the image: choose X_b = 2, solve 2*ix + Y_b*iy + 1 = 0 *)
  if Q.equal iy Q.zero then Alcotest.fail "degenerate sample: iy = 0";
  let xb = q "2" in
  let yb = Q.div (Q.neg (Q.add Q.one (Q.mul xb ix))) iy in
  match solve_eqs [ al AL5 A ] with
  | [ e ] ->
      Alcotest.(check bool)
        "vanishes on solution" true
        (Q.equal (eval e [| fx; fy; xb; yb |]) Q.zero);
      Alcotest.(check bool)
        "nonzero off solution" false
        (Q.equal (eval e [| fx; fy; xb; Q.add yb Q.one |]) Q.zero)
  | _ -> Alcotest.fail "AL5a: expected exactly 1 equation"

(* AL8: F_a(P1) = F_b(P2). Construct a solution: fix fold a, let Q1 be the
   image of P1; fold b must map P2 to Q1, i.e. fold b is the perpendicular
   bisector of P2 and Q1. Both equations must vanish there. *)
let test_al8_semantic () =
  let prm, _ =
    Symeq.alignment_params ~stream:Symeq.stream_a ~start:0 (al AL8 Sym)
  in
  let p1, p2 =
    match prm.Symeq.points with
    | [ p1; p2 ] -> (p1, p2)
    | _ -> Alcotest.fail "params"
  in
  let fx, fy = (q "-2", q "9/4") in
  let q1 = Geom.reflect_point (geom_line (fx, fy)) (gpoint p1) in
  let xb, yb = rep_of_geom_line (Geom.perpendicular_bisector (gpoint p2) q1) in
  let eqs = solve_eqs [ al AL8 Sym ] in
  Alcotest.(check int) "2 equations" 2 (List.length eqs);
  List.iter
    (fun e ->
      Alcotest.(check bool)
        "vanishes on solution" true
        (Q.equal (eval e [| fx; fy; xb; yb |]) Q.zero))
    eqs

(* AL10a: the virtual point V = fold line a ∩ L1, folded by b, lies on L2.
   Construct a solution: fix fold a, compute V with Geom, pick a target point
   W on L2, and let fold b be the perpendicular bisector of V and W (so that
   F_b(V) = W ∈ L2). *)
let test_al10a_semantic () =
  let prm, _ =
    Symeq.alignment_params ~stream:Symeq.stream_a ~start:0 (al AL10 A)
  in
  let l1, l2 =
    match prm.Symeq.lines with
    | [ l1; l2 ] -> (l1, l2)
    | _ -> Alcotest.fail "params"
  in
  let fx, fy = (q "5/7", q "11/2") in
  let v =
    match Geom.intersection (geom_line (fx, fy)) (geom_line l1) with
    | Some v -> v
    | None -> Alcotest.fail "degenerate sample: fold a parallel to L1"
  in
  let wx = q "3/2" in
  let wy = Q.div (Q.neg (Q.add Q.one (Q.mul (fst l2) wx))) (snd l2) in
  let xb, yb =
    rep_of_geom_line (Geom.perpendicular_bisector v (gpoint (wx, wy)))
  in
  match solve_eqs [ al AL10 A ] with
  | [ e ] ->
      Alcotest.(check bool)
        "vanishes on solution" true
        (Q.equal (eval e [| fx; fy; xb; yb |]) Q.zero);
      Alcotest.(check bool)
        "nonzero off solution" false
        (Q.equal (eval e [| fx; fy; xb; Q.add yb Q.one |]) Q.zero)
  | _ -> Alcotest.fail "AL10a: expected exactly 1 equation"

let () =
  Alcotest.run "symeq"
    [
      ( "reflect",
        [
          Alcotest.test_case "point example" `Quick test_reflect_point_example;
          Alcotest.test_case "point vs Geom" `Quick test_reflect_point_vs_geom;
          Alcotest.test_case "line vs Geom" `Quick test_reflect_line_vs_geom;
          Alcotest.test_case "line involution" `Quick
            test_reflect_line_involution;
        ] );
      ( "equations",
        [
          Alcotest.test_case "counts for all 17 symbols" `Quick
            test_equation_counts_symbolic;
        ] );
      ( "variables",
        [
          Alcotest.test_case "AL2a only fold-a vars" `Quick
            test_var_occurrence_al2a;
          Alcotest.test_case "AL5a mentions both folds" `Quick
            test_var_occurrence_al5a;
        ] );
      ( "semantics",
        [
          Alcotest.test_case "AL1 perpendicularity" `Quick test_al1_semantic;
          Alcotest.test_case "AL5a constructed solution" `Quick
            test_al5a_semantic;
          Alcotest.test_case "AL8 constructed solution" `Quick test_al8_semantic;
          Alcotest.test_case "AL10a constructed solution" `Quick
            test_al10a_semantic;
        ] );
    ]
