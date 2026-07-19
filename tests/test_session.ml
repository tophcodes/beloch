open Beloch

let fold_str f = Yojson.Safe.to_string (Fold_emit.to_json_folded f)

let full src =
  fold_str (Eval.eval_folded (Beloch.parse ~filename:"t.bel" src))

(* `mark` statements evaluate cleanly (subdivide, no `moving .p`, never throw).
   `paper square` is the header, not a statement, so an N-mark program has N
   statements and N keys — the counts below reflect that. *)

let test_equivalence () =
  let s = Session.create () in
  let src = "paper square\nmark through .a .c\nmark through .b .d\n" in
  let got = fold_str (Session.eval s ~filename:"t.bel" src) in
  Alcotest.(check string) "session == eval_folded" (full src) got

let test_append_recomputes_one () =
  let s = Session.create () in
  let a = "paper square\nmark through .a .c\n" in
  let b = "paper square\nmark through .a .c\nmark through .b .d\n" in
  ignore (Session.eval s ~filename:"t.bel" a);
  let gotb = Session.eval s ~filename:"t.bel" b in
  Alcotest.(check int) "only the appended statement ran" 1 (Session.last_ran s);
  (* warmed (prefix=1) resume must byte-match a cold eval *)
  Alcotest.(check string) "warmed append == cold eval" (full b) (fold_str gotb)

let test_edit_invalidates_from_k () =
  let s = Session.create () in
  (* 3 statements; edit the 2nd — statement 1 is reused, 2 and 3 recomputed *)
  let a =
    "paper square\nmark through .a .c\nmark through .b .d\nmark map .a onto .b\n"
  in
  let b =
    "paper square\nmark through .a .c\nmark map .a onto .d\nmark map .a onto .b\n"
  in
  ignore (Session.eval s ~filename:"t.bel" a);
  let gotb = Session.eval s ~filename:"t.bel" b in
  Alcotest.(check int) "recomputed 2 of 3" 2 (Session.last_ran s);
  (* the WARMED session resumed from snaps[0]; output must equal a cold eval *)
  Alcotest.(check string) "warmed edit resume == cold eval" (full b) (fold_str gotb)

let test_unchanged_reuses_all () =
  let s = Session.create () in
  let src = "paper square\nmark through .a .c\nmark through .b .d\n" in
  ignore (Session.eval s ~filename:"t.bel" src);
  ignore (Session.eval s ~filename:"t.bel" src);
  Alcotest.(check int) "nothing recomputed on identical re-eval" 0 (Session.last_ran s)

let test_resume_byte_identical_many_named () =
  (* enough named creases to exceed the initial 8-bucket hashtable layout, so
     restore's rebuilt iteration order would diverge from a fresh eval unless
     output is canonicalized. Marks eval cleanly (no `moving .p`). *)
  let src =
    "paper square\n\
     mark --l1 = through .a .c\n\
     mark --l2 = through .b .d\n\
     mark --l3 = map .a onto .b\n\
     mark --l4 = map .a onto .d\n\
     mark --l5 = map .b onto .c\n\
     mark --l6 = map .c onto .d\n\
     mark --l7 = map .a onto .c\n"
  in
  let s = Session.create () in
  (* warm the session, then edit the LAST statement so resume replays from a
     deep prefix (>6) — the regime where bucket order diverges *)
  ignore (Session.eval s ~filename:"t.bel" src);
  let src2 = src ^ "mark --l8 = map .b onto .d\n" in
  let warmed = fold_str (Session.eval s ~filename:"t.bel" src2) in
  Alcotest.(check string) "warmed deep-resume == cold eval" (full src2) warmed;
  (* idempotency: same session, same source, twice → identical bytes *)
  let a = fold_str (Session.eval s ~filename:"t.bel" src2) in
  let b = fold_str (Session.eval s ~filename:"t.bel" src2) in
  Alcotest.(check string) "idempotent re-eval" a b

let () =
  Alcotest.run "session"
    [ ( "incremental",
        [ Alcotest.test_case "equivalence" `Quick test_equivalence;
          Alcotest.test_case "append-recomputes-one" `Quick test_append_recomputes_one;
          Alcotest.test_case "edit-invalidates-from-k" `Quick test_edit_invalidates_from_k;
          Alcotest.test_case "unchanged-reuses-all" `Quick test_unchanged_reuses_all;
          Alcotest.test_case "resume-byte-identical-many-named" `Quick
            test_resume_byte_identical_many_named ] ) ]
