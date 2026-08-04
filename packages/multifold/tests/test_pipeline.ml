(* Tests for Pipeline: candidate combos -> equations -> msolve -> symbols.

   Group "onefold" is Quick (7 combos). Group "twofold" is Slow: it shells
   out to msolve 264 times (~17s measured; the k=2/no-AL10 slice of
   Combo.candidates, 566 total with AL10).
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
     the paper's printed count exactly.

     KNOWN CONCERN (Task-8 fix round 2, real_count >= 1 added to strict_keep
     for Definition 9): this currently FAILS -- 174, not 203, at stream_a
     (180 at stream_b). The narrow effect the filter was added for is
     verified correct (AL2a7a8/AL2a7b8 now die here, at real_count = 0 at
     BOTH streams, instead of via R4; R4's remaining burden is exactly
     {AL2ab8, AL2a7a9, AL2a7b9}), but 29 other symbols that ARE in the
     paper's published list (23 at stream_b, only 12 overlapping between the
     two streams) also spuriously show real_count = 0 -- the same
     stream-sign-correlation artifact {!Pipeline.onefold_stream}'s comment
     documents for the one-fold pipeline (stream_a/stream_b's strictly
     alternating signs bias tangent/cubic-type sub-constructions, degree>=2
     in AL5/AL8, toward the complex side), not a genuine mathematical
     exclusion -- confirmed because the two streams disagree on which
     symbols it hits. Fixing this needs a deliberately decorrelated two-fold
     stream (as {!Pipeline.onefold_stream} is for one-fold), which is a
     bigger, more consequential change here: stream_a's literal values are
     quoted verbatim throughout
     notes/2026-08-04-multifold-203-mismatch.md and prior task reports, so
     replacing it invalidates that prose. Left unresolved per the Task-8
     review instruction to stop and report rather than force a fix; see
     .superpowers/sdd/task-8-report.md, "Fix round 2". *)
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
   rather than re-solving.

   KNOWN CONCERN (same root cause as test_twofold_no_al10, above): this now
   also FAILS, mechanically -- lax_keep never checked real_count (its
   documented purpose is isolating the multiplicity_free axis only), so
   every symbol newly excluded from strict_keep by the real_count >= 1
   conjunct (Task-8 fix round 2) shows up as "lax-only" too. Not a second,
   independent finding: the multiplicity axis itself is still empty (no
   surviving candidate fails multiplicity_free), exactly as R3 established;
   this is the stream-correlation artifact re-surfacing through a different
   assertion. *)
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
