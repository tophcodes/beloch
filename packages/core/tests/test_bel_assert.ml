(* tests/test_bel_assert.ml — runner for the `.bel` inline-assertion test
   format (docs/superpowers/specs/2026-07-14-beloch-inline-assertions-design.md).

   The assertion grammar, tokenizer and checker live in bel_assert.ml, shared
   with test_reference_corpus.ml; this file keeps the corpus walk and calls
   into it. *)

open Beloch

(* Anchor to the source root of *this* build context, exactly like
   test_eval.ml's example walk — dune sets DUNE_SOURCEROOT to the absolute
   workspace root, so an in-repo worktree reads its own corpora rather than
   the main checkout's (#37). *)
let source_root =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some root -> root
  | None -> "../../../../.."

(* The `.bel` corpora this runner covers: the dedicated case files and the
   docs examples. Both carry inline assertions and are checked identically, so
   a behaviour test that is also a showcase lives in examples/ alone. A file
   with no assertion line is still evaluated (it must not error). *)
let corpora = [ ("cases", "packages/core/tests/cases"); ("examples", "examples") ]

let corpus_dir (rel : string) = Filename.concat source_root rel ^ "/"

(* every .bel under [dir] (recursively); names are relative paths (e.g.
   "fold/basic-fold.bel") mirroring test_eval.ml's example_names walker. *)
let bel_names (dir : string) =
  let rec walk prefix =
    let dir = dir ^ prefix in
    Sys.readdir dir |> Array.to_list
    |> List.concat_map (fun entry ->
           let rel = prefix ^ entry in
           if Sys.is_directory (dir ^ entry) then walk (rel ^ "/")
           else if Filename.check_suffix entry ".bel" then [ rel ]
           else [])
  in
  walk "" |> List.sort compare

let read path = In_channel.with_open_text path In_channel.input_all

(* ---- Per-file test ---- *)

let test_one (dir : string) (name : string) () =
  let path = dir ^ name in
  let src = read path in
  let parsed =
    match Bel_assert.extract src with
    | p -> p
    | exception Bel_assert.Harness_fail msg -> Alcotest.failf "%s: %s" name msg
  in
  match Bel_assert.expected_error (List.map snd parsed) with
  | exception Bel_assert.Harness_fail msg -> Alcotest.failf "%s: %s" name msg
  | Some substr -> (
      match Eval.eval_folded (Beloch.parse ~filename:(Filename.basename name) src) with
      | (_ : Eval.folded) ->
          Alcotest.failf "%s: expected an error containing %S, but eval succeeded" name substr
      | exception Error.Beloch_error (_, msg) -> (
          match Bel_assert.check_error_message ~expected:substr msg with
          | () -> ()
          | exception Bel_assert.Harness_fail m -> Alcotest.failf "%s: %s" name m))
  | None -> (
      match Eval.eval_folded (Beloch.parse ~filename:(Filename.basename name) src) with
      | fd ->
          List.iter
            (fun (line, a) ->
              try Bel_assert.check fd a
              with Bel_assert.Harness_fail msg -> Alcotest.failf "%s: %S: %s" name line msg)
            parsed
      | exception Error.Beloch_error (_, msg) ->
          Alcotest.failf "%s: unexpected evaluation error: %s" name msg)

let () =
  Alcotest.run "bel_assert"
    (List.map
       (fun (group, rel) ->
         let dir = corpus_dir rel in
         ( group,
           List.map
             (fun n -> Alcotest.test_case n `Quick (test_one dir n))
             (bel_names dir) ))
       corpora)
