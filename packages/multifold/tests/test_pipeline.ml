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
  (* run_twofold_published applies R1-R3 (baked into Combo.candidates /
     Symeq.equations_denoms_of) plus R4, the empirical published-list filter
     [notes/2026-08-04-multifold-203-mismatch.md] -- this is what reproduces
     the paper's printed count exactly. *)
  let syms =
    Pipeline.run_twofold_published ~with_al10:false ~stream:Symeq.stream_a
  in
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

(* Prints, and now asserts, the strict/lax difference at k=2/no-AL10. Before
   R3, this was 1 symbol (AL13a9, a repeated-root artifact of the missing
   isotropic saturation); the investigation found that with R3 in place no
   surviving candidate fails multiplicity_free at all, so strict and lax
   coincide -- a principled, verified claim (not an accident of this
   particular stream), see
   notes/2026-08-04-multifold-203-mismatch.md, §R3 and the AL13a9 section.
   Cheap: shares run_twofold's cached msolve results (same with_al10/stream)
   rather than re-solving. *)
let test_twofold_lax_diff () =
  let diff = Pipeline.lax_only ~with_al10:false ~stream:Symeq.stream_a in
  Printf.printf "lax-only difference at k=2/no-AL10: %d symbol(s)%s\n%!"
    (List.length diff)
    (if diff = [] then "" else ": " ^ String.concat ", " diff);
  Alcotest.(check (list string)) "strict and lax coincide" [] diff

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
