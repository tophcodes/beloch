open Multifold
open Alignment

let test_alphabet_size () =
  Alcotest.(check int)
    "17 two-fold symbols" 17
    (List.length Alignment.all_twofold)

let al k s = Alignment.{ kind = k; suffix = s }

let test_equation_counts () =
  (* [alperin2006, §4]: alignments yield 1 or 2 equations; a valid 2FA has
     2–4 alignments totalling exactly 4. Table: AL4, AL8, AL9 → 2; rest → 1. *)
  Alcotest.(check int) "AL1" 1 (Alignment.equations (al AL1 Sym));
  Alcotest.(check int) "AL2a" 1 (Alignment.equations (al AL2 A));
  Alcotest.(check int) "AL4a" 2 (Alignment.equations (al AL4 A));
  Alcotest.(check int) "AL8" 2 (Alignment.equations (al AL8 Sym));
  Alcotest.(check int) "AL9" 2 (Alignment.equations (al AL9 Sym));
  Alcotest.(check int) "AL10b" 1 (Alignment.equations (al AL10 B))

let test_symbol_roundtrip () =
  let cases = [ "AL6ab8"; "AL110aaa"; "AL2a3b10ab"; "AL4ab"; "AL10aaab" ] in
  List.iter
    (fun s ->
      match Alignment.combo_of_symbol s with
      | None -> Alcotest.failf "parse %s" s
      | Some c ->
          Alcotest.(check string)
            ("roundtrip " ^ s) s
            (Alignment.combo_to_symbol c))
    cases

let test_symbol_semantics () =
  (* AL6ab8 = AL6a + AL6b + AL8 *)
  match Alignment.combo_of_symbol "AL6ab8" with
  | Some [ x; y; z ] ->
      Alcotest.(check bool) "AL6a" true (x = al AL6 A);
      Alcotest.(check bool) "AL6b" true (y = al AL6 B);
      Alcotest.(check bool) "AL8" true (z = al AL8 Sym)
  | _ -> Alcotest.fail "expected 3 alignments"

let test_symbol_rejects_malformed () =
  (* AL1 is symmetric (Alignment.symmetric): a trailing a/b letter is
     malformed, not a suffix. *)
  Alcotest.(check bool)
    "AL1a rejected" true
    (Alignment.combo_of_symbol "AL1a" = None);
  (* Leading zero: "01" must not be read as kind number 1. *)
  Alcotest.(check bool)
    "AL01 rejected" true
    (Alignment.combo_of_symbol "AL01" = None)

let test_fixture_count () =
  Alcotest.(check int) "489 symbols" 489 (List.length (Test_fixture.fixture ()))

let test_fixture_all_sum_to_four () =
  List.iter
    (fun s ->
      match Alignment.combo_of_symbol s with
      | None -> Alcotest.failf "unparseable %s" s
      | Some c ->
          let sum = List.fold_left (fun n a -> n + Alignment.equations a) 0 c in
          Alcotest.(check int) ("eqs of " ^ s) 4 sum;
          let n = List.length c in
          Alcotest.(check bool)
            ("2..4 alignments in " ^ s)
            true
            (n >= 2 && n <= 4))
    (Test_fixture.fixture ())

let () =
  Alcotest.run "multifold-alignment"
    [
      ("alphabet", [ Alcotest.test_case "size" `Quick test_alphabet_size ]);
      ("equations", [ Alcotest.test_case "counts" `Quick test_equation_counts ]);
      ( "symbol",
        [
          Alcotest.test_case "roundtrip" `Quick test_symbol_roundtrip;
          Alcotest.test_case "semantics" `Quick test_symbol_semantics;
          Alcotest.test_case "rejects malformed" `Quick
            test_symbol_rejects_malformed;
        ] );
      ( "fixture",
        [
          Alcotest.test_case "count" `Quick test_fixture_count;
          Alcotest.test_case "sum to four" `Quick test_fixture_all_sum_to_four;
        ] );
    ]
