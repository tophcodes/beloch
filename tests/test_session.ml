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
  ignore (Session.eval s ~filename:"t.bel" b);
  Alcotest.(check int) "only the appended statement ran" 1 (Session.last_ran s)

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
  ignore (Session.eval s ~filename:"t.bel" b);
  Alcotest.(check int) "recomputed 2 of 3" 2 (Session.last_ran s);
  (* and the result still equals a cold eval *)
  Alcotest.(check string) "edited result correct" (full b)
    (fold_str (Session.eval (Session.create ()) ~filename:"t.bel" b))

let test_unchanged_reuses_all () =
  let s = Session.create () in
  let src = "paper square\nmark through .a .c\nmark through .b .d\n" in
  ignore (Session.eval s ~filename:"t.bel" src);
  ignore (Session.eval s ~filename:"t.bel" src);
  Alcotest.(check int) "nothing recomputed on identical re-eval" 0 (Session.last_ran s)

let () =
  Alcotest.run "session"
    [ ( "incremental",
        [ Alcotest.test_case "equivalence" `Quick test_equivalence;
          Alcotest.test_case "append-recomputes-one" `Quick test_append_recomputes_one;
          Alcotest.test_case "edit-invalidates-from-k" `Quick test_edit_invalidates_from_k;
          Alcotest.test_case "unchanged-reuses-all" `Quick test_unchanged_reuses_all ] ) ]
