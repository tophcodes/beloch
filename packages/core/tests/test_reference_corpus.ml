(* tests/test_reference_corpus.ml — the guard that holds the kernel to
   spec/BELOCH.md (design doc "The reference corpus test", kernel side of
   "The three runners"). Every tagged block in the document is extracted,
   assembled with its prelude, evaluated in process, and checked against its
   own `; assert` / `; expect error` lines through Bel_assert — the same
   checker the `.bel` corpus runner uses. *)

open Beloch

(* Anchor to the source root of *this* build context, the way
   test_bel_assert.ml does (dune sets DUNE_SOURCEROOT to the workspace
   root). *)
let source_root =
  match Sys.getenv_opt "DUNE_SOURCEROOT" with
  | Some root -> root
  | None -> "../../../../.."

let read path = In_channel.with_open_text path In_channel.input_all

(* ---- Block extraction (design doc "Marking the blocks") ---- *)

(* A `.bel` fenced block's tag, read from pandoc's attribute form of the
   info string: the first class is always `bel`, a second class names the
   kind, and `name=`/`prelude=` are attributes. A bare `bel` (one word, no
   braces) is a whole program, same as `{.bel}`. *)
type tag = Whole | Prelude of string | Frag of string option | Construction of string option

type block = { tag : tag; body : string; fence_line : int (* 1-based, the line the opening fence is on *) }

exception Extract_fail of string

let extract_fail fmt = Printf.ksprintf (fun s -> raise (Extract_fail s)) fmt

let tag_key = function
  | Whole -> "whole"
  | Prelude _ -> "prelude"
  | Frag _ -> "frag"
  | Construction _ -> "construction"

(* attribute-list body, e.g. ".bel .frag prelude=triangle" (braces already
   stripped) -> its key=value attributes, ignoring the leading class
   tokens. *)
let attrs_of (tokens : string list) : (string * string) list =
  List.filter_map
    (fun t ->
      if String.length t > 0 && t.[0] = '.' then None
      else
        match String.index_opt t '=' with
        | Some i -> Some (String.sub t 0 i, String.sub t (i + 1) (String.length t - i - 1))
        | None -> extract_fail "malformed attribute %S" t)
    tokens

(* [info] is the text right after the opening ``` , e.g. "{.bel .frag
   prelude=triangle}" or "bel" or "grammar". [None] when it does not tag a
   Beloch block (a `grammar*` fence, or any other info string), which the
   corpus test skips exactly as the site does. *)
let parse_tag (info : string) : tag option =
  let info = String.trim info in
  if info = "bel" || info = "beloch" then Some Whole
  else if
    String.length info >= 2
    && info.[0] = '{'
    && info.[String.length info - 1] = '}'
  then begin
    let inner = String.sub info 1 (String.length info - 2) in
    match String.split_on_char ' ' inner |> List.filter (fun t -> t <> "") with
    | ".bel" :: rest ->
        let classes = List.filter (fun t -> String.length t > 0 && t.[0] = '.') rest in
        let attrs = attrs_of rest in
        let attr k = List.assoc_opt k attrs in
        (match classes with
        | [] -> Some Whole
        | [ ".prelude" ] -> (
            match attr "name" with
            | Some n -> Some (Prelude n)
            | None -> extract_fail "{.bel .prelude} block with no name=")
        | [ ".frag" ] -> Some (Frag (attr "prelude"))
        | [ ".construction" ] -> Some (Construction (attr "prelude"))
        | _ -> extract_fail "unrecognized .bel block classes: %s" (String.concat " " classes))
    | _ -> None
  end
  else None

(* Scan [src] for fenced code blocks whose info string [parse_tag] resolves,
   in document order. Every fence in spec/*.md opens and closes with a bare
   ``` line (no longer backtick run, no indentation); a block that never
   closes is a malformed document, not a block to silently drop. *)
let extract_blocks (src : string) : block list =
  let lines = String.split_on_char '\n' src |> Array.of_list in
  let n = Array.length lines in
  let blocks = ref [] in
  let i = ref 0 in
  while !i < n do
    let line = lines.(!i) in
    if String.length line >= 3 && String.sub line 0 3 = "```" then begin
      let info = String.sub line 3 (String.length line - 3) in
      let fence_line = !i + 1 in
      let body_start = !i + 1 in
      let j = ref body_start in
      while !j < n && lines.(!j) <> "```" do
        incr j
      done;
      if !j >= n then extract_fail "unterminated fence opened at line %d" fence_line;
      let body = String.concat "\n" (Array.to_list (Array.sub lines body_start (!j - body_start))) in
      (match parse_tag info with
      | Some tag -> blocks := { tag; body; fence_line } :: !blocks
      | None -> ());
      i := !j + 1
    end
    else incr i
  done;
  List.rev !blocks

(* ---- Prelude resolution (design doc "Hidden preludes") ---- *)

let prelude_table (blocks : block list) : (string * string) list =
  List.filter_map (fun b -> match b.tag with Prelude name -> Some (name, b.body) | _ -> None) blocks

(* no trailing newline, matching the convention of a block body extracted by
   [extract_blocks] (its lines are joined by "\n" with none trailing). *)
let default_prelude = "paper square"

let resolve_prelude (preludes : (string * string) list) (name_opt : string option) : string =
  match name_opt with
  | None -> default_prelude
  | Some name -> (
      match List.assoc_opt name preludes with
      | Some body -> body
      | None -> extract_fail "prelude=%s names no block" name)

(* A `.construction` body carries one item per line, a trailing comment, and
   may carry `; assert`/`; expect error` lines. Blank lines and assertion
   lines are stripped before each remaining line is wrapped as `mark
   <line>` (Task 5's block inventory report, "Two requirements on Task 6's
   extractor"). *)
let wrap_construction (body : string) : string =
  String.split_on_char '\n' body
  |> List.filter (fun l -> String.trim l <> "" && not (Bel_assert.is_assertion_line l))
  |> List.map (fun l -> "mark " ^ l)
  |> String.concat "\n"

(* The full program source a block evaluates as. A `.prelude` block is a
   program in its own right (design: "parses and evaluates under its own
   prelude" — a prelude never itself carries `prelude=`, so this is the
   [Whole] case under another name); the other three kinds prepend the
   resolved prelude, wrapping construction lines first. *)
let assemble (preludes : (string * string) list) (b : block) : string =
  match b.tag with
  | Whole | Prelude _ -> b.body
  | Frag prelude_name -> resolve_prelude preludes prelude_name ^ "\n" ^ b.body
  | Construction prelude_name ->
      resolve_prelude preludes prelude_name ^ "\n" ^ wrap_construction b.body

(* ---- Evaluating and checking one block ---- *)

(* [verify_block preludes b] is [Ok ()] when [b] assembles, evaluates and
   checks clean, and [Error msg] naming the first thing that did not — the
   five failure modes of Acceptance 8: a block that does not fold, an
   `; expect error` block that succeeds or fails with the wrong message, a
   failing `; assert`, and a `prelude=` naming no block. A pure result
   (rather than an Alcotest call) so the failure modes are directly
   testable against small inline samples, not only by breaking the real
   corpus. *)
let verify_block (preludes : (string * string) list) (b : block) : (unit, string) result =
  match assemble preludes b with
  | exception Extract_fail msg -> Error msg
  | program -> (
      match Bel_assert.extract b.body with
      | exception Bel_assert.Harness_fail msg -> Error msg
      | parsed -> (
          match Bel_assert.expected_error (List.map snd parsed) with
          | exception Bel_assert.Harness_fail msg -> Error msg
          | Some substr -> (
              match Eval.eval_folded (Beloch.parse ~filename:"BELOCH.md" program) with
              | (_ : Eval.folded) ->
                  Error (Printf.sprintf "expected an error containing %S, but eval succeeded" substr)
              | exception Error.Beloch_error (_, msg, _) -> (
                  match Bel_assert.check_error_message ~expected:substr msg with
                  | () -> Ok ()
                  | exception Bel_assert.Harness_fail m -> Error m))
          | None -> (
              match Eval.eval_folded (Beloch.parse ~filename:"BELOCH.md" program) with
              | fd -> (
                  match List.iter (fun (_, a) -> Bel_assert.check fd a) parsed with
                  | () -> Ok ()
                  | exception Bel_assert.Harness_fail msg -> Error msg)
              | exception Error.Beloch_error (_, msg, _) ->
                  Error (Printf.sprintf "unexpected evaluation error: %s" msg))))

let check_ok label result =
  match result with Ok () -> () | Error msg -> Alcotest.failf "%s: %s" label msg

let check_error_containing label substr result =
  match result with
  | Ok () -> Alcotest.failf "%s: expected to fail (%S), but it passed" label substr
  | Error msg ->
      if not (Bel_assert.contains_substring msg substr) then
        Alcotest.failf "%s: failure %S does not contain %S" label msg substr

(* ---- Extractor tests on small inline samples ---- *)

let one_of_each_kind =
  {|prose before

```{.bel .prelude name=p}
paper square
```

```{.bel .frag prelude=p}
mark (through .a .c) as --ac
```

```{.bel .construction prelude=p}
(align (.a onto .c))
```

```{.bel}
paper square
```

```grammar
not ours
```
|}

let test_attribute_parsing () =
  let blocks = extract_blocks one_of_each_kind in
  Alcotest.(check (list string))
    "tags found, grammar block skipped"
    [ "prelude"; "frag"; "construction"; "whole" ]
    (List.map (fun b -> tag_key b.tag) blocks)

let test_bare_bel_is_whole () =
  Alcotest.(check bool) "bare bel" true
    (match extract_blocks "```bel\npaper square\n```\n" with
    | [ { tag = Whole; _ } ] -> true
    | _ -> false)

let test_unrecognized_class_fails () =
  match extract_blocks "```{.bel .mystery}\nx\n```\n" with
  | _ -> Alcotest.fail "expected Extract_fail on an unknown .bel class"
  | exception Extract_fail _ -> ()

let test_prelude_resolution () =
  let src =
    "```{.bel .prelude name=sheet}\npaper square\nmark (through .a .c) as --ac\n```\n\
     ```{.bel .frag prelude=sheet}\nmark (through .b .d) as --bd\n```\n"
  in
  let blocks = extract_blocks src in
  let preludes = prelude_table blocks in
  let frag = List.find (fun b -> match b.tag with Frag _ -> true | _ -> false) blocks in
  let assembled = assemble preludes frag in
  Alcotest.(check bool) "prelude prepended"
    true
    (String.length assembled > String.length frag.body
    && String.sub assembled 0 12 = "paper square")

let test_default_prelude () =
  let b = { tag = Frag None; body = "mark (through .a .c) as --ac"; fence_line = 0 } in
  Alcotest.(check string) "default prelude is paper square"
    (default_prelude ^ "\n" ^ b.body) (assemble [] b)

let test_missing_prelude_fails () =
  let b = { tag = Frag (Some "nope"); body = "mark (through .a .c) as --ac"; fence_line = 0 } in
  match assemble [] b with
  | _ -> Alcotest.fail "expected Extract_fail for an undefined prelude"
  | exception Extract_fail msg ->
      Alcotest.(check bool) "names the missing prelude" true
        (Bel_assert.contains_substring msg "nope")

let test_construction_wrapping () =
  let body =
    "(align (.a onto .c))                            ; axiom 2\n\
     (align (through .a) (through .b))               ; axiom 1\n\n\
     ; assert .p = (1/2, 1/2)\n\
     ; assert .q = (1/2, 0)\n"
  in
  Alcotest.(check string) "each line wrapped, blanks and assertions stripped"
    "mark (align (.a onto .c))                            ; axiom 2\n\
     mark (align (through .a) (through .b))               ; axiom 1"
    (wrap_construction body)

let test_assertion_stripping_matches_bel_assert () =
  let body = "mark (through .a .c)\n\n; assert faces = 1\n; expect error \"never both\"\n" in
  let extracted = Bel_assert.extract body in
  Alcotest.(check int) "two assertion lines extracted" 2 (List.length extracted);
  Alcotest.(check bool) "the program line is not an assertion line" true
    (not (Bel_assert.is_assertion_line "mark (through .a .c)"))

(* ---- The five failure modes of Acceptance 8, each on a small sample ---- *)

let test_failure_does_not_fold () =
  let b = { tag = Whole; body = "paper square\nfold (map .a onto .c) (moving .a) (over .b) (mountain)\n"; fence_line = 0 } in
  check_error_containing "does-not-fold" "derives its direction" (verify_block [] b)

let test_failure_expect_error_succeeds () =
  let b =
    { tag = Whole; body = "paper square\nfold (map .a onto .c)\n\n; expect error \"never happens\"\n"; fence_line = 0 }
  in
  check_error_containing "expect-error-but-succeeded" "expected an error containing" (verify_block [] b)

let test_failure_expect_error_wrong_message () =
  let b =
    { tag = Whole;
      body =
        "paper square\nfold (map .a onto .c) (moving .a) (over .b) (mountain)\n\n\
         ; expect error \"a completely different message\"\n";
      fence_line = 0 }
  in
  check_error_containing "expect-error-wrong-message" "does not contain" (verify_block [] b)

let test_failure_assert_does_not_hold () =
  let b = { tag = Whole; body = "paper square\nmark (through .a .c) as --ac\n\n; assert faces = 99\n"; fence_line = 0 } in
  check_error_containing "assert-does-not-hold" "faces = " (verify_block [] b)

let test_failure_unknown_prelude () =
  let b = { tag = Frag (Some "ghost"); body = "mark (through .a .c) as --ac"; fence_line = 0 } in
  check_error_containing "unknown-prelude" "ghost" (verify_block [] b)

let test_success_case () =
  let b = { tag = Whole; body = "paper square\nmark (through .a .c) as --ac\n\n; assert faces = 1\n"; fence_line = 0 } in
  check_ok "success" (verify_block [] b)

let extractor_tests =
  [
    Alcotest.test_case "attribute parsing, grammar blocks skipped" `Quick test_attribute_parsing;
    Alcotest.test_case "bare `bel` is a whole program" `Quick test_bare_bel_is_whole;
    Alcotest.test_case "an unrecognized .bel class fails" `Quick test_unrecognized_class_fails;
    Alcotest.test_case "prelude resolution prepends the named prelude" `Quick test_prelude_resolution;
    Alcotest.test_case "no prelude= uses paper square" `Quick test_default_prelude;
    Alcotest.test_case "an undefined prelude= fails, naming it" `Quick test_missing_prelude_fails;
    Alcotest.test_case "construction wrapping strips blanks and assertions" `Quick test_construction_wrapping;
    Alcotest.test_case "assertion lines match Bel_assert.is_assertion_line" `Quick
      test_assertion_stripping_matches_bel_assert;
  ]

let failure_mode_tests =
  [
    Alcotest.test_case "a block that does not fold" `Quick test_failure_does_not_fold;
    Alcotest.test_case "an expect-error block that succeeds" `Quick test_failure_expect_error_succeeds;
    Alcotest.test_case "an expect-error block with the wrong message" `Quick
      test_failure_expect_error_wrong_message;
    Alcotest.test_case "a failing assert line" `Quick test_failure_assert_does_not_hold;
    Alcotest.test_case "a prelude= naming no block" `Quick test_failure_unknown_prelude;
    Alcotest.test_case "a clean block passes" `Quick test_success_case;
  ]

(* ---- The real corpus: spec/BELOCH.md ---- *)

(* Block inventory of spec/BELOCH.md, by tag (Task 5's count: 6 preludes, 7
   fragments — 2 under the default prelude, 5 named — and 1 construction).
   Ceiling: this catches the OCaml extractor drifting from the document, not
   from the tree-sitter and build-side copies of the same rule; update the
   three together when a tagged block is added to BELOCH.md. *)
let expected_inventory = [ ("construction", 1); ("frag", 7); ("prelude", 6); ("whole", 0) ]

let count_by_tag (blocks : block list) : (string * int) list =
  let base = List.map (fun (k, _) -> (k, 0)) expected_inventory in
  List.fold_left
    (fun acc b ->
      List.map (fun (k, n) -> if k = tag_key b.tag then (k, n + 1) else (k, n)) acc)
    base blocks

let corpus_test_cases () =
  let path = Filename.concat source_root "spec/BELOCH.md" in
  let blocks = extract_blocks (read path) in
  let preludes = prelude_table blocks in
  let inventory_case =
    Alcotest.test_case "block inventory matches the constant" `Quick (fun () ->
        Alcotest.(check (list (pair string int)))
          "counts per tag" (List.sort compare expected_inventory) (List.sort compare (count_by_tag blocks)))
  in
  let block_case (b : block) =
    let name = Printf.sprintf "line %d (%s)" b.fence_line (tag_key b.tag) in
    Alcotest.test_case name `Quick (fun () -> check_ok name (verify_block preludes b))
  in
  inventory_case :: List.map block_case blocks

let () =
  Alcotest.run "reference_corpus"
    [
      ("extractor", extractor_tests);
      ("failure modes", failure_mode_tests);
      ("BELOCH.md", corpus_test_cases ());
    ]
