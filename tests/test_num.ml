open Beloch

let n = Num.of_int
let qp l = Poly.of_list (List.map Q.of_int l)

(* ---- Num: basic arithmetic ---- *)

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
  let lhs = Num.sqrt (n 8) and rhs = Num.mul (n 2) (Num.sqrt (n 2)) in
  Alcotest.(check bool) "sqrt8 = 2 sqrt2" true (Num.equal lhs rhs);
  Alcotest.(check int) "sqrt8 - 2 sqrt2 = 0" 0 (Num.sign (Num.sub lhs rhs))

let test_num_distributive () =
  let a = Num.sqrt (n 2) and b = Num.sqrt (n 3) and c = Num.one in
  Alcotest.(check bool)
    "distributive" true
    (Num.equal (Num.mul a (Num.add b c)) (Num.add (Num.mul a b) (Num.mul a c)))

let test_num_inv_roundtrip () =
  let x = Num.sub (Num.sqrt (n 2)) (n 3) in
  Alcotest.(check bool)
    "x * (1/x) = 1" true
    (Num.equal (Num.mul x (Num.div Num.one x)) Num.one);
  Alcotest.(check bool) "x / x = 1" true (Num.equal (Num.div x x) Num.one)

let test_num_nested_radical () =
  let inner = Num.add Num.one (Num.sqrt (n 2)) in
  let a = Num.sqrt inner in
  Alcotest.(check bool) "(√(1+√2))² = 1+√2" true (Num.equal (Num.mul a a) inner)

let test_num_termination_guard () =
  let deep =
    Num.sqrt (Num.add Num.one (Num.sqrt (Num.add Num.one (Num.sqrt (n 2)))))
  in
  Alcotest.(check int) "deep nest is positive" 1 (Num.sign deep)

let test_num_to_float () =
  Alcotest.(check bool)
    "to_float sqrt2 ≈ 1.41421" true
    (Float.abs (Num.to_float (Num.sqrt (n 2)) -. 1.4142135623) < 1e-6)

let test_num_cross_field_fast () =
  (* the former >120s cliff: cbrt2 meets sqrt2 (spike: FLINT does this in ~0s) *)
  let cbrt2 =
    match Num.real_roots [| n (-2); Num.zero; Num.zero; Num.one |] with
    | [ r ] -> r
    | _ -> Alcotest.fail "expected one real root for x^3-2"
  in
  let s2 = Num.sqrt (n 2) in
  let t0 = Unix.gettimeofday () in
  let g = Num.add cbrt2 s2 in
  let g2 = Num.mul g g in
  Alcotest.(check int) "g2 > g" 1 (Num.compare g2 g);
  let d = Num.sub g s2 in
  Alcotest.(check bool) "(g - sqrt2)^3 = 2 exactly" true
    (Num.equal (Num.mul (Num.mul d d) d) (n 2));
  Alcotest.(check bool) "1/g * g = 1" true
    (Num.equal (Num.mul (Num.inv g) g) Num.one);
  let dt = Unix.gettimeofday () -. t0 in
  Alcotest.(check bool)
    (Printf.sprintf "cross-field sequence under 1s (took %.3fs)" dt)
    true (dt < 1.0)

(* ---- Num: real_roots ---- *)

let test_num_real_roots_cubic () =
  let coeffs = [| Num.of_int (-1); Num.of_int (-3); Num.zero; Num.one |] in
  let roots = Num.real_roots coeffs in
  Alcotest.(check int) "three real roots" 3 (List.length roots);
  let rec asc = function
    | a :: (b :: _ as r) -> Num.compare a b < 0 && asc r
    | _ -> true
  in
  Alcotest.(check bool) "ascending" true (asc roots);
  List.iter
    (fun x ->
      let v =
        Num.sub
          (Num.sub (Num.mul x (Num.mul x x)) (Num.mul (Num.of_int 3) x))
          Num.one
      in
      Alcotest.(check int) "root vanishes" 0 (Num.sign v))
    roots;
  let largest = List.nth roots 2 in
  Alcotest.(check bool) "largest ≈ 1.8794" true
    (Float.abs (Num.to_float largest -. 1.8793852) < 1e-6)

let test_num_casus_irreducibilis_distinct () =
  let coeffs = [| Num.of_int (-1); Num.of_int (-3); Num.zero; Num.one |] in
  match Num.real_roots coeffs with
  | [ a; b; c ] ->
      Alcotest.(check bool) "a≠b" false (Num.equal a b);
      Alcotest.(check bool) "b≠c" false (Num.equal b c);
      Alcotest.(check bool) "a≠c" false (Num.equal a c)
  | _ -> Alcotest.fail "expected three roots"

let test_real_roots_one_generator () =
  let s2 = Num.sqrt (Num.of_int 2) in
  let roots = Num.real_roots [| Num.neg s2; Num.zero; Num.zero; Num.one |] in
  Alcotest.(check int) "one real root" 1 (List.length roots);
  let v = List.hd roots in
  let v6 = Num.mul (Num.mul v v) (Num.mul (Num.mul v v) (Num.mul v v)) in
  Alcotest.(check bool) "v^6 = 2" true (Num.equal v6 (Num.of_int 2))

let test_real_roots_two_generators () =
  let s2 = Num.sqrt (Num.of_int 2) and s3 = Num.sqrt (Num.of_int 3) in
  let c0 = Num.neg (Num.add s2 s3) in
  let roots = Num.real_roots [| c0; Num.one |] in
  Alcotest.(check int) "one root" 1 (List.length roots);
  let v = List.hd roots in
  let t = Num.sub v s2 in
  Alcotest.(check bool) "(v-√2)^2 = 3" true (Num.equal (Num.mul t t) (Num.of_int 3))

let test_real_roots_casus_irreducibilis_irrational () =
  let s2 = Num.sqrt (Num.of_int 2) in
  let c k = Num.mul s2 (Num.of_int k) in
  let roots = Num.real_roots [| c (-1); c (-3); Num.zero; c 1 |] in
  Alcotest.(check int) "three real roots" 3 (List.length roots);
  List.iter
    (fun z ->
      let z3 = Num.mul z (Num.mul z z) in
      let f = Num.sub (Num.sub z3 (Num.mul (Num.of_int 3) z)) Num.one in
      Alcotest.(check bool) "root of z^3-3z-1" true (Num.equal f Num.zero))
    roots;
  (match roots with
   | [ a; b; c ] ->
       Alcotest.(check bool) "ordered" true (Num.compare a b < 0 && Num.compare b c < 0)
   | _ -> Alcotest.fail "expected 3 roots")

let test_real_roots_rational_cube_root () =
  let roots = Num.real_roots [| Num.of_int (-2); Num.zero; Num.zero; Num.one |] in
  Alcotest.(check int) "one real root" 1 (List.length roots);
  let v = List.hd roots in
  Alcotest.(check bool) "v^3 = 2" true (Num.equal (Num.mul v (Num.mul v v)) (Num.of_int 2))

let test_real_roots_affine_shared_field () =
  let s2 = Num.sqrt (Num.of_int 2) in
  let c0 = Num.neg s2 and c1 = Num.sub Num.one s2 and c2 = Num.one in
  let roots = Num.real_roots [| c0; c1; c2 |] in
  Alcotest.(check int) "two real roots" 2 (List.length roots);
  (match roots with
   | [ a; b ] ->
       Alcotest.(check bool) "first is -1" true (Num.equal a (Num.of_int (-1)));
       Alcotest.(check bool) "second is √2" true (Num.equal b s2)
   | _ -> Alcotest.fail "expected 2 roots")

(* ---- Poly: core arithmetic ---- *)

let test_poly_eval () =
  Alcotest.(check bool) "eval" true
    (Q.equal (Poly.eval (qp [1;2;3]) (Q.of_int 2)) (Q.of_int 17))

let test_poly_add_mul () =
  let p = qp [1;1] and q = qp [-1;1] in
  Alcotest.(check bool) "mul" true
    (Poly.eval (Poly.mul p q) (Q.of_int 3) |> Q.equal (Q.of_int 8));
  Alcotest.(check bool) "add" true
    (Poly.eval (Poly.add p q) (Q.of_int 5) |> Q.equal (Q.of_int 10));
  Alcotest.(check int) "degree of x²-1" 2 (Poly.degree (Poly.mul p q))

let test_poly_derivative () =
  let d = Poly.derivative (qp [1;2;3]) in
  Alcotest.(check bool) "deriv@1=8" true (Q.equal (Poly.eval d Q.one) (Q.of_int 8))

let test_poly_compose () =
  let a = qp [0;0;1] and g = qp [1;1] in
  Alcotest.(check bool) "compose" true
    (Q.equal (Poly.eval (Poly.compose a g) (Q.of_int 2)) (Q.of_int 9))

let test_poly_normalize_zero () =
  Alcotest.(check int) "zero degree -1" (-1) (Poly.degree Poly.zero);
  Alcotest.(check bool) "trailing zeros trimmed" true (Poly.degree (qp [1;2;0;0]) = 1)

let test_poly_divmod () =
  let q, r = Poly.divmod (qp [-1;0;1]) (qp [-1;1]) in
  Alcotest.(check bool) "quotient x+1" true
    (Poly.eval q (Q.of_int 4) |> Q.equal (Q.of_int 5));
  Alcotest.(check bool) "remainder 0" true (Poly.is_zero r)

let test_poly_resultant () =
  Alcotest.(check bool) "Res(x²-2,x²-3)=1" true
    (Q.equal (Poly.resultant (qp [-2;0;1]) (qp [-3;0;1])) Q.one);
  Alcotest.(check bool) "Res(P,P)=0" true
    (Q.equal (Poly.resultant (qp [-2;0;1]) (qp [-2;0;1])) Q.zero)

let test_poly_squarefree () =
  let p = Poly.mul (qp [1;-2;1]) (qp [2;1]) in
  let s = Poly.squarefree_part p in
  Alcotest.(check int) "squarefree degree 2" 2 (Poly.degree s);
  Alcotest.(check bool) "monic" true (Q.equal (Poly.leading s) Q.one);
  Alcotest.(check bool) "still vanishes at 1" true (Q.equal (Poly.eval s Q.one) Q.zero)

let test_poly_sturm_count () =
  let p = qp [-1;-3;0;1] in
  let seq = Poly.sturm_sequence p in
  Alcotest.(check int) "3 real roots in (-10,10]" 3
    (Poly.count_roots_in seq (Q.of_int (-10)) (Q.of_int 10));
  let seq2 = Poly.sturm_sequence (qp [1;0;1]) in
  Alcotest.(check int) "0 real roots" 0
    (Poly.count_roots_in seq2 (Q.of_int (-10)) (Q.of_int 10))

let test_poly_isolate () =
  let p = qp [-1;-3;0;1] in
  let iv = Poly.isolate_roots p in
  Alcotest.(check int) "three isolating intervals" 3 (List.length iv);
  List.iter
    (fun (lo, hi) ->
      Alcotest.(check bool) "sign change in interval" true
        (Poly.sign_at p lo * Poly.sign_at p hi <= 0))
    iv;
  let rec ordered = function
    | (_, h1) :: ((l2, _) :: _ as r) -> Q.compare h1 l2 <= 0 && ordered r
    | _ -> true
  in
  Alcotest.(check bool) "ascending disjoint" true (ordered iv)

let test_poly_sign_variations () =
  Alcotest.(check int) "x²-3x+2 has 2 variations" 2
    (Poly.sign_variations (qp [ 2; -3; 1 ]));
  Alcotest.(check int) "x²+x+1 has 0 variations" 0
    (Poly.sign_variations (qp [ 1; 1; 1 ]));
  Alcotest.(check int) "zeros skipped: x³-1" 1
    (Poly.sign_variations (qp [ -1; 0; 0; 1 ]))

let test_poly_descartes_test () =
  (* p = (x−1)(x−2) on various intervals *)
  let p = qp [ 2; -3; 1 ] in
  Alcotest.(check int) "no root in (3,4)" 0
    (Poly.descartes_test p (Q.of_int 3) (Q.of_int 4));
  Alcotest.(check int) "one root in (1/2,3/2)" 1
    (Poly.descartes_test p (Q.of_string "1/2") (Q.of_string "3/2"))

let test_poly_isolate_close_roots () =
  (* ε-quartic at the hardest rung: two roots ~3·10⁻¹⁰ apart *)
  let eps = Q.of_string "1/20000000000000000000" in
  let p = Poly.of_list [ eps; Q.zero; Q.of_int (-5); Q.zero; Q.one ] in
  let iv = Poly.isolate_roots p in
  Alcotest.(check int) "four isolated roots" 4 (List.length iv)

(* ---- Mpoly ---- *)

let test_mpoly_resultant_constant_free () =
  let nvars = 2 in
  let x = Mpoly.var nvars 0 and y = Mpoly.var nvars 1 in
  let a = Mpoly.sub x y in
  let b = Mpoly.sub (Mpoly.mul y y) (Mpoly.const nvars (Q.of_int 2)) in
  let r = Mpoly.resultant a b 1 in
  let p = Mpoly.to_poly_in r 0 in
  Alcotest.(check int) "deg 2" 2 (Poly.degree p);
  Alcotest.(check bool) "sign change across √2" true
    (Poly.sign_at p (Q.of_string "7/5") * Poly.sign_at p (Q.of_string "3/2") < 0)

let test_mpoly_two_var_elim () =
  let nvars = 3 in
  let x = Mpoly.var nvars 0 and y = Mpoly.var nvars 1 and w = Mpoly.var nvars 2 in
  let p = Mpoly.sub (Mpoly.sub x y) w in
  let my = Mpoly.sub (Mpoly.mul y y) (Mpoly.const nvars (Q.of_int 2)) in
  let mw = Mpoly.sub (Mpoly.mul w w) (Mpoly.const nvars (Q.of_int 3)) in
  let r1 = Mpoly.resultant p my 1 in
  let r2 = Mpoly.resultant r1 mw 2 in
  let poly = Mpoly.to_poly_in r2 0 in
  Alcotest.(check bool) "sign change across √2+√3" true
    (Poly.sign_at poly (Q.of_string "31/10") * Poly.sign_at poly (Q.of_string "32/10") < 0)

(* ---- Field ---- *)

let test_real_roots_returns_field_cube () =
  match Num.real_roots [| Num.of_int (-2); Num.zero; Num.zero; Num.one |] with
  | [ v ] ->
      Alcotest.(check bool) "is Field" true
        (match v with Num.Field _ -> true | _ -> false);
      Alcotest.(check bool) "v³ = 2" true
        (Num.equal (Num.mul v (Num.mul v v)) (Num.of_int 2))
  | _ -> Alcotest.fail "expected one real root"

let test_real_roots_field_and_rat () =
  let roots =
    Num.real_roots [| Num.one; Num.of_int (-3); Num.of_int (-3); Num.one |]
  in
  Alcotest.(check int) "three roots" 3 (List.length roots);
  (match roots with
   | [ a; b; c ] ->
       Alcotest.(check bool) "−1 is Rat" true
         (match a with Num.Rat _ -> true | _ -> false);
       Alcotest.(check bool) "first = −1" true (Num.equal a (Num.of_int (-1)));
       Alcotest.(check bool) "2−√3 is Field" true
         (match b with Num.Field _ -> true | _ -> false);
       Alcotest.(check bool) "2+√3 is Field" true
         (match c with Num.Field _ -> true | _ -> false);
       List.iter (fun t ->
         let f = Num.add (Num.sub (Num.mul t t) (Num.mul (Num.of_int 4) t)) Num.one in
         Alcotest.(check bool) "root of t²−4t+1" true (Num.equal f Num.zero)) [ b; c ]
   | _ -> Alcotest.fail "expected 3 roots")

let test_field_mul_cube () =
  let mu = Poly.of_list [ Q.of_int (-2); Q.zero; Q.zero; Q.one ] in
  let gen = { Num.mu; lo = Q.one; hi = Q.of_int 2 } in
  let alpha = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  let a2 = Num.mul alpha alpha in
  Alcotest.(check bool) "α² is irrational" true
    (Num.sign (Num.sub a2 (Num.of_int 1)) <> 0);
  let a3 = Num.mul a2 alpha in
  Alcotest.(check bool) "α³ = 2 exactly" true (Num.equal a3 (Num.of_int 2))

let test_field_add_canonicalizes () =
  let mu = Poly.of_list [ Q.of_int (-2); Q.zero; Q.zero; Q.one ] in
  let gen = { Num.mu; lo = Q.one; hi = Q.of_int 2 } in
  let alpha = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  Alcotest.(check bool) "α−α = 0" true (Num.equal (Num.sub alpha alpha) Num.zero);
  Alcotest.(check bool) "α+1−1 = α" true
    (Num.equal (Num.sub (Num.add alpha Num.one) Num.one) alpha)

let test_field_sign_and_inv () =
  let mu = Poly.of_list [ Q.of_int (-2); Q.zero; Q.zero; Q.one ] in
  let gen = { Num.mu; lo = Q.one; hi = Q.of_int 2 } in
  let alpha = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  Alcotest.(check int) "sign(α−1)" 1 (Num.sign (Num.sub alpha Num.one));
  Alcotest.(check int) "sign(α−2)" (-1) (Num.sign (Num.sub alpha (Num.of_int 2)));
  Alcotest.(check bool) "α·α⁻¹ = 1" true
    (Num.equal (Num.mul alpha (Num.inv alpha)) Num.one);
  Alcotest.(check (float 1e-9)) "to_float α" 1.2599210498948732 (Num.to_float alpha)

let test_field_compare () =
  let mu = Poly.of_list [ Q.one; Q.of_int (-4); Q.one ] in
  let gen = { Num.mu; lo = Q.zero; hi = Q.one } in
  let beta = Num.Field { gen; coords = Poly.of_list [ Q.zero; Q.one ] } in
  Alcotest.(check bool) "β > 1/4" true
    (Num.compare beta (Num.of_q (Q.of_ints 1 4)) > 0);
  Alcotest.(check bool) "β < 1/3" true
    (Num.compare beta (Num.of_q (Q.of_ints 1 3)) < 0)

(* ---- Axiom 7 trisection cubic ---- *)

let test_axiom7_trisection_cubic () =
  let roots =
    Num.real_roots
      [| Num.one; Num.of_int (-3); Num.of_int (-3); Num.one |]
  in
  Alcotest.(check int) "three real roots" 3 (List.length roots);
  List.iter (fun t ->
    let t2 = Num.mul t t in
    let t3 = Num.mul t t2 in
    let f =
      Num.add
        (Num.sub
           (Num.sub t3 (Num.mul (Num.of_int 3) t2))
           (Num.mul (Num.of_int 3) t))
        Num.one
    in
    Alcotest.(check bool) "root of t³−3t²−3t+1" true (Num.equal f Num.zero))
    roots

let test_num_close_roots_distinct () =
  (* #23 repro: x⁴ − 5x² + ε with ε = 5·10⁻⁸ has two roots ≈ ±10⁻⁴.
     They are distinct; equal/compare must say so. *)
  let eps = Num.of_q (Q.of_string "1/20000000") in
  let coeffs = [| eps; Num.zero; Num.of_int (-5); Num.zero; Num.one |] in
  match Num.real_roots coeffs with
  | [ _; y; x; _ ] ->
      Alcotest.(check bool) "close roots not equal" false (Num.equal x y);
      Alcotest.(check int) "compare x y = 1" 1 (Num.compare x y);
      Alcotest.(check int) "compare y x = -1" (-1) (Num.compare y x)
  | roots -> Alcotest.failf "expected 4 roots, got %d" (List.length roots)

let test_simplest_in () =
  let q = Q.of_string in
  Alcotest.(check bool) "1/2 in [2/5, 3/5]" true
    (Q.equal (Num.simplest_in (q "2/5") (q "3/5")) (q "1/2"));
  Alcotest.(check bool) "0 in [-1/3, 1/4]" true
    (Q.equal (Num.simplest_in (q "-1/3") (q "1/4")) Q.zero);
  Alcotest.(check bool) "3 in [5/2, 7/2]" true
    (Q.equal (Num.simplest_in (q "5/2") (q "7/2")) (Q.of_int 3));
  Alcotest.(check bool) "-1/2 in [-3/5, -2/5]" true
    (Q.equal (Num.simplest_in (q "-3/5") (q "-2/5")) (q "-1/2"));
  Alcotest.(check bool) "point interval" true
    (Q.equal (Num.simplest_in (q "3/7") (q "3/7")) (q "3/7"))

let test_rational_roots_big_denominator () =
  (* the #23 wall: integer-cleared leading coefficient ~2·10¹⁹; the old
     divisor enumeration trial-divided to √(2·10¹⁹). Must now be instant. *)
  let eps = Q.of_string "1/20000000000000000000" in
  let p = Poly.of_list [ eps; Q.zero; Q.of_int (-5); Q.zero; Q.one ] in
  let t0 = Unix.gettimeofday () in
  let roots = Num.rational_roots_in p (Q.of_int (-3)) (Q.of_int 3) in
  let dt = Unix.gettimeofday () -. t0 in
  Alcotest.(check int) "quartic has no rational roots" 0 (List.length roots);
  Alcotest.(check bool) (Printf.sprintf "under 1s (took %.2fs)" dt) true (dt < 1.0)

let test_rational_roots_finds_roots () =
  (* (7x − 3)(x − 2)(x² − 2) : rational roots 3/7 and 2, irrational ±√2 *)
  let p =
    Poly.mul
      (Poly.mul
         (Poly.of_list [ Q.of_int (-3); Q.of_int 7 ])
         (Poly.of_list [ Q.of_int (-2); Q.one ]))
      (Poly.of_list [ Q.of_int (-2); Q.zero; Q.one ])
  in
  let roots = Num.rational_roots_in p (Q.of_int (-3)) (Q.of_int 3) in
  Alcotest.(check int) "two rational roots" 2 (List.length roots);
  Alcotest.(check bool) "3/7 found" true
    (List.exists (Q.equal (Q.of_string "3/7")) roots);
  Alcotest.(check bool) "2 found" true
    (List.exists (Q.equal (Q.of_int 2)) roots);
  (* range clipping: only 3/7 within [0, 1] *)
  let clipped = Num.rational_roots_in p Q.zero Q.one in
  Alcotest.(check int) "clipped to [0,1]" 1 (List.length clipped);
  (* negative rational root through the full pipeline, and a root exactly
     at the query boundary (closed interval: must be included) *)
  let pneg =
    Poly.mul
      (Poly.of_list [ Q.of_string "1/2"; Q.one ])   (* root -1/2 *)
      (Poly.of_list [ Q.of_int (-2); Q.one ])        (* root 2 *)
  in
  let nroots = Num.rational_roots_in pneg (Q.of_string "-1/2") (Q.of_int 1) in
  Alcotest.(check int) "boundary root -1/2 included, 2 excluded" 1
    (List.length nroots);
  Alcotest.(check bool) "-1/2 found" true
    (List.exists (Q.equal (Q.of_string "-1/2")) nroots)

let test_real_roots_epsilon_ladder () =
  (* #23: previously 0.07s → 0.39s → 3.47s → >150s down this ladder. *)
  let rec strictly_ascending = function
    | a :: (b :: _ as r) -> Num.compare a b < 0 && strictly_ascending r
    | _ -> true
  in
  List.iter
    (fun (name, eps) ->
      let coeffs =
        [| Num.of_q (Q.of_string eps); Num.zero; Num.of_int (-5);
           Num.zero; Num.one |]
      in
      let t0 = Unix.gettimeofday () in
      let roots = Num.real_roots coeffs in
      let dt = Unix.gettimeofday () -. t0 in
      Alcotest.(check int) (name ^ ": four roots") 4 (List.length roots);
      Alcotest.(check bool) (name ^ ": strictly ascending") true
        (strictly_ascending roots);
      Alcotest.(check bool)
        (Printf.sprintf "%s: under 1s (took %.2fs)" name dt)
        true (dt < 1.0))
    [ ("eps=5e-8", "1/20000000");
      ("eps=5e-12", "1/200000000000");
      ("eps=5e-16", "1/2000000000000000");
      ("eps=5e-20", "1/20000000000000000000") ]

let test_num_sqrt2_sqrt5_identities () =
  let s2 = Num.sqrt (n 2) and s5 = Num.sqrt (n 5) and s10 = Num.sqrt (n 10) in
  let x = Num.add s2 s5 in
  Alcotest.(check bool) "(sqrt2+sqrt5)^2 = 7 + 2*sqrt10" true
    (Num.equal (Num.mul x x) (Num.add (n 7) (Num.mul (n 2) s10)));
  Alcotest.(check bool) "1/(sqrt2+sqrt5) = (sqrt5 - sqrt2)/3" true
    (Num.equal (Num.inv x) (Num.div (Num.sub s5 s2) (n 3)));
  Alcotest.(check bool) "sqrt2*sqrt5 = sqrt10" true
    (Num.equal (Num.mul s2 s5) s10)

let test_num_deg27_smoke () =
  let cbrt k =
    match Num.real_roots [| n (-k); Num.zero; Num.zero; Num.one |] with
    | [ r ] -> r
    | _ -> Alcotest.fail "expected one real cube root"
  in
  let t0 = Unix.gettimeofday () in
  let x = Num.add (Num.add (cbrt 2) (cbrt 3)) (cbrt 5) in
  let x' = Num.add (cbrt 2) (Num.add (cbrt 3) (cbrt 5)) in
  Alcotest.(check bool) "associativity holds exactly (deg 27)" true
    (Num.equal x x');
  Alcotest.(check int) "x^2 > x (x > 1)" 1 (Num.compare (Num.mul x x) x);
  Alcotest.(check bool) "1/x * x = 1" true
    (Num.equal (Num.mul (Num.inv x) x) Num.one);
  let dt = Unix.gettimeofday () -. t0 in
  Alcotest.(check bool)
    (Printf.sprintf "deg-27 smoke under 1s (took %.3fs)" dt) true (dt < 1.0)

let test_num_axiom7_style_algebraic_cubic_fast () =
  (* cubic with coefficients in Q(sqrt2, sqrt3) — degree-4 coefficient field;
     was ~28s via generator elimination, FLINT 3.6 roots-first target < 1s *)
  let s2 = Num.sqrt (n 2) and s3 = Num.sqrt (n 3) in
  let gamma = Num.div (Num.add s2 s3) (n 8) in
  let coeffs =
    [| Num.div (n (-1)) (n 3); Num.div gamma (n 2); Num.neg gamma; Num.one |]
  in
  let t0 = Unix.gettimeofday () in
  let roots = Num.real_roots coeffs in
  let dt = Unix.gettimeofday () -. t0 in
  Alcotest.(check bool) "at least one real root" true (List.length roots >= 1);
  List.iter
    (fun r ->
      (* verify exactly: r^3 + a2 r^2 + a1 r + a0 = 0 *)
      let v =
        Num.add
          (Num.add
             (Num.mul (Num.mul r r) (Num.add r coeffs.(2)))
             (Num.mul r coeffs.(1)))
          coeffs.(0)
      in
      Alcotest.(check bool) "root verifies exactly" true (Num.equal v Num.zero))
    roots;
  Alcotest.(check bool)
    (Printf.sprintf "under 1s (took %.3fs)" dt)
    true (dt < 1.0)

let test_real_roots_independent_folds () =
  (* a cubic whose coefficients combine two INDEPENDENT prior folds:
     sqrt2 and cbrt2. Coefficient field is Q(sqrt2, cbrt2), degree 6.
     t^3 + (cbrt2)·t - sqrt2 = 0 — one real root, verified exactly. *)
  let s2 = Num.sqrt (n 2) in
  let c2 = Num.real_roots [| n (-2); n 0; n 0; n 1 |] |> List.hd in (* cbrt2 *)
  let coeffs = [| Num.neg s2; c2; n 0; n 1 |] in
  let roots = Num.real_roots coeffs in
  Alcotest.(check bool) "≥1 real root" true (List.length roots >= 1);
  List.iter
    (fun r ->
      let v =
        Num.add (Num.add (Num.mul (Num.mul r r) r) (Num.mul c2 r)) (Num.neg s2)
      in
      Alcotest.(check bool) "root verifies exactly" true (Num.equal v Num.zero))
    roots

(* Horner eval shared by the pe_tier-routing tests below. *)
let eval_num (coeffs : Num.t array) (r : Num.t) : Num.t =
  let acc = ref Num.zero in
  for i = Array.length coeffs - 1 downto 0 do
    acc := Num.add (Num.mul !acc r) coeffs.(i)
  done;
  !acc

let test_real_roots_quartic_independent_folds () =
  (* Quartic (degree-in-z = 4 > 3) trips flint_first's own guard, so it
     returns None regardless of max_deg, and control falls through to
     pe_tier. Coefficients combine two INDEPENDENT prior folds — sqrt2 and
     cbrt2 — so the coefficient field is the compositum Q(sqrt2, cbrt2)
     (degree 6): x^4 + cbrt2*x^2 - sqrt2*x - 1. At x=0 the value is -1 and
     the quartic -> +inf as x -> +-inf, so a real root is guaranteed. *)
  let s2 = Num.sqrt (n 2) in
  let c2 = Num.real_roots [| n (-2); n 0; n 0; n 1 |] |> List.hd in
  (* cbrt2 *)
  let coeffs = [| n (-1); Num.neg s2; c2; n 0; n 1 |] in
  let roots = Num.real_roots coeffs in
  Alcotest.(check bool) "≥1 real root" true (List.length roots >= 1);
  List.iter
    (fun r ->
      Alcotest.(check bool)
        "root verifies exactly" true
        (Num.equal (eval_num coeffs r) Num.zero))
    roots

let test_real_roots_degree5_coefficient () =
  (* Cubic with a coefficient of individual Qqbar.degree 5 — the real root
     of the irreducible quintic x^5 - x - 1 — pushes max_deg to 5, so the
     `max_deg < 5` gate skips flint_first entirely (it is never called) and
     goes straight to pe_tier: x^3 + quint*x - 2. At x=0 the value is -2 and
     the cubic -> +inf as x -> +inf, so a real root is guaranteed. *)
  let quint =
    Num.real_roots [| n (-1); n (-1); n 0; n 0; n 0; n 1 |] |> List.hd
  in
  let coeffs = [| n (-2); quint; n 0; n 1 |] in
  let roots = Num.real_roots coeffs in
  Alcotest.(check bool) "≥1 real root" true (List.length roots >= 1);
  List.iter
    (fun r ->
      Alcotest.(check bool)
        "root verifies exactly" true
        (Num.equal (eval_num coeffs r) Num.zero))
    roots

let test_real_roots_deep_stack_fast () =
  (* Cubic with a single coefficient of qqbar-degree 8: g = sqrt(sqrt2 +
     sqrt3). sqrt2+sqrt3 is degree 4 (Q(sqrt2,sqrt3) compositum), and its
     square root doubles that to degree 8. max_deg = 8 >= 5, so the gate
     skips flint_first entirely and routes through pe_tier — the case the
     spike measured at ~9s via qqbar-native elimination vs ~0.2s via PE.
     x^3 + g*x - 2: at x=0 the value is -2 and the cubic -> +inf as x ->
     +inf, so a real root is guaranteed. *)
  let s2 = Num.sqrt (n 2) and s3 = Num.sqrt (n 3) in
  let g = Num.sqrt (Num.add s2 s3) in
  let coeffs = [| n (-2); g; n 0; n 1 |] in
  let t0 = Unix.gettimeofday () in
  let roots = Num.real_roots coeffs in
  let dt = Unix.gettimeofday () -. t0 in
  Alcotest.(check bool) "≥1 real root" true (List.length roots >= 1);
  List.iter
    (fun r ->
      Alcotest.(check bool)
        "root verifies exactly" true
        (Num.equal (eval_num coeffs r) Num.zero))
    roots;
  Alcotest.(check bool)
    (Printf.sprintf "under 2s (took %.3fs)" dt)
    true (dt < 2.0)

let () =
  Alcotest.run "beloch-num"
    [
      ( "num",
        [
          Alcotest.test_case "rational arithmetic" `Quick test_num_rational;
          Alcotest.test_case "sqrt" `Quick test_num_sqrt;
          Alcotest.test_case "sign mixed" `Quick test_num_sign_mixed;
          Alcotest.test_case "equal rewrites" `Quick test_num_equal_rewrites;
          Alcotest.test_case "distributive" `Quick test_num_distributive;
          Alcotest.test_case "inv roundtrip" `Quick test_num_inv_roundtrip;
          Alcotest.test_case "nested radical" `Quick test_num_nested_radical;
          Alcotest.test_case "termination guard" `Quick test_num_termination_guard;
          Alcotest.test_case "to_float" `Quick test_num_to_float;
          Alcotest.test_case "cross-field via qqbar fast" `Quick
            test_num_cross_field_fast;
          Alcotest.test_case "real roots cubic" `Quick test_num_real_roots_cubic;
          Alcotest.test_case "casus irreducibilis distinct" `Quick
            test_num_casus_irreducibilis_distinct;
          Alcotest.test_case "real roots one generator" `Quick
            test_real_roots_one_generator;
          Alcotest.test_case "real roots two generators" `Quick
            test_real_roots_two_generators;
          Alcotest.test_case "real roots casus irreducibilis irrational" `Slow
            test_real_roots_casus_irreducibilis_irrational;
          Alcotest.test_case "real roots rational cube root" `Quick
            test_real_roots_rational_cube_root;
          Alcotest.test_case "real roots affine shared field" `Quick
            test_real_roots_affine_shared_field;
          Alcotest.test_case "axiom7 trisection cubic" `Quick
            test_axiom7_trisection_cubic;
          Alcotest.test_case "close roots distinct (#23)" `Quick
            test_num_close_roots_distinct;
          Alcotest.test_case "simplest rational in interval" `Quick test_simplest_in;
          Alcotest.test_case "rational roots: big denominator fast (#23)" `Quick
            test_rational_roots_big_denominator;
          Alcotest.test_case "rational roots: found and clipped" `Quick
            test_rational_roots_finds_roots;
          Alcotest.test_case "real_roots epsilon ladder (#23)" `Slow
            test_real_roots_epsilon_ladder;
          Alcotest.test_case "sqrt2/sqrt5 identities" `Quick
            test_num_sqrt2_sqrt5_identities;
          Alcotest.test_case "deg-27 smoke (cubic extensions)" `Quick
            test_num_deg27_smoke;
          Alcotest.test_case "axiom7-style algebraic cubic fast (flint 3.6)"
            `Quick test_num_axiom7_style_algebraic_cubic_fast;
          Alcotest.test_case "real roots independent folds (compositum)" `Quick
            test_real_roots_independent_folds;
          Alcotest.test_case "real roots quartic independent folds (pe_tier)"
            `Quick test_real_roots_quartic_independent_folds;
          Alcotest.test_case "real roots degree-5 coefficient (pe_tier)" `Quick
            test_real_roots_degree5_coefficient;
          Alcotest.test_case "real roots deep stack fast (#33)" `Slow
            test_real_roots_deep_stack_fast;
        ] );
      ( "poly",
        [
          Alcotest.test_case "eval" `Quick test_poly_eval;
          Alcotest.test_case "add/mul" `Quick test_poly_add_mul;
          Alcotest.test_case "derivative" `Quick test_poly_derivative;
          Alcotest.test_case "compose" `Quick test_poly_compose;
          Alcotest.test_case "normalize zero" `Quick test_poly_normalize_zero;
          Alcotest.test_case "divmod" `Quick test_poly_divmod;
          Alcotest.test_case "resultant" `Quick test_poly_resultant;
          Alcotest.test_case "squarefree" `Quick test_poly_squarefree;
          Alcotest.test_case "sturm count" `Quick test_poly_sturm_count;
          Alcotest.test_case "isolate roots" `Quick test_poly_isolate;
          Alcotest.test_case "sign variations" `Quick test_poly_sign_variations;
          Alcotest.test_case "descartes 0/1 test" `Quick test_poly_descartes_test;
          Alcotest.test_case "isolate close roots (#23)" `Quick
            test_poly_isolate_close_roots;
        ] );
      ( "mpoly",
        [
          Alcotest.test_case "resultant eliminates one var" `Quick
            test_mpoly_resultant_constant_free;
          Alcotest.test_case "two-variable elimination" `Quick
            test_mpoly_two_var_elim;
        ] );
      ( "field",
        [
          Alcotest.test_case "real_roots returns Field (cube root)" `Quick
            test_real_roots_returns_field_cube;
          Alcotest.test_case "real_roots Field and Rat mixed" `Quick
            test_real_roots_field_and_rat;
          Alcotest.test_case "mul cube root" `Quick test_field_mul_cube;
          Alcotest.test_case "add canonicalizes" `Quick test_field_add_canonicalizes;
          Alcotest.test_case "sign and inv" `Quick test_field_sign_and_inv;
          Alcotest.test_case "compare" `Quick test_field_compare;
        ] );
    ]
