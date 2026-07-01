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

(* line one\nline two\n--l: through .a .a\nline four\n
   offsets: "line one\n"=0..8, "line two\n"=9..17, line 3 starts at 18 *)
let src = "line one\nline two\n--l: through .a .a\nline four\n"

let test_basic () =
  (* underline "through .a .a" on line 3: cols 5..18 (0-based) => cnum 23..36 *)
  let span = (pos "f.bel" 3 18 23, pos "f.bel" 3 18 36) in
  let out = Diagnostic.render ~source:src ~span ~msg:"lines are identical" in
  Alcotest.(check bool) "header" true (contains out "error: lines are identical");
  Alcotest.(check bool) "location" true (contains out "--> f.bel:3:6");
  Alcotest.(check bool)
    "error line with gutter" true
    (contains out "3 | --l: through .a .a");
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
  let out = Diagnostic.render ~source:src ~span ~msg:"boom" in
  Alcotest.(check bool) "line 1 shown" true (contains out "1 | line one");
  Alcotest.(check bool) "header" true (contains out "error: boom")

let () =
  Alcotest.run "diagnostic"
    [
      ( "render",
        [
          Alcotest.test_case "basic block" `Quick test_basic;
          Alcotest.test_case "top of file" `Quick test_top_of_file;
        ] );
    ]
