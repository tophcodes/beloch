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
  | [ e; _ ] ->
      Alcotest.(check string) "axiom" "axiom2" (e |> member "axiom" |> to_string);
      let cs = candidates e in
      Alcotest.(check int) "one candidate" 1 (List.length cs);
      Alcotest.(check int) "selected" 1 (count selected cs);
      Alcotest.(check bool) "no conics" true (e |> member "conics" = `Null)
  | es -> Alcotest.failf "expected two entries, got %d" (List.length es)

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

(* ---- writes ---- *)

let write_entries json =
  List.filter (fun e -> e |> member "write" <> `Null) (entries json)

let only_write json =
  match write_entries json with
  | [ e ] -> e
  | es -> Alcotest.failf "expected one write entry, got %d" (List.length es)

let terms e = e |> member "terms"
let region j = j |> to_list |> List.map (fun p -> p |> to_list)
let placement e = terms e |> member "placement" |> to_string

let test_fold_terms () =
  let json, _ = fold_traced "paper square\nfold (map .a onto .c)\n" in
  let e = only_write json in
  Alcotest.(check string) "write" "fold" (e |> member "write" |> to_string);
  Alcotest.(check int) "statement" 0 (e |> member "statement" |> to_int);
  Alcotest.(check int) "read on the flat sheet" 0 (e |> member "frame_index" |> to_int);
  Alcotest.(check int) "the construction comes first" 1
    (List.length
       (List.filter (fun e -> e |> member "axiom" <> `Null) (entries json)));
  Alcotest.(check string) "placed on top" "top" (placement e);
  Alcotest.(check int) "the axis is a line" 3
    (List.length (terms e |> member "axis" |> to_list));
  let side = terms e |> member "side" |> to_int in
  Alcotest.(check bool) "side is a sign" true (side = 1 || side = -1);
  (* the half of the square with .a in it, one layer *)
  (match region (terms e |> member "moving") with
  | [ poly ] -> Alcotest.(check int) "a triangle" 3 (List.length poly)
  | r -> Alcotest.failf "expected one moving face, got %d" (List.length r));
  Alcotest.(check int) "a fold chooses no state" 0 (List.length (candidates e))

let test_fold_mountain () =
  let json, _ = fold_traced "paper square\nfold (map .a onto .c) (mountain)\n" in
  Alcotest.(check string) "placed at the bottom" "bottom" (placement (only_write json))

let test_fold_tuck () =
  let json, failed =
    fold_traced
      "paper square\nfold (map .a onto .d)\n.m = free on --bc from .b at 1/2\n\
       .n = free on --ab from .b at 1/2\n.p = free on --ab from .a at 1/4\n\
       fold (through .m .n) (moving .b) (under .p) as --t\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let e = List.nth (write_entries json) 1 in
  Alcotest.(check string) "placed under" "under" (placement e);
  Alcotest.(check bool) "with a target region" true
    (region (terms e |> member "target") <> [])

let preliminary =
  "paper square\nfold (map .a onto .c) as --bd\nreverse (map .b onto .c) as --h\n\
   reverse (map .d onto .c) as --v\n"

let test_reverse () =
  let json, failed = fold_traced preliminary in
  Alcotest.(check bool) "the program succeeds" false failed;
  let e = List.nth (write_entries json) 1 in
  Alcotest.(check string) "write" "reverse" (e |> member "write" |> to_string);
  Alcotest.(check string) "inside" "inside" (terms e |> member "kind" |> to_string);
  Alcotest.(check bool) "a tip" true (region (terms e |> member "tip") <> []);
  let cs = candidates e in
  Alcotest.(check int) "one spine selected" 1 (count selected cs);
  let s = List.find selected cs in
  Alcotest.(check bool) "the selected spine has a frame" true
    (s |> member "frame" |> member "faces_vertices" <> `Null);
  Alcotest.(check int) "two halves" 2 (List.length (s |> member "halves" |> to_list));
  Alcotest.(check int) "two bodies" 2 (List.length (s |> member "bodies" |> to_list));
  Alcotest.(check int) "the spine is a segment" 2
    (List.length (s |> member "spine" |> to_list));
  List.iter
    (fun c ->
      if not (selected c) then begin
        Alcotest.(check bool) "a removed spine has a reason" true (removed c <> None);
        Alcotest.(check bool) "and no frame" true (c |> member "frame" = `Null)
      end)
    cs

let collapse toward =
  "paper square\nmark (through .a .c) as --ac\nmark (through .b .d) as --bd\n\
   mark (map --ab onto --cd) as --h\nmark (map --da onto --bc) as --v\n\
   .q = free on --ab from .a at 1/4\n.r = free on --ab from .b at 1/4\n\
   flatten (--h & --bc) (--v & --cd) (--h & --da) (--v & --ab) (--bd & .b) \
   (--bd & .d) (.q over .r)" ^ toward ^ "\n"

let test_flatten_even () =
  let json, failed = fold_traced (collapse " (toward .q)") in
  Alcotest.(check bool) "the program succeeds" false failed;
  let e = only_write json in
  Alcotest.(check string) "write" "flatten" (e |> member "write" |> to_string);
  Alcotest.(check (list (float 1e-9))) "the vertex is the centre" [ 0.5; 0.5 ]
    (terms e |> member "point" |> floats);
  let cs = candidates e in
  Alcotest.(check int) "one selected" 1 (count selected cs);
  List.iter
    (fun c ->
      Alcotest.(check int) "six given rays" 6 (List.length (c |> member "rays" |> to_list));
      Alcotest.(check bool) "no emergent ray" true (c |> member "emergent" = `Null);
      Alcotest.(check int) "the stayer is bounded by two ray ends" 2
        (List.length (c |> member "stayer" |> to_list));
      Alcotest.(check bool) "every candidate is a state" true
        (c |> member "frame" |> member "faces_vertices" <> `Null);
      if not (selected c) then
        Alcotest.(check bool) "removed by a stage of the selection" true
          (List.mem (removed c) [ Some "toward"; Some "mountains"; Some "top" ]))
    cs

let test_flatten_ambiguous () =
  let json, failed = fold_traced (collapse "") in
  Alcotest.(check bool) "the program fails" true failed;
  let cs = candidates (only_write json) in
  Alcotest.(check int) "none selected" 0 (count selected cs);
  Alcotest.(check bool) "several stay open" true
    (count (fun c -> removed c = None) cs >= 2)

let test_flatten_odd () =
  let json, failed =
    fold_traced
      "paper square\nmark (map .a onto .c) as --diag\nmark (through .a .c) as --ray\n\
       mark (map --ab onto --diag) as --l1\nmark (map --da onto --diag) as --l2\n\
       flatten (--l1) (--l2) (--ray) (toward .d)\n"
  in
  Alcotest.(check bool) "the program succeeds" false failed;
  let cs = candidates (only_write json) in
  let s = List.find selected cs in
  Alcotest.(check int) "three given rays" 3 (List.length (s |> member "rays" |> to_list));
  Alcotest.(check int) "an emergent ray" 2 (List.length (s |> member "emergent" |> to_list))

(* .d lands at (1/2, ±√3/2); every point of y = 0 is as near to one landing
   as to the other, so `toward .b` selects nothing *)
let test_toward_tie () =
  let json, failed = fold_traced (triangle " toward .b") in
  Alcotest.(check bool) "the program fails" true failed;
  let cs = candidates (List.nth (entries json) 1) in
  Alcotest.(check int) "both stay open" 2 (count (fun c -> removed c = None) cs);
  Alcotest.(check int) "none selected" 0 (count selected cs);
  let err = json |> member "beloch:error" in
  Alcotest.(check bool) "the error names the tie" true
    (Str.string_match (Str.regexp ".*as near") (err |> member "message" |> to_string) 0);
  Alcotest.(check bool) "with a hint" true (err |> member "hint" <> `Null)

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
          Alcotest.test_case "a toward point on the boundary selects nothing" `Quick
            test_toward_tie;
          Alcotest.test_case "without --trace nothing changes" `Quick
            test_untraced_unchanged;
        ] );
      ( "writes",
        [
          Alcotest.test_case "a fold's terms" `Quick test_fold_terms;
          Alcotest.test_case "a mountain fold is placed at the bottom" `Quick
            test_fold_mountain;
          Alcotest.test_case "a tuck has a target" `Quick test_fold_tuck;
          Alcotest.test_case "a reverse fold's spines" `Quick test_reverse;
          Alcotest.test_case "an even flatten's states" `Quick test_flatten_even;
          Alcotest.test_case "an ambiguous flatten keeps its states" `Quick
            test_flatten_ambiguous;
          Alcotest.test_case "an odd flatten's emergent ray" `Quick test_flatten_odd;
        ] );
    ]
