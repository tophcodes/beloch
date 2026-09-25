(* Annotations (spec/BELOCH.md, Annotations; ADR 0029). *)

open Beloch

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
    Beloch.parse ~filename:"t.bel"
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
    Beloch.parse ~filename:"t.bel"
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
  expect_error "none follows" (fun () ->
      fold "paper square\nfold (map .a onto .c)\n@say \"Done.\"\n");
  expect_error "@orient takes" (fun () -> fold (program "@orient .a sideways\n"));
  expect_error "@orient takes" (fun () -> fold (program "@orient .a vertical\n"));
  expect_error "@call takes" (fun () -> fold (program "@call \"corner\" .a\n"));
  expect_error "closing quote" (fun () -> fold (program "@say \"open\n"));
  expect_error "undefined point .zz" (fun () ->
      fold (program "@call .zz \"nowhere\"\n"))

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
  walk (Beloch.parse ~filename:"t.bel" src);
  Bytes.to_string b

let without_annotations json =
  match json with
  | `Assoc fields -> `Assoc (List.filter (fun (k, _) -> k <> "beloch:annotations") fields)
  | j -> j

let invariant_programs =
  [
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
       reverse (map .d onto .c) as --v\n" );
    ( "reads that materialise a mark on their way",
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
      ("check", [ Alcotest.test_case "static and read errors" `Quick test_errors ]);
      ( "emit",
        [
          Alcotest.test_case "beloch:annotations" `Quick test_emit;
          Alcotest.test_case "once per execution of a body" `Quick test_emit_in_body;
        ] );
      ( "invariance",
        [ Alcotest.test_case "the geometry ignores annotations" `Quick test_invariant ] );
    ]
