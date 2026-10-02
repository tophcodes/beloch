(* Annotations (spec/BELOCH-ANNOTATIONS.md; ADR 0029). *)

open Beloch

(* the statements of a parsed program, after its header *)
let parse_stmts ~filename src = (Beloch.parse ~filename src).Ast.p_stmts

let fold src = Beloch.fold_string ~filename:"t.bel" src

let expect_error msg_substr thunk =
  try
    ignore (thunk ());
    Alcotest.fail ("expected error containing: " ^ msg_substr)
  with Error.Beloch_error (_, m, _) ->
    Alcotest.(check bool)
      (Printf.sprintf "error %S mentions %S" m msg_substr)
      true
      (try
         ignore (Str.search_forward (Str.regexp_string msg_substr) m 0);
         true
       with Not_found -> false)

let annotations json =
  Yojson.Safe.Util.(json |> member "beloch:annotations" |> to_list)

(* ---- parsing ---- *)

let test_parse () =
  let prog =
    parse_stmts ~filename:"t.bel"
      "paper square\n\
       @step prelim \"Fold \\\"it\\\" in half.\" ; a comment\n\
       @yr:hold .a 2\n\
       fold (map .a onto .c)\n"
  in
  match prog with
  | [ Ast.Annotation s; Ast.Annotation y; Ast.Fold _ ] ->
      Alcotest.(check string) "key" "step" s.Ast.a_key;
      Alcotest.(check (option string)) "no namespace" None s.Ast.a_ns;
      (match List.map (fun a -> a.Ast.av) s.Ast.a_args with
      | [ Ast.AvWord "prelim"; Ast.AvText t ] ->
          Alcotest.(check string) "escapes" "Fold \"it\" in half." t
      | _ -> Alcotest.fail "step arguments");
      Alcotest.(check (option string)) "namespace" (Some "yr") y.Ast.a_ns;
      Alcotest.(check string) "namespaced key" "hold" y.Ast.a_key;
      (match List.map (fun a -> a.Ast.av) y.Ast.a_args with
      | [ Ast.AvPoint _; Ast.AvNumber _ ] -> ()
      | _ -> Alcotest.fail "yr:hold arguments")
  | _ -> Alcotest.fail "two annotations, then the fold"

let test_parse_in_body () =
  let prog =
    parse_stmts ~filename:"t.bel"
      "paper square\n\
       def half(.p .q) {\n\
      \  @say \"Fold it.\"\n\
      \  fold (map .p onto .q)\n\
       }\n\
       apply half(.a .b)\n"
  in
  match prog with
  | [ Ast.Def (_, _, [ Ast.Annotation _; Ast.Fold _ ], _); Ast.Apply _ ] -> ()
  | _ -> Alcotest.fail "the annotation sits in the body"

(* ---- static errors ---- *)

let program body = "paper square\n" ^ body ^ "fold (map .a onto .c)\n"

let test_errors () =
  expect_error "unknown annotation @stpe" (fun () -> fold (program "@stpe\n"));
  expect_error "@say takes one text" (fun () -> fold (program "@say hello\n"));
  expect_error "a bare word means nothing to @yr:arrow" (fun () ->
      fold (program "@yr:arrow push\n"));
  expect_error "the label one is already used here" (fun () ->
      fold
        "paper square\n\
         @label one\n\
         fold (map .a onto .c)\n\
         @step one\n\
         fold (map .b onto .d)\n");
  expect_error "a statement opens at most one step" (fun () ->
      fold (program "@step\n@step\n"));
  expect_error "@step belongs to the statement after it, and none follows" (fun () ->
      fold "paper square\nfold (map .a onto .c)\n@step\n");
  expect_error "@label belongs to the statement after it" (fun () ->
      fold "paper square\ndef f(.p) {\n  fold (map .p onto .c)\n  @label done\n}\napply f(.a)\n");
  expect_error "@orient takes" (fun () -> fold (program "@orient .a sideways\n"));
  expect_error "@orient takes" (fun () -> fold (program "@orient .a vertical\n"));
  expect_error "@call takes" (fun () -> fold (program "@call \"corner\" .a\n"));
  expect_error "closing quote" (fun () -> fold (program "@say \"open\n"));
  expect_error "undefined point .zz" (fun () ->
      fold (program "@call .zz \"nowhere\"\n"))

(* ---- the program as a whole (ADR 0051) ---- *)

let test_program_errors () =
  expect_error "@author belongs before the first statement" (fun () ->
      fold "paper square\nfold (map .a onto .c)\n@author \"X\"\nfold (map .b onto .d)\n");
  expect_error "@design belongs before the first statement" (fun () ->
      fold "paper square\nfold (map .a onto .c)\n@design traditional\n");
  expect_error "@source belongs before the first statement" (fun () ->
      fold "paper square\ndef f(.p) {\n  fold (map .p onto .c)\n}\n@source \"Ida\"\napply f(.a)\n");
  expect_error "@author belongs to the program and stands before its first statement, not in a def body"
    (fun () -> fold "paper square\ndef f(.p) {\n  @author \"X\"\n  fold (map .p onto .c)\n}\napply f(.a)\n");
  expect_error "@author stands once in a program" (fun () ->
      fold "@author \"X\"\npaper square\n@author \"Y\"\nfold (map .a onto .c)\n");
  expect_error "@design stands once in a program" (fun () ->
      fold (program "@design traditional\n@design \"Y\"\n"));
  expect_error "@author takes one text" (fun () -> fold (program "@author Claude\n"));
  expect_error "@design takes the word traditional or one text" (fun () ->
      fold (program "@design modern\n"));
  expect_error "@source takes one text" (fun () -> fold (program "@source ida2020\n"));
  expect_error "@source takes one text" (fun () ->
      fold (program "@source \"[ida2020]\" \"Fig. 7.19\"\n"));
  expect_error "@author stands once in a program" (fun () ->
      Parse.library ~filename:"lib.bel" "@author \"X\"\n@author \"Y\"\n")

(* ---- output ---- *)

let test_emit () =
  let json =
    fold
      "paper square\n\
       @step \"Fold the diagonal.\"\n\
       fold (map .a onto .c) as --bd\n\
       @step prelim\n\
       @call .a \"top corner\"\n\
       reverse (map .b onto .c) as --h\n\
       reverse (map .d onto .c) as --v\n\
       .o = --h * --v\n\
       @orient .o .c down\n\
       @yr:hold .o\n\
       @step\n\
       --mid = (through .c .o)\n"
  in
  let open Yojson.Safe.Util in
  let anns = annotations json in
  let key j =
    match j |> member "namespace" with
    | `String ns -> ns ^ ":" ^ (j |> member "key" |> to_string)
    | _ -> j |> member "key" |> to_string
  in
  Alcotest.(check (list string)) "keys in reading order"
    [ "step"; "step"; "call"; "orient"; "yr:hold"; "step" ]
    (List.map key anns);
  let target j = j |> member "target" |> to_list |> List.map to_int in
  Alcotest.(check (list (list int)))
    "a step runs to the next step, everything else is one entry"
    [ [ 0; 0 ]; [ 1; 3 ]; [ 1; 1 ]; [ 4; 4 ]; [ 4; 4 ]; [ 4; 4 ] ]
    (List.map target anns);
  let args j = j |> member "args" |> to_list in
  let call = List.nth anns 2 in
  Alcotest.(check string) "call text" "top corner"
    (List.nth (args call) 1 |> member "text" |> to_string);
  let paper = List.hd (args call) |> member "point" |> member "paper" in
  Alcotest.(check (list (float 1e-9))) "call point in paper coordinates" [ 0.; 0. ]
    (paper |> to_list |> List.map to_float);
  let table = List.hd (args call) |> member "point" |> member "table" in
  Alcotest.(check (list (float 1e-9))) "call point on the table" [ 1.; 1. ]
    (table |> to_list |> List.map to_float);
  let orient = List.nth anns 3 in
  Alcotest.(check string) "a direction stays a word" "down"
    (List.nth (args orient) 2 |> member "word" |> to_string)

let test_emit_in_body () =
  let json =
    fold
      "paper square\n\
       def half(.p .q) {\n\
      \  @say \"Fold it.\"\n\
      \  fold (map .p onto .q)\n\
       }\n\
       apply half(.a .b)\n\
       apply half(.b .c)\n"
  in
  let open Yojson.Safe.Util in
  let anns = annotations json in
  Alcotest.(check (list (list int))) "one entry per execution, on the body's fold"
    [ [ 2; 2 ]; [ 4; 4 ] ]
    (List.map (fun j -> j |> member "target" |> to_list |> List.map to_int) anns)

(* An annotation after the last statement belongs to the final state: no
   target, read against the last frame. *)
let test_emit_trailing () =
  let json =
    fold
      "paper square\n\
       fold (map .a onto .c) as --bd\n\
       @orient .a up\n\
       @yr:hold .a\n\
       @say \"Done.\"\n"
  in
  let open Yojson.Safe.Util in
  let frames = json |> member "file_frames" |> to_list |> List.length in
  let anns = annotations json in
  Alcotest.(check (list string)) "every entry" [ "orient"; "hold"; "say" ]
    (List.map (fun j -> j |> member "key" |> to_string) anns);
  List.iter
    (fun j ->
      Alcotest.(check bool) "no target" true (j |> member "target" = `Null);
      Alcotest.(check int) "the final frame" (frames - 1) (j |> member "frame_index" |> to_int))
    anns;
  let point = List.hd (anns |> List.hd |> member "args" |> to_list) |> member "point" in
  Alcotest.(check (list (float 1e-9))) ".a on .c in the final state" [ 1.; 1. ]
    (point |> member "table" |> to_list |> List.map to_number)

(* At the end of a def body an annotation belongs to the state the body left,
   once per execution. *)
let test_emit_trailing_in_body () =
  let json =
    fold
      "paper square\n\
       def half(.p .q) {\n\
      \  fold (map .p onto .q)\n\
      \  @call .p \"tip\"\n\
       }\n\
       apply half(.a .b)\n\
       apply half(.b .c)\n"
  in
  let open Yojson.Safe.Util in
  let anns = annotations json in
  Alcotest.(check (list int)) "after each execution's fold" [ 1; 2 ]
    (List.map (fun j -> j |> member "frame_index" |> to_int) anns);
  List.iter
    (fun j -> Alcotest.(check bool) "no target" true (j |> member "target" = `Null))
    anns

(* The keys of the program stand before `paper` or after it, before the first
   statement. [author] fills FOLD's [file_author], and every one of them has the
   target "program". *)
let test_emit_program () =
  let json =
    fold
      "@author \"Claude (Anthropic)\"\n\
       @design traditional\n\
       @source \"[ida2020, Fig. 7.19]\"\n\
       unit cm\n\
       paper square 15\n\
       @source \"[candia2025cicada]\"\n\
       @step\n\
       fold (map .a onto .c)\n"
  in
  let open Yojson.Safe.Util in
  Alcotest.(check string) "file_author" "Claude (Anthropic)"
    (json |> member "file_author" |> to_string);
  let anns = annotations json in
  Alcotest.(check (list string)) "keys in reading order"
    [ "author"; "design"; "source"; "source"; "step" ]
    (List.map (fun j -> j |> member "key" |> to_string) anns);
  Alcotest.(check (list string)) "the program is the target of its keys"
    [ "\"program\""; "\"program\""; "\"program\""; "\"program\""; "[0,0]" ]
    (List.map (fun j -> j |> member "target" |> Yojson.Safe.to_string) anns);
  let design = List.nth anns 1 in
  Alcotest.(check string) "traditional is a word" "traditional"
    (List.hd (design |> member "args" |> to_list) |> member "word" |> to_string);
  let source = List.nth anns 2 in
  Alcotest.(check (list string)) "the source is one text" [ "[ida2020, Fig. 7.19]" ]
    (List.map (fun a -> a |> member "text" |> to_string) (source |> member "args" |> to_list));
  Alcotest.(check bool) "no file_author without @author" true
    (fold "paper square\nfold (map .a onto .c)\n" |> member "file_author" = `Null)

(* ---- the geometry never depends on an annotation (ADR 0029) ---- *)

(* Every annotation replaced by spaces, line breaks kept, so every span of
   the rest of the program stays where it was. *)
let blank_annotations (src : string) : string =
  let b = Bytes.of_string src in
  let rec walk = function
    | [] -> ()
    | Ast.Annotation a :: rest ->
        let s, e = a.Ast.a_span in
        for i = s.Lexing.pos_cnum to min (Bytes.length b) e.Lexing.pos_cnum - 1 do
          if Bytes.get b i <> '\n' then Bytes.set b i ' '
        done;
        walk rest
    | Ast.Def (_, _, body, _) :: rest ->
        walk body;
        walk rest
    | _ :: rest -> walk rest
  in
  walk (parse_stmts ~filename:"t.bel" src);
  Bytes.to_string b

let without_annotations json =
  match json with
  | `Assoc fields ->
      `Assoc
        (List.filter (fun (k, _) -> k <> "beloch:annotations" && k <> "file_author") fields)
  | j -> j

let invariant_programs =
  [
    ( "the keys of the program",
      "@author \"Claude (Anthropic)\"\n\
       @design \"Someone\"\n\
       paper square\n\
       @source \"[ida2020, Fig. 7.19]\"\n\
       fold (map .a onto .c) as --bd\n" );
    ( "the vocabulary",
      "paper square\n\
       @step prelim \"Fold the diagonal.\"\n\
       @label first\n\
       @call .a \"top corner\"\n\
       fold (map .a onto .c) as --bd\n\
       @orient --bd vertical\n\
       @say \"Reverse-fold the side.\"\n\
       reverse (map .b onto .c) as --h\n\
       @orient .a .c up\n\
       reverse (map .d onto .c) as --v\n\
       @orient .a down\n" );
    ( "reads that materialize a mark on their way",
      "paper square\n\
       mark (through .a .c) as --m\n\
       @call --m & .a \"the diagonal\"\n\
       @yr:xray #[.b] (map .a onto .c) --m & .c 3/4 \"x\"\n\
       fold (map .a onto .c) as --n\n\
       fold (map .b onto .d)\n" );
    ( "a def body",
      "paper square\n\
       def half(.p .q) {\n\
      \  @step \"Fold it.\"\n\
      \  --l = (through .p .q)\n\
      \  @call --l \"the line\"\n\
      \  fold (map .p onto .q)\n\
       }\n\
       @step\n\
       apply half(.a .b)\n\
       apply half(.b .c)\n" );
  ]

let test_invariant () =
  List.iter
    (fun (name, src) ->
      let with_ = fold src and without = fold (blank_annotations src) in
      Alcotest.(check bool) (name ^ ": annotations were emitted") true
        (annotations with_ <> []);
      Alcotest.(check string) (name ^ ": the same FOLD without them")
        (Yojson.Safe.to_string (without_annotations without))
        (Yojson.Safe.to_string (without_annotations with_)))
    invariant_programs

let () =
  Alcotest.run "annotation"
    [
      ( "parse",
        [
          Alcotest.test_case "keys, namespaces, text" `Quick test_parse;
          Alcotest.test_case "inside a def body" `Quick test_parse_in_body;
        ] );
      ( "check",
        [
          Alcotest.test_case "static and read errors" `Quick test_errors;
          Alcotest.test_case "the keys of the program" `Quick test_program_errors;
        ] );
      ( "emit",
        [
          Alcotest.test_case "beloch:annotations" `Quick test_emit;
          Alcotest.test_case "once per execution of a body" `Quick test_emit_in_body;
          Alcotest.test_case "after the last statement" `Quick test_emit_trailing;
          Alcotest.test_case "after a body's last statement" `Quick test_emit_trailing_in_body;
          Alcotest.test_case "the keys of the program" `Quick test_emit_program;
        ] );
      ( "invariance",
        [ Alcotest.test_case "the geometry ignores annotations" `Quick test_invariant ] );
    ]
