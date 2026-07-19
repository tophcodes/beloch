open Beloch

let parse src = Beloch.parse ~filename:"t.bel" src

let keys src = Spine.chain_keys src (parse src)

let test_whitespace_insensitive () =
  let a = keys "paper square\nmark through .a .c\n" in
  let b = keys "paper square\n\n  mark   through .a .c\n" in
  Alcotest.(check (list string)) "cosmetic edits do not bust" a b

let test_append_keeps_prefix () =
  let a = keys "paper square\nfold through .a .c\n" in
  let b = keys "paper square\nfold through .a .c\nfold through .b .d\n" in
  (* every key of [a] is a prefix of [b] *)
  List.iteri
    (fun i k -> Alcotest.(check string) (Printf.sprintf "key %d stable" i) k (List.nth b i))
    a;
  Alcotest.(check int) "b has one more key" (List.length a + 1) (List.length b)

let test_edit_invalidates_suffix () =
  let a = keys "paper square\nfold through .a .c\nfold through .b .d\n" in
  let b = keys "paper square\nfold through .a .b\nfold through .b .d\n" in
  Alcotest.(check string) "key 0 stable" (List.nth a 0) (List.nth b 0);
  Alcotest.(check bool) "key 1 changed" true (List.nth a 1 <> List.nth b 1);
  Alcotest.(check bool) "key 2 changed (chained)" true (List.nth a 2 <> List.nth b 2)

let () =
  Alcotest.run "spine"
    [ ( "chain",
        [ Alcotest.test_case "whitespace-insensitive" `Quick test_whitespace_insensitive;
          Alcotest.test_case "append-keeps-prefix" `Quick test_append_keeps_prefix;
          Alcotest.test_case "edit-invalidates-suffix" `Quick test_edit_invalidates_suffix ] ) ]
