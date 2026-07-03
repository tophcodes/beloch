open Beloch

let q = Q.of_string
let qp l = Poly.of_list (List.map Q.of_int l)

let test_rational_roundtrip () =
  let x = Qqbar.of_q (q "3/7") in
  Alcotest.(check bool) "to_q returns 3/7" true
    (match Qqbar.to_q x with Some r -> Q.equal r (q "3/7") | None -> false);
  Alcotest.(check int) "degree 1" 1 (Qqbar.degree x);
  Alcotest.(check bool) "is_zero 0" true (Qqbar.is_zero (Qqbar.of_q Q.zero))

let test_arithmetic () =
  let two = Qqbar.of_q (q "2") in
  let s2 = Qqbar.sqrt two in
  Alcotest.(check bool) "sqrt2 irrational" true (Qqbar.to_q s2 = None);
  Alcotest.(check int) "degree sqrt2 = 2" 2 (Qqbar.degree s2);
  Alcotest.(check bool) "sqrt2 * sqrt2 = 2" true
    (Qqbar.equal (Qqbar.mul s2 s2) two);
  Alcotest.(check bool) "sqrt2 + (-sqrt2) = 0" true
    (Qqbar.is_zero (Qqbar.add s2 (Qqbar.neg s2)));
  Alcotest.(check int) "1 < sqrt2" (-1)
    (Qqbar.cmp_re (Qqbar.of_q Q.one) s2);
  Alcotest.(check int) "sign sqrt2 = 1" 1 (Qqbar.sign_re s2);
  Alcotest.(check bool) "inv: 1/sqrt2 = sqrt2/2" true
    (Qqbar.equal (Qqbar.inv s2) (Qqbar.div s2 two));
  Alcotest.(check bool) "inv zero raises" true
    (try ignore (Qqbar.inv (Qqbar.of_q Q.zero)); false
     with Invalid_argument _ -> true);
  Alcotest.(check bool) "sqrt negative raises" true
    (try ignore (Qqbar.sqrt (Qqbar.of_q (q "-1"))); false
     with Invalid_argument _ -> true)

let test_real_roots () =
  (* x^3 - 2: one real root, cbrt2 *)
  let roots = Qqbar.real_roots_of_poly (qp [ -2; 0; 0; 1 ]) in
  Alcotest.(check int) "one real root" 1 (List.length roots);
  let c = List.hd roots in
  Alcotest.(check int) "degree 3" 3 (Qqbar.degree c);
  Alcotest.(check bool) "cbrt2^3 = 2" true
    (Qqbar.equal (Qqbar.mul c (Qqbar.mul c c)) (Qqbar.of_q (q "2")));
  (* x^2 - 2 with rational coefficients that need clearing: (1/3)x^2 - 2/3 *)
  let roots2 =
    Qqbar.real_roots_of_poly (Poly.of_list [ q "-2/3"; Q.zero; q "1/3" ])
  in
  Alcotest.(check int) "two roots ascending" 2 (List.length roots2);
  Alcotest.(check int) "roots ascending" (-1)
    (Qqbar.cmp_re (List.nth roots2 0) (List.nth roots2 1))

let test_minpoly_enclosure () =
  let s2 = Qqbar.sqrt (Qqbar.of_q (q "2")) in
  let mu = Qqbar.minpoly s2 in
  Alcotest.(check bool) "minpoly sqrt2 = x^2 - 2" true
    (Poly.degree mu = 2 && Q.equal mu.(2) Q.one && Q.equal mu.(1) Q.zero
     && Q.equal mu.(0) (q "-2"));
  let lo, hi = Qqbar.enclosure s2 ~prec:64 in
  Alcotest.(check bool) "enclosure brackets sqrt2" true
    (Q.compare (Q.mul lo lo) (q "2") < 0 && Q.compare (Q.mul hi hi) (q "2") > 0);
  Alcotest.(check bool) "enclosure is tight at prec 64" true
    (Q.compare (Q.sub hi lo) (q "1/1000000") < 0)

let () =
  Alcotest.run "beloch-qqbar"
    [
      ( "qqbar",
        [
          Alcotest.test_case "rational roundtrip" `Quick test_rational_roundtrip;
          Alcotest.test_case "arithmetic" `Quick test_arithmetic;
          Alcotest.test_case "real roots" `Quick test_real_roots;
          Alcotest.test_case "minpoly + enclosure" `Quick test_minpoly_enclosure;
        ] );
    ]
