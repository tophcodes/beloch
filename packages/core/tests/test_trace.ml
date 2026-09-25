(* The trace of a construction's candidates (spec/FOLD.md, "The trace"):
   `beloch fold --trace` output, read as JSON the way a figure reads it. *)

open Yojson.Safe.Util

let fold_traced src =
  let json, failure = Beloch.fold_traced ~filename:"t.bel" src in
  (json, Option.is_some failure)

let triangle toward =
  "paper square\nmark (map .a onto .b) as --ef\nfold (map .d onto --ef through .a"
  ^ toward ^ ") as --s\n"

let entries json = json |> member "beloch:trace" |> to_list
let candidates e = e |> member "candidates" |> to_list
let removed c = c |> member "removed_by" |> to_string_option
let selected c = c |> member "selected" |> to_bool
let count p l = List.length (List.filter p l)
let floats j = j |> to_list |> List.map to_number

let test_ambiguous_keeps_both () =
  let json, failed = fold_traced (triangle "") in
  Alcotest.(check bool) "the program fails" true failed;
  let e = List.nth (entries json) 1 in
  Alcotest.(check string) "axiom" "axiom6" (e |> member "axiom" |> to_string);
  let cs = candidates e in
  Alcotest.(check int) "two candidates" 2 (List.length cs);
  Alcotest.(check int) "none removed" 2 (count (fun c -> removed c = None) cs);
  Alcotest.(check int) "none selected" 0 (count selected cs);
  let err = json |> member "beloch:error" in
  Alcotest.(check bool) "error names the ambiguity" true
    (Str.string_match (Str.regexp ".*two folds") (err |> member "message" |> to_string) 0);
  Alcotest.(check int) "error points at the failing statement" 1
    (err |> member "statement" |> to_int);
  let stmts = json |> member "beloch:statements" |> to_list in
  Alcotest.(check int) "the failing statement has its log entry" 2 (List.length stmts);
  Alcotest.(check int) "the error names that entry" 1 (e |> member "statement" |> to_int)

let test_toward_selects () =
  let json, failed = fold_traced (triangle " toward .c") in
  Alcotest.(check bool) "the program succeeds" false failed;
  let cs = candidates (List.nth (entries json) 1) in
  Alcotest.(check int) "one selected" 1 (count selected cs);
  Alcotest.(check int) "one removed by toward" 1
    (count (fun c -> removed c = Some "toward") cs);
  Alcotest.(check bool) "no error field" true (json |> member "beloch:error" = `Null);
  Alcotest.(check int) "the candidates are read on the state before the fold" 0
    (List.nth (entries json) 1 |> member "frame_index" |> to_int)

let test_conic () =
  let json, _ = fold_traced (triangle " toward .c") in
  let conics = List.nth (entries json) 1 |> member "conics" |> to_list in
  Alcotest.(check int) "one parabola" 1 (List.length conics);
  let c = List.hd conics in
  Alcotest.(check (list (float 1e-9))) "focus is .d" [ 0.; 1. ] (c |> member "focus" |> floats);
  (* --ef is x = 1/2 *)
  let d = c |> member "directrix" |> floats in
  let a, b, k = (List.nth d 0, List.nth d 1, List.nth d 2) in
  Alcotest.(check (float 1e-9)) "directrix is x = 1/2" 0.5 (k /. a);
  Alcotest.(check (float 1e-9)) "directrix is vertical" 0. b

let test_paper_filter () =
  let json, failed =
    fold_traced
      "paper square\nmark (map .a onto .d) as --ef\nfold (map .d onto --ef through .a) as --s\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let cs = candidates (List.nth (entries json) 1) in
  Alcotest.(check int) "two candidates" 2 (List.length cs);
  Alcotest.(check int) "one removed by the paper" 1
    (count (fun c -> removed c = Some "paper") cs);
  Alcotest.(check int) "the other selected" 1 (count selected cs)

let test_single_solution () =
  let json, _ = fold_traced "paper square\nfold (map .a onto .c)\n" in
  match entries json with
  | [ e ] ->
      Alcotest.(check string) "axiom" "axiom2" (e |> member "axiom" |> to_string);
      let cs = candidates e in
      Alcotest.(check int) "one candidate" 1 (List.length cs);
      Alcotest.(check int) "selected" 1 (count selected cs);
      Alcotest.(check bool) "no conics" true (e |> member "conics" = `Null)
  | es -> Alcotest.failf "expected one entry, got %d" (List.length es)

let test_axiom5_bind () =
  let json, failed =
    fold_traced
      "paper square\nmark (map --ab onto --cd) as --h\n.m = --h * --da\n\
       mark (through .m .c) as --mc\n--k = (map --h onto --mc)\n"
  in
  Alcotest.(check bool) "ambiguous without toward" true failed;
  let e = List.nth (entries json) 2 in
  Alcotest.(check string) "axiom" "axiom5" (e |> member "axiom" |> to_string);
  Alcotest.(check int) "both bisectors kept open" 2
    (count (fun c -> removed c = None) (candidates e))

let test_untraced_unchanged () =
  let src = triangle " toward .c" in
  let plain = Beloch.fold_string ~filename:"t.bel" src in
  Alcotest.(check bool) "no trace field without --trace" true
    (plain |> member "beloch:trace" = `Null);
  let traced, _ = fold_traced src in
  let strip = function
    | `Assoc kv -> `Assoc (List.filter (fun (k, _) -> k <> "beloch:trace") kv)
    | j -> j
  in
  Alcotest.(check string) "every other field is the same"
    (Yojson.Safe.to_string plain) (Yojson.Safe.to_string (strip traced))

let () =
  Alcotest.run "trace"
    [
      ( "constructions",
        [
          Alcotest.test_case "an ambiguous construction keeps both" `Quick
            test_ambiguous_keeps_both;
          Alcotest.test_case "toward selects, the other is removed" `Quick
            test_toward_selects;
          Alcotest.test_case "axiom 6 carries its parabola" `Quick test_conic;
          Alcotest.test_case "the paper filter is recorded" `Quick test_paper_filter;
          Alcotest.test_case "a single solution is one selected candidate" `Quick
            test_single_solution;
          Alcotest.test_case "axiom 5 in a binding" `Quick test_axiom5_bind;
          Alcotest.test_case "without --trace nothing changes" `Quick
            test_untraced_unchanged;
        ] );
    ]
