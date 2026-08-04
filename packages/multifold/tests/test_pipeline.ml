(* Tests for Pipeline: candidate combos -> equations -> msolve -> symbols.

   Group "onefold" is Quick (7 combos). Group "twofold" is Slow: it shells
   out to msolve ~1099 times (the k=2/no-AL10 slice of Combo.candidates).
   Run via `dune runtest`/`dune test` for Quick only (the dune rule below
   sets ALCOTEST_QUICK_TESTS=true for the runtest alias); run
   `dune exec packages/multifold/tests/test_pipeline.exe` from this
   directory for the full suite including Slow. *)

open Multifold

let test_onefold_pipeline () =
  Alcotest.(check int)
    "7 survive the algebraic filter" 7
    (List.length (Pipeline.run_onefold ()))

let test_twofold_no_al10 () =
  let syms = Pipeline.run_twofold ~with_al10:false ~stream:Symeq.stream_a in
  Alcotest.(check int) "203" 203 (List.length syms);
  (* symbol-by-symbol against the 489-symbol fixture, restricted to symbols
     without AL10 *)
  let expected =
    Test_fixture.fixture ()
    |> List.filter (fun s ->
        match Alignment.combo_of_symbol s with
        | Some c -> not (List.exists (fun (a : Alignment.t) -> a.kind = AL10) c)
        | None -> false)
    |> List.sort String.compare
  in
  Alcotest.(check (list string)) "exact symbol set" expected syms

(* Prints, but asserts nothing about, the strict/lax difference at
   k=2/no-AL10 — this measurement is what Task 10's report records; whether
   it's empty is evidence, not yet a spec. Cheap: shares run_twofold's
   cached msolve results (same with_al10/stream) rather than re-solving. *)
let test_twofold_lax_diff () =
  let diff = Pipeline.lax_only ~with_al10:false ~stream:Symeq.stream_a in
  Printf.printf "lax-only difference at k=2/no-AL10: %d symbol(s)%s\n%!"
    (List.length diff)
    (if diff = [] then "" else ": " ^ String.concat ", " diff)

let () =
  Alcotest.run "multifold-pipeline"
    [
      ( "onefold",
        [ Alcotest.test_case "still the 7 HJAs" `Quick test_onefold_pipeline ]
      );
      ( "twofold",
        [
          Alcotest.test_case "203, no AL10" `Slow test_twofold_no_al10;
          Alcotest.test_case "strict/lax difference" `Slow test_twofold_lax_diff;
        ] );
    ]
