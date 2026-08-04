(* Tests for Msolve: the msolve subprocess driver.

   Group 1 unit-tests the output parser directly against LITERAL msolve
   0.10.0 output, captured by hand (`msolve -f in.ms -o out.ms -P 1`,
   nixpkgs rev e73de5be04e0eff4190a1432b946d469c794e7b4 — see
   .superpowers/sdd/task-7-report.md for the capture transcript) — per the
   task instruction to pin the format empirically rather than guess it.

   Group 2 exercises the real subprocess end-to-end via Msolve.classify;
   these require `msolve` on PATH (nix devShell / `nix flake check`). *)

open Multifold
module M = Beloch.Mpoly

let q = Q.of_string

(* --- Group 1: parser, pinned against literal captures ------------------ *)

(* x² − 2 = 0, y − 1 = 0 (2 vars): zero-dimensional, 2 distinct solutions. *)
let out_zero_dim =
  "[0, [0, \n\
   2, \n\
   2, \n\
   ['y', 'x'],\n\
   [0, 1],\n\
   [1,\n\
   [[2, [-2, 0, 1]],\n\
   [1, [0, 2]],\n\
   [\n\
   [[1, [0, -2]],\n\
   1]\n\
   ]]]],[1,\n\
   [[[1, 1], [-2219290601644883707169587795849264957011310523479721104423 / \
   2^190, -1109645300822441853584793897924632478505655261739860552211 / \
   2^189]], [[1, 1], \
   [1109645300822441853584793897924632478505655261739860552211 / 2^189, \
   2219290601644883707169587795849264957011310523479721104423 / 2^190]]]\n\
   ]]:"

(* x + y = 0 alone (2 vars): positive-dimensional. *)
let out_positive_dim = "[1, 2, -1, []]:"

(* x = 0, x = 1 (inconsistent): no solutions. *)
let out_no_solutions = "[-1]:"

(* (x−1)² = 0 (1 var): msolve's rational parametrization always represents
   the REDUCED variety [rouillier1999] — the eliminant f₀ reports only the
   DISTINCT root (degree 1, f₀ = x−1). The weighted degree at dim_tuple index
   2 is 2 (the double root's Bézout multiplicity), so count=1 but
   multiplicity_free=false — the mismatch is what flags the repeated root,
   since f₀ alone (degree 1, trivially squarefree) can't. *)
let out_multiplicity =
  "[0, [0, \n\
   1, \n\
   2, \n\
   ['x'],\n\
   [1],\n\
   [1,\n\
   [[1, [-1, 1]],\n\
   [0, [1]],\n\
   [\n\
   ]]]],[1,\n\
   [[[1, 1]]]\n\
   ]]:"

(* x·(x−1) = 0, saturated by w·x − 1 = 0 (2 vars: x, w): only x=1 survives
   (x=0 is excluded — w·0−1 ≠ 0), a single simple root. *)
let out_saturated =
  "[0, [0, \n\
   2, \n\
   1, \n\
   ['x', 'w'],\n\
   [0, 1],\n\
   [1,\n\
   [[1, [-1, 1]],\n\
   [0, [1]],\n\
   [\n\
   [[0, [-1]],\n\
   1]\n\
   ]]]],[1,\n\
   [[[1, 1], [1, 1]]]\n\
   ]]:"

let test_parse_zero_dim () =
  match Msolve.parse_output out_zero_dim with
  | `Zero_dim { count; multiplicity_free } ->
      Alcotest.(check int) "2 distinct solutions" 2 count;
      Alcotest.(check bool) "multiplicity-free" true multiplicity_free
  | _ -> Alcotest.fail "expected Zero_dim"

let test_parse_positive_dim () =
  match Msolve.parse_output out_positive_dim with
  | `Positive_dim -> ()
  | _ -> Alcotest.fail "expected Positive_dim"

let test_parse_no_solutions () =
  match Msolve.parse_output out_no_solutions with
  | `No_solutions -> ()
  | _ -> Alcotest.fail "expected No_solutions"

let test_parse_multiplicity_negative () =
  match Msolve.parse_output out_multiplicity with
  | `Zero_dim { count; multiplicity_free } ->
      Alcotest.(check int) "1 distinct solution" 1 count;
      Alcotest.(check bool)
        "weighted degree 2 <> count 1 -> not multiplicity-free" false
        multiplicity_free
  | _ -> Alcotest.fail "expected Zero_dim"

let test_parse_saturated () =
  match Msolve.parse_output out_saturated with
  | `Zero_dim { count; multiplicity_free } ->
      Alcotest.(check int) "1 solution after saturation" 1 count;
      Alcotest.(check bool) "multiplicity-free" true multiplicity_free
  | _ -> Alcotest.fail "expected Zero_dim"

let test_parse_garbage () =
  try
    ignore (Msolve.parse_output "not msolve output at all");
    Alcotest.fail "expected Solve_failed"
  with Msolve.Solve_failed _ -> ()

(* --- printer -------------------------------------------------------------
   msolve's syntax accepts (and our fixtures above were generated from)
   plain `+`/`-`/`*`/`^`; check the printer emits something of that shape
   for a small polynomial with a fractional coefficient. *)
let names i = "x" ^ string_of_int i

let test_poly_to_string () =
  let x0 = M.var 2 0 and x1 = M.var 2 1 in
  let p =
    M.sub
      (M.mul (M.const 2 (q "1/2")) (M.mul x0 x0))
      (M.add x1 (M.const 2 (q "2")))
  in
  Alcotest.(check string)
    "1/2*x0^2-x1-2" "1/2*x0^2-x1-2"
    (Msolve.poly_to_string ~names p);
  Alcotest.(check string) "zero poly" "0" (Msolve.poly_to_string ~names M.zero)

(* --- Group 2: end-to-end via the real msolve subprocess ----------------- *)

let test_classify_zero_dim () =
  let x = M.var 2 0 and y = M.var 2 1 in
  let sys =
    [ M.sub (M.mul x x) (M.const 2 (q "2")); M.sub y (M.const 2 (q "1")) ]
  in
  match Msolve.classify ~nvars:2 ~denoms:[] sys with
  | `Zero_dim { count; multiplicity_free } ->
      Alcotest.(check int) "2 sols" 2 count;
      Alcotest.(check bool) "multiplicity-free" true multiplicity_free
  | _ -> Alcotest.fail "expected zero-dimensional"

let test_classify_positive_dim () =
  let x = M.var 2 0 and y = M.var 2 1 in
  let sys = [ M.add x y ] in
  match Msolve.classify ~nvars:2 ~denoms:[] sys with
  | `Positive_dim -> ()
  | _ -> Alcotest.fail "expected positive-dimensional"

let test_classify_empty () =
  let x = M.var 1 0 in
  let sys = [ x; M.sub x (M.const 1 (q "1")) ] in
  match Msolve.classify ~nvars:1 ~denoms:[] sys with
  | `No_solutions -> ()
  | _ -> Alcotest.fail "expected no solutions"

(* eqs = [x·(x−1)] alone has 2 solutions {0, 1}; saturating by denoms = [x]
   excludes x=0 (the denominator's zero locus), leaving only x=1. *)
let test_classify_saturation_effectiveness () =
  let x = M.var 1 0 in
  let eqs = [ M.mul x (M.sub x (M.const 1 (q "1"))) ] in
  (match Msolve.classify ~nvars:1 ~denoms:[] eqs with
  | `Zero_dim { count; _ } -> Alcotest.(check int) "unsaturated: {0,1}" 2 count
  | _ -> Alcotest.fail "expected zero-dimensional");
  match Msolve.classify ~nvars:1 ~denoms:[ x ] eqs with
  | `Zero_dim { count; _ } -> Alcotest.(check int) "saturated: only {1}" 1 count
  | _ -> Alcotest.fail "expected zero-dimensional"

(* (x−1)² = 0: msolve's RUR eliminant f₀ = (x−1) reports only the distinct
   root (count=1), but the weighted (Bézout) degree in the output tuple is 2
   — the mismatch is what flags the double root: multiplicity_free=false. *)
let test_classify_multiplicity_negative () =
  let x = M.var 1 0 in
  let d = M.sub x (M.const 1 (q "1")) in
  match Msolve.classify ~nvars:1 ~denoms:[] [ M.mul d d ] with
  | `Zero_dim { count; multiplicity_free } ->
      Alcotest.(check int) "1 distinct solution" 1 count;
      Alcotest.(check bool) "not multiplicity-free" false multiplicity_free
  | _ -> Alcotest.fail "expected zero-dimensional"

let () =
  Alcotest.run "multifold-msolve"
    [
      ( "parser (literal fixtures)",
        [
          Alcotest.test_case "zero-dim" `Quick test_parse_zero_dim;
          Alcotest.test_case "positive-dim" `Quick test_parse_positive_dim;
          Alcotest.test_case "no solutions" `Quick test_parse_no_solutions;
          Alcotest.test_case "multiplicity-negative" `Quick
            test_parse_multiplicity_negative;
          Alcotest.test_case "saturated" `Quick test_parse_saturated;
          Alcotest.test_case "garbage" `Quick test_parse_garbage;
        ] );
      ( "printer",
        [ Alcotest.test_case "poly_to_string" `Quick test_poly_to_string ] );
      ( "classify (subprocess)",
        [
          Alcotest.test_case "zero-dim" `Quick test_classify_zero_dim;
          Alcotest.test_case "positive-dim" `Quick test_classify_positive_dim;
          Alcotest.test_case "empty" `Quick test_classify_empty;
          Alcotest.test_case "saturation effectiveness" `Quick
            test_classify_saturation_effectiveness;
          Alcotest.test_case "multiplicity-negative" `Quick
            test_classify_multiplicity_negative;
        ] );
    ]
