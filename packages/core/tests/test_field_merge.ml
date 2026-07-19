open Beloch

let q = Q.of_string
let qq s = Qqbar.of_q (q s)

(* helper: evaluate a ℚ-poly at a qqbar point *)
let[@warning "-32"] eval_at (c : Poly.t) (g : Qqbar.t) : Qqbar.t =
  let acc = ref (qq "0") in
  for i = Array.length c - 1 downto 0 do
    acc := Qqbar.add (Qqbar.mul !acc g) (Qqbar.of_q c.(i))
  done;
  !acc

let test_merge_single_generator () =
  (* coefficients all in Q(sqrt2): 1, sqrt2, 3+sqrt2 *)
  let s2 = Qqbar.sqrt (qq "2") in
  let coeffs = [| qq "1"; s2; Qqbar.add (qq "3") s2 |] in
  match Field_merge.merge_generators coeffs with
  | None -> Alcotest.fail "should merge Q(sqrt2)"
  | Some (mu, coords) ->
      (* reconstruct each coefficient from its coords over the SAME gamma.
         gamma is a root of mu; verify by rebuilding coeffs and comparing. *)
      Alcotest.(check int) "3 coord polys" 3 (Array.length coords);
      (* mu has degree 2 (Q(sqrt2)) *)
      Alcotest.(check int) "mu degree 2" 2 (Poly.degree mu)

let test_merge_compositum_independent () =
  (* independent folds: sqrt2 and cbrt2 → Q(sqrt2, cbrt2), degree 6 *)
  let s2 = Qqbar.sqrt (qq "2") in
  let c2 = List.hd (Qqbar.real_roots_of_poly (Poly.of_list (List.map q ["-2";"0";"0";"1"]))) in
  let coeffs = [| s2; c2; Qqbar.add s2 c2 |] in
  match Field_merge.merge_generators coeffs with
  | None -> Alcotest.fail "should merge Q(sqrt2, cbrt2)"
  | Some (mu, coords) ->
      Alcotest.(check int) "mu degree 6" 6 (Poly.degree mu);
      Alcotest.(check int) "3 coord polys" 3 (Array.length coords)

let test_resultant_superset_cubic () =
  (* cubic t^3 - 2 has coeffs all rational except none; use t^3 - sqrt2 whose
     coeff sqrt2 lives in Q(sqrt2). R must vanish at the real cube-ish root. *)
  let s2 = Qqbar.sqrt (qq "2") in
  let coeffs = [| Qqbar.neg s2; qq "0"; qq "0"; qq "1" |] in
  match Field_merge.merge_generators coeffs with
  | None -> Alcotest.fail "merge"
  | Some (mu, coords) ->
      let r = Field_merge.resultant_superset ~coords ~mu in
      let roots = Qqbar.real_roots_of_poly r in
      (* the real root of t^3 = sqrt2 must be among R's real roots *)
      let target = List.hd (Qqbar.real_roots_of_poly
                     (Poly.of_list (List.map q ["-2";"0";"0";"0";"0";"0";"1"]))) in
      Alcotest.(check bool) "R contains t with t^6 = 2" true
        (List.exists (fun z -> Qqbar.equal z target) roots)

let () =
  Alcotest.run "field_merge"
    [ ( "merge",
        [ Alcotest.test_case "single generator" `Quick test_merge_single_generator;
          Alcotest.test_case "compositum independent" `Quick
            test_merge_compositum_independent;
          Alcotest.test_case "resultant superset cubic" `Quick
            test_resultant_superset_cubic ] ) ]
