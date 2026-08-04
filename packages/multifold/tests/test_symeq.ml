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

(* --- Group 2b: cleared denominators ------------------------------------ *)

(* [equations_of] must be exactly the equations component of
   [equations_denoms_of], and each alignment must clear exactly the
   denominators its reflections produce: none for the incidence-only kinds
   (AL1-AL3, which reflect nothing), one per single reflected object
   (AL4-AL6), and two for the kinds that reflect two objects or an
   intersection plus a reflection (AL7-AL10). *)
let poly_list_equal (l1 : M.t list) (l2 : M.t list) : bool =
  List.length l1 = List.length l2
  && List.for_all2 (fun a b -> M.is_zero (M.sub a b)) l1 l2

let expected_denom_count : Alignment.kind -> int = function
  | AL1 | AL2 | AL3 -> 0
  | AL4 | AL5 | AL6 -> 1
  | AL7 | AL8 | AL9 | AL10 -> 2

let test_equations_denoms_of () =
  List.iter
    (fun a ->
      let name = Alignment.combo_to_symbol [ a ] in
      let eqs, denoms =
        Symeq.equations_denoms_of ~nvars:4 ~stream:Symeq.stream_a [ a ]
      in
      let eqs' = Symeq.equations_of ~nvars:4 ~stream:Symeq.stream_a [ a ] in
      Alcotest.(check bool)
        (name ^ ": matches equations_of")
        true (poly_list_equal eqs eqs');
      Alcotest.(check int)
        (name ^ ": denom count")
        (expected_denom_count a.Alignment.kind)
        (List.length denoms);
      List.iter
        (fun d ->
          Alcotest.(check bool) (name ^ ": denom nonzero") false (M.is_zero d))
        denoms)
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

(* Reflect a line (X,Y) rep across a Geom fold line: reflect two sample
   points of it, take the line through the images, and convert back — same
   technique as [test_reflect_line_vs_geom]. Requires the line's
   Y-coefficient nonzero (needed to parametrize sample points). *)
let geom_reflect_line (fold : Geom.line) ((lx, ly) : Q.t * Q.t) : Q.t * Q.t =
  if Q.equal ly Q.zero then Alcotest.fail "degenerate sample: ly = 0";
  let pt t = gpoint (t, Q.div (Q.neg (Q.add Q.one (Q.mul lx t))) ly) in
  let p1 = Geom.reflect_point fold (pt (q "0")) in
  let p2 = Geom.reflect_point fold (pt (q "1")) in
  rep_of_geom_line (Geom.line_through p1 p2)

(* True if at least one of [eqs] is nonzero when evaluated at [vals] — the
   negative leg for alignments with more than one equation, where "off the
   solution" only requires the combination to fail, not every equation. *)
let some_nonzero (eqs : M.t list) (vals : Q.t array) : bool =
  List.exists (fun e -> not (Q.equal (eval e vals) Q.zero)) eqs

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

(* AL4a: F_a(L) <-> L_b. Construct a solution: fix fold a, compute the image
   of the stream's line L with Geom, and let fold line b be exactly that
   image line. *)
let test_al4a_semantic () =
  let prm, _ =
    Symeq.alignment_params ~stream:Symeq.stream_a ~start:0 (al AL4 A)
  in
  let l =
    match prm.Symeq.lines with [ l ] -> l | _ -> Alcotest.fail "params"
  in
  let fx, fy = (q "1/3", q "-7/5") in
  let xb, yb = geom_reflect_line (geom_line (fx, fy)) l in
  let eqs = solve_eqs [ al AL4 A ] in
  Alcotest.(check int) "2 equations" 2 (List.length eqs);
  List.iter
    (fun e ->
      Alcotest.(check bool)
        "vanishes on solution" true
        (Q.equal (eval e [| fx; fy; xb; yb |]) Q.zero))
    eqs;
  Alcotest.(check bool)
    "perturbed fold breaks at least one equation" true
    (some_nonzero eqs [| fx; fy; xb; Q.add yb Q.one |])

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
    eqs;
  Alcotest.(check bool)
    "perturbed fold breaks at least one equation" true
    (some_nonzero eqs [| fx; fy; xb; Q.add yb Q.one |])

(* AL9 [F_a(L1) <-> F_b(L2)]: unlike AL5a/AL8/AL10a, both given lines are
   baked into the equations as constants pulled from the stream, so no choice
   of fold pair generally satisfies the alignment for the stream's specific
   L1 *and* L2 — the axis mapping one given line onto another is generically
   an angle bisector, i.e. irrational (involves sqrt(a²+b²)), so it can't be
   constructed as an exact rational fold line here. Instead: fix BOTH folds
   concretely (rational, so every reflection below stays exact), take the
   stream's L1, and use our own L2 := F_b(F_a(L1)) — built directly from
   [Symeq.reflect_line_raw] and the same cross-multiplied equality
   [Symeq.eq_pair] uses internally, rather than through [Symeq.equations_of]
   (which would insist on the stream's L2, not this one). *)
let test_al9_semantic () =
  let prm, _ =
    Symeq.alignment_params ~stream:Symeq.stream_a ~start:0 (al AL9 Sym)
  in
  let l1 =
    match prm.Symeq.lines with l1 :: _ -> l1 | [] -> Alcotest.fail "params"
  in
  let f0x, f0y = (q "1/3", q "-7/5") and f1x, f1y = (q "-2", q "9/4") in
  let fa_l1 = geom_reflect_line (geom_line (f0x, f0y)) l1 in
  let l2 = geom_reflect_line (geom_line (f1x, f1y)) fa_l1 in
  let n1X, n1Y, d1 = Symeq.reflect_line_raw ~nvars:4 ~fold:0 l1 in
  let n2X, n2Y, d2 = Symeq.reflect_line_raw ~nvars:4 ~fold:1 l2 in
  let eqs =
    [ M.sub (M.mul n1X d2) (M.mul n2X d1); M.sub (M.mul n1Y d2) (M.mul n2Y d1) ]
  in
  let vals = [| f0x; f0y; f1x; f1y |] in
  List.iter
    (fun e ->
      Alcotest.(check bool)
        "vanishes on solution" true
        (Q.equal (eval e vals) Q.zero))
    eqs;
  Alcotest.(check bool)
    "perturbed fold breaks at least one equation" true
    (some_nonzero eqs [| f0x; f0y; f1x; Q.add f1y Q.one |])

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
          Alcotest.test_case "cleared denominators" `Quick
            test_equations_denoms_of;
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
          Alcotest.test_case "AL4a constructed solution" `Quick
            test_al4a_semantic;
          Alcotest.test_case "AL5a constructed solution" `Quick
            test_al5a_semantic;
          Alcotest.test_case "AL8 constructed solution" `Quick test_al8_semantic;
          Alcotest.test_case "AL9 constructed solution" `Quick test_al9_semantic;
          Alcotest.test_case "AL10a constructed solution" `Quick
            test_al10a_semantic;
        ] );
    ]
