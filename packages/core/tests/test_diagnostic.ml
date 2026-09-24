open Beloch

(* build a Lexing.position: file, 1-based line, byte offset of line start, and
   absolute byte offset *)
let pos fname lnum bol cnum =
  { Lexing.pos_fname = fname; pos_lnum = lnum; pos_bol = bol; pos_cnum = cnum }

let contains hay needle =
  try
    ignore (Str.search_forward (Str.regexp_string needle) hay 0);
    true
  with Not_found -> false

(* line one\nline two\n--l = through .a .a\nline four\n
   offsets: "line one\n"=0..8, "line two\n"=9..17, line 3 starts at 18 *)
let src = "line one\nline two\n--l = through .a .a\nline four\n"

let test_basic () =
  (* underline "through .a .a" on line 3: cols 6..19 (0-based) => cnum 24..37 *)
  let span = (pos "f.bel" 3 18 24, pos "f.bel" 3 18 37) in
  let out = Diagnostic.render ~source:src ~span ~msg:"lines are identical" ~hint:None in
  Alcotest.(check bool) "header" true (contains out "error: lines are identical");
  Alcotest.(check bool) "location" true (contains out "--> f.bel:3:7");
  Alcotest.(check bool)
    "error line with gutter" true
    (contains out "3 | --l = through .a .a");
  Alcotest.(check bool) "prior context line 2" true (contains out "2 | line two");
  Alcotest.(check bool) "prior context line 1" true (contains out "1 | line one");
  (* 13-char span => 13 carets *)
  Alcotest.(check bool) "caret width" true (contains out (String.make 13 '^'));
  (* context stops at the error line: line four (below) must NOT appear *)
  Alcotest.(check bool)
    "no lines after the error" false
    (contains out "line four")

let test_top_of_file () =
  (* error on line 1: no prior context, no crash *)
  let span = (pos "f.bel" 1 0 0, pos "f.bel" 1 0 4) in
  let out = Diagnostic.render ~source:src ~span ~msg:"boom" ~hint:None in
  Alcotest.(check bool) "line 1 shown" true (contains out "1 | line one");
  Alcotest.(check bool) "header" true (contains out "error: boom")

let test_hint () =
  (* a hint is printed as a help line under the caret line; none, no line *)
  let span = (pos "f.bel" 3 18 24, pos "f.bel" 3 18 37) in
  let out =
    Diagnostic.render ~source:src ~span ~msg:"lines are identical"
      ~hint:(Some "name two distinct points")
  in
  Alcotest.(check bool) "help line" true
    (contains out "= help: name two distinct points");
  let caret_at = Str.search_forward (Str.regexp_string "^^^") out 0 in
  let help_at = Str.search_forward (Str.regexp_string "= help:") out 0 in
  Alcotest.(check bool) "help after caret" true (help_at > caret_at);
  let bare = Diagnostic.render ~source:src ~span ~msg:"x" ~hint:None in
  Alcotest.(check bool) "no help without hint" false (contains bare "help:")

(* a real evaluator error carries a real span through fold_string; render it *)
let test_integration () =
  let source = "paper square\nmark --l = through .a .a\n" in
  let rendered =
    try
      ignore (Beloch.fold_string ~filename:"t.bel" source);
      "NO ERROR"
    with Error.Beloch_error (span, msg, hint) ->
      Diagnostic.render ~source ~span ~msg ~hint
  in
  Alcotest.(check bool) "renders an error block" true (contains rendered "error:");
  Alcotest.(check bool)
    "has a location arrow" true
    (contains rendered "--> t.bel:");
  Alcotest.(check bool) "has a caret" true (contains rendered "^");
  Alcotest.(check bool) "shows the offending line" true
    (contains rendered "through .a .a")

let () =
  Alcotest.run "diagnostic"
    [
      ( "render",
        [
          Alcotest.test_case "basic block" `Quick test_basic;
          Alcotest.test_case "top of file" `Quick test_top_of_file;
          Alcotest.test_case "hint as help line" `Quick test_hint;
          Alcotest.test_case "integration via fold_string" `Quick test_integration;
        ] );
    ]
