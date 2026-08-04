open Multifold

let al k s = Alignment.{ kind = k; suffix = s }

let test_canonical_swap () =
  (* AL2b+AL3a+AL10b sorted, swapped = AL2a+AL3b+AL10a — canonical picks the swap-min *)
  let c = [ al AL2 B; al AL3 A; al AL10 B ] in
  let cc = Combo.canonical c in
  Alcotest.(check string)
    "canonical symbol" "AL2a3b10a"
    (Alignment.combo_to_symbol cc)

let test_separable () =
  (* AL2a+AL3a determine fold a alone (2 one-fold-style equations on fold a);
     paired with AL2b+AL3b this is two independent 1FAs → separable. *)
  Alcotest.(check bool)
    "separable" true
    (Combo.separable [ al AL2 A; al AL3 A; al AL2 B; al AL3 B ]);
  (* AL6ab8 is in the paper's list → non-separable *)
  Alcotest.(check bool)
    "AL6ab8 stays" false
    (Combo.separable [ al AL6 A; al AL6 B; al AL8 Sym ]);
  (* R1 regression [notes/2026-08-04-multifold-203-mismatch.md, §R1]:
     AL12a3a5a = AL1+AL2a+AL3a+AL5a. {AL2a,AL3a} alone fixes fold a from
     the givens (the old 2+2-bipartition rule missed this, since AL1 and
     AL5a both mention fold b too — "both" was non-empty). Sequential
     separability catches it: fold a determined, AL1+AL5a then a 1FA for
     fold b given fold a. *)
  Alcotest.(check bool)
    "AL12a3a5a is separable under R1" true
    (Combo.separable [ al AL1 Sym; al AL2 A; al AL3 A; al AL5 A ])

let test_al1_degenerate () =
  (* R2 regression [notes/2026-08-04-multifold-203-mismatch.md, §R2]. *)
  Alcotest.(check bool)
    "AL1+AL4a rejected" true
    (Combo.al1_degenerate [ al AL1 Sym; al AL4 A; al AL2 A; al AL2 B ]);
  Alcotest.(check bool)
    "AL1+AL9 rejected" true
    (Combo.al1_degenerate [ al AL1 Sym; al AL3 A; al AL9 Sym ]);
  (* AL1 paired only with kinds outside {AL4,AL5,AL8,AL9} is untouched. *)
  Alcotest.(check bool)
    "AL1+AL2+AL3+AL6 kept" false
    (Combo.al1_degenerate [ al AL1 Sym; al AL2 A; al AL3 B; al AL6 A ])

let test_matches_published_list () =
  (* R4 regression [notes/2026-08-04-multifold-203-mismatch.md, §R4]:
     AL2ab8 has AL8 and no anchor kind {AL3,AL4,AL5,AL6,AL10} → excluded,
     even though (per the notes) it may be a genuine, unlisted 2FA. *)
  Alcotest.(check bool)
    "AL2ab8 excluded" false
    (Combo.matches_published_list [ al AL2 A; al AL2 B; al AL8 Sym ]);
  (* AL6ab8 has AL8 but also an anchor (AL6) → kept. *)
  Alcotest.(check bool)
    "AL6ab8 kept" true
    (Combo.matches_published_list [ al AL6 A; al AL6 B; al AL8 Sym ]);
  (* No AL8/AL9 at all → R4 doesn't apply, always kept. *)
  Alcotest.(check bool)
    "no AL8/AL9, always kept" true
    (Combo.matches_published_list [ al AL2 A; al AL2 B; al AL7 A; al AL7 B ])

let test_onefold_seven () =
  (* Mapping to the classical names [alperin2006, Table 1]: A1=O2, A2=O3,
     {A3,A4}=O7, {A3,A5}=O4, {A4,A4}=O6, {A4,A5}=O5, {A5,A5}=O1. *)
  let expected = [ "A1"; "A2"; "A3+A4"; "A3+A5"; "A4+A4"; "A4+A5"; "A5+A5" ] in
  Alcotest.(check (list string))
    "the 7 HJAs" expected
    (Combo.onefold_candidates ())

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

let test_candidates_count () =
  (* Pins the post-R1/R2 canonical non-separable counts quoted in
     data/twofold-axioms.txt's header and both
     notes/2026-08-04-multifold-{phase1-reproduction,203-mismatch}.md: 566
     candidates total (with AL10), 264 of them without any AL10 alignment. *)
  let cands = Combo.candidates () in
  Alcotest.(check int) "566 candidates" 566 (List.length cands);
  let no_al10 =
    List.filter
      (fun c -> not (List.exists (fun (a : Alignment.t) -> a.kind = AL10) c))
      cands
  in
  Alcotest.(check int) "264 without AL10" 264 (List.length no_al10)

let () =
  Alcotest.run "multifold-combo"
    [
      ("canonical", [ Alcotest.test_case "swap" `Quick test_canonical_swap ]);
      ("separable", [ Alcotest.test_case "cases" `Quick test_separable ]);
      ( "al1_degenerate",
        [ Alcotest.test_case "cases" `Quick test_al1_degenerate ] );
      ( "matches_published_list",
        [ Alcotest.test_case "cases" `Quick test_matches_published_list ] );
      ("onefold", [ Alcotest.test_case "the 7 HJAs" `Quick test_onefold_seven ]);
      ( "candidates",
        [
          Alcotest.test_case "contain fixture" `Quick
            test_candidates_contain_fixture;
          Alcotest.test_case "566/264 count pins" `Quick test_candidates_count;
        ] );
    ]
