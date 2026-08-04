open Multifold

let al k s = Alignment.{ kind = k; suffix = s }

let test_canonical_swap () =
  (* AL2b+AL3a+AL10b sorted, swapped = AL2a+AL3b+AL10a — canonical picks the swap-min *)
  let c = [ al AL2 B; al AL3 A; al AL10 B ] in
  let cc = Combo.canonical c in
  Alcotest.(check string) "canonical symbol" "AL2a3b10a" (Alignment.combo_to_symbol cc)

let test_separable () =
  (* AL2a+AL3a determine fold a alone (2 one-fold-style equations on fold a);
     paired with AL2b+AL3b this is two independent 1FAs → separable. *)
  Alcotest.(check bool) "separable" true
    (Combo.separable [ al AL2 A; al AL3 A; al AL2 B; al AL3 B ]);
  (* AL6ab8 is in the paper's list → non-separable *)
  Alcotest.(check bool) "AL6ab8 stays" false
    (Combo.separable [ al AL6 A; al AL6 B; al AL8 Sym ])

let test_candidates_contain_fixture () =
  (* Every printed 489 symbol must appear among raw candidates (superset check). *)
  let cands =
    Combo.candidates ()
    |> List.map Alignment.combo_to_symbol
    |> List.sort_uniq String.compare
  in
  let missing =
    List.filter (fun s -> not (List.mem s cands)) (Test_fixture.fixture ())
  in
  Alcotest.(check (list string)) "no fixture symbol missing" [] missing

let () =
  Alcotest.run "multifold-combo"
    [
      ("canonical", [ Alcotest.test_case "swap" `Quick test_canonical_swap ]);
      ("separable", [ Alcotest.test_case "cases" `Quick test_separable ]);
      ( "candidates",
        [
          Alcotest.test_case "contain fixture" `Quick
            test_candidates_contain_fixture;
        ] );
    ]
