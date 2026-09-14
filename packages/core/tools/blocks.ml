(* tools/blocks.ml: the build-side reference-corpus capture (design doc
   "The three runners", build side; Acceptance 10). Selects and assembles
   the tagged blocks of spec/BELOCH.md by the same rule
   packages/core/tests/test_reference_corpus.ml uses, evaluates each one in
   process, and writes one entry per block to _build/spec/blocks.json, the
   input packages/www/src/lib/remark-bel.ts reads to render the outcome
   under each program. Never exits nonzero over a block that fails to fold:
   that is what the kernel-side corpus test guards; this tool exists so the
   site still builds and shows the failure.

   Run from the repo root:
     dune exec packages/core/tools/blocks.exe *)

open Beloch

(* ---- Block extraction and prelude resolution (mirrors
   test_reference_corpus.ml's rule; design doc "Marking the blocks" and
   "Hidden preludes"). A third copy, in the same language as that one: the
   design accepts the duplication (three extractors, two languages) rather
   than sharing a module across kernel test and build tool. ---- *)

type tag =
  | Whole
  | Prelude of string
  | Frag of string option
  | Construction of string option
  | Malformed of string
      (** A `.bel`-tagged block whose classes or attributes [parse_tag] does
          not recognize: an unrecognized class, a `.prelude` with no `name=`,
          or a bare attribute token with no `=`. Still occupies a block index
          (remark-bel.ts's parseFenceTag counts it too, not knowing it is
          malformed), but [compute_outcome] turns it straight into an
          [Error_result] without assembling or evaluating it: a malformed tag
          must not stop the rest of the document from building (test
          coverage: a throwaway fixture, not spec/BELOCH.md). *)

type block = { tag : tag; body : string; fence_line : int (* 1-based, the line the opening fence is on *) }

exception Extract_fail of string

let extract_fail fmt = Printf.ksprintf (fun s -> raise (Extract_fail s)) fmt

let attrs_of (tokens : string list) : (string * string) list =
  List.filter_map
    (fun t ->
      if String.length t > 0 && t.[0] = '.' then None
      else
        match String.index_opt t '=' with
        | Some i -> Some (String.sub t 0 i, String.sub t (i + 1) (String.length t - i - 1))
        | None -> extract_fail "malformed attribute %S" t)
    tokens

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
    | ".bel" :: rest -> (
        (* A malformed tag (unrecognized class, a `.prelude` with no name=,
           or a bare attribute) is still a `.bel` block by intent, so it
           keeps its slot as [Malformed] instead of escaping as a build-
           killing exception; see the [Malformed] constructor. *)
        try
          let classes = List.filter (fun t -> String.length t > 0 && t.[0] = '.') rest in
          let attrs = attrs_of rest in
          let attr k = List.assoc_opt k attrs in
          match classes with
          | [] -> Some Whole
          | [ ".prelude" ] -> (
              match attr "name" with
              | Some n -> Some (Prelude n)
              | None -> extract_fail "{.bel .prelude} block with no name=")
          | [ ".frag" ] -> Some (Frag (attr "prelude"))
          | [ ".construction" ] -> Some (Construction (attr "prelude"))
          | _ -> extract_fail "unrecognized .bel block classes: %s" (String.concat " " classes)
        with Extract_fail msg -> Some (Malformed msg))
    | _ -> None
  end
  else None

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

let prelude_table (blocks : block list) : (string * string) list =
  List.filter_map (fun b -> match b.tag with Prelude name -> Some (name, b.body) | _ -> None) blocks

let default_prelude = "paper square"

let resolve_prelude (preludes : (string * string) list) (name_opt : string option) : string =
  match name_opt with
  | None -> default_prelude
  | Some name -> (
      match List.assoc_opt name preludes with
      | Some body -> body
      | None -> extract_fail "prelude=%s names no block" name)

(* Same wrapping rule as test_reference_corpus.ml's wrap_construction, plus
   the mapping a diagnostic needs to point back at the block's own text:
   [orig_line.(k)] is the 1-based body line of the (k+1)-th wrapped line
   (0-based array index), since wrapping drops blank and assertion lines. *)
let wrap_construction_mapped (body : string) : string * int array =
  let indexed = List.mapi (fun i l -> (i + 1, l)) (String.split_on_char '\n' body) in
  let kept =
    List.filter (fun (_, l) -> String.trim l <> "" && not (Bel_assert.is_assertion_line l)) indexed
  in
  let wrapped = String.concat "\n" (List.map (fun (_, l) -> "mark " ^ l) kept) in
  (wrapped, Array.of_list (List.map fst kept))

(* [assemble_full preludes b] is [(program, prelude_lines, orig_line)]: the
   full source [b] evaluates as, how many of its leading lines belong to a
   prepended prelude (0 for [Whole]/[Prelude]), and, for [Construction]
   only, the wrapped-line -> body-line map [locate] needs. *)
let assemble_full (preludes : (string * string) list) (b : block) : string * int * int array =
  match b.tag with
  | Whole | Prelude _ -> (b.body, 0, [||])
  | Frag prelude_name ->
      let p = resolve_prelude preludes prelude_name in
      (p ^ "\n" ^ b.body, List.length (String.split_on_char '\n' p), [||])
  | Construction prelude_name ->
      let p = resolve_prelude preludes prelude_name in
      let wrapped, orig_line = wrap_construction_mapped b.body in
      (p ^ "\n" ^ wrapped, List.length (String.split_on_char '\n' p), orig_line)
  | Malformed _ -> invalid_arg "assemble_full: Malformed block (compute_outcome must not call this)"

(* Maps a 1-based line number in the assembled program back onto the
   block's own body text: [None] when it falls inside a prepended prelude
   (design doc "Hidden preludes": recorded as a message with no excerpt),
   [Some (body_line, col_offset)] otherwise, where [col_offset] is the width
   of the synthetic "mark " prefix a .construction line carries in the
   assembled program but not in the body as written. *)
let locate (b : block) (prelude_lines : int) (orig_line : int array) (assembled_line : int) :
    (int * int) option =
  match b.tag with
  | Whole | Prelude _ -> Some (assembled_line, 0)
  | Frag _ -> if assembled_line <= prelude_lines then None else Some (assembled_line - prelude_lines, 0)
  | Construction _ ->
      if assembled_line <= prelude_lines then None
      else
        let k = assembled_line - prelude_lines in
        if k >= 1 && k <= Array.length orig_line then Some (orig_line.(k - 1), String.length "mark ")
        else None
  | Malformed _ -> invalid_arg "locate: Malformed block (compute_outcome must not call this)"

(* ---- Evaluating and capturing one block's outcome ---- *)

type assert_result = { text : string; verified : bool; note : string option }

(* The pre-rendered diagnostic plus the position [Diagnostic.render] drew it
   from, so remark-bel.ts can carry both without redoing the remap in
   TypeScript. *)
type diagnostic_info = { diag_text : string; diag_line : int; diag_col : int; diag_end_col : int }

type outcome =
  | Ok_result of assert_result list
  | Ok_but_expected_error of string (* an `expect error` that never raised *)
  | Error_result of { message : string; expected : bool; diagnostic : diagnostic_info option }

(* [expected] means what test_reference_corpus.ml's verify_block means:
   whether Bel_assert.check_error_message accepts the raised message against
   the block's `; expect error` substring, not merely whether the block
   carries one. A syntactic reading (does the block carry `; expect error`
   at all) would mark a block "expected" even when its message is the wrong
   one, the exact case verify_block fails the build over. *)
let compute_outcome (filename : string) (preludes : (string * string) list) (b : block) : outcome =
  match b.tag with
  | Malformed msg ->
      Error_result
        { message = Printf.sprintf "line %d: %s" b.fence_line msg; expected = false; diagnostic = None }
  | Whole | Prelude _ | Frag _ | Construction _ -> (
      try
        let program, prelude_lines, orig_line = assemble_full preludes b in
        let parsed = Bel_assert.extract b.body in
        let expects = Bel_assert.expected_error (List.map snd parsed) in
        match Eval.eval_folded (Beloch.parse ~filename program) with
        | fd -> (
            match expects with
            | Some substr ->
                Ok_but_expected_error
                  (Printf.sprintf "expected an error containing %S, but eval succeeded" substr)
            | None ->
                Ok_result
                  (List.map
                     (fun (text, a) ->
                       match Bel_assert.check fd a with
                       | () -> { text; verified = true; note = None }
                       | exception Bel_assert.Harness_fail msg -> { text; verified = false; note = Some msg })
                     parsed))
        | exception Error.Beloch_error ((start, finish), msg) ->
            let expected =
              match expects with
              | None -> false
              | Some substr -> (
                  match Bel_assert.check_error_message ~expected:substr msg with
                  | () -> true
                  | exception Bel_assert.Harness_fail _ -> false)
            in
            let line_no = start.Lexing.pos_lnum in
            let diagnostic =
              match locate b prelude_lines orig_line line_no with
              | None -> None
              | Some (body_line, col_offset) ->
                  let start_col = max 0 (start.Lexing.pos_cnum - start.Lexing.pos_bol - col_offset) in
                  let end_col =
                    if finish.Lexing.pos_lnum = line_no then
                      finish.Lexing.pos_cnum - finish.Lexing.pos_bol - col_offset
                    else start_col + 1
                  in
                  let fabricated : Error.span =
                    ( { Lexing.pos_fname = filename; pos_lnum = body_line; pos_bol = 0; pos_cnum = start_col },
                      { Lexing.pos_fname = filename; pos_lnum = body_line; pos_bol = 0; pos_cnum = end_col } )
                  in
                  Some
                    {
                      diag_text = Diagnostic.render ~source:b.body ~span:fabricated ~msg;
                      diag_line = body_line;
                      diag_col = start_col;
                      diag_end_col = end_col;
                    }
            in
            Error_result { message = msg; expected; diagnostic }
      with
      | Extract_fail msg ->
          Error_result
            { message = Printf.sprintf "line %d: %s" b.fence_line msg; expected = false; diagnostic = None }
      | Bel_assert.Harness_fail msg ->
          Error_result
            { message = Printf.sprintf "line %d: %s" b.fence_line msg; expected = false; diagnostic = None })

(* ---- JSON encoding ---- *)

let json_of_assert (a : assert_result) : Yojson.Basic.t =
  `Assoc
    ((("text", `String a.text) :: [ ("verified", `Bool a.verified) ])
    @ match a.note with Some n -> [ ("message", `String n) ] | None -> [])

let json_of_entry (index : int) (outcome : outcome) : Yojson.Basic.t =
  match outcome with
  | Ok_result asserts ->
      `Assoc
        [
          ("index", `Int index);
          ("status", `String "ok");
          ("expected", `Bool false);
          ("asserts", `List (List.map json_of_assert asserts));
        ]
  | Ok_but_expected_error msg ->
      `Assoc
        [
          ("index", `Int index);
          ("status", `String "ok");
          ("expected", `Bool true);
          ("message", `String msg);
          ("asserts", `List []);
        ]
  | Error_result { message; expected; diagnostic } ->
      `Assoc
        ([
           ("index", `Int index);
           ("status", `String "error");
           ("expected", `Bool expected);
           ("message", `String message);
           ("asserts", `List []);
         ]
        @
        match diagnostic with
        | Some d ->
            [
              ("diagnostic", `String d.diag_text);
              ("line", `Int d.diag_line);
              ("col", `Int d.diag_col);
              ("end_col", `Int d.diag_end_col);
            ]
        | None -> [])

(* ---- Entry point ---- *)

let rec mkdir_p d =
  if d <> "." && d <> "/" && not (Sys.file_exists d) then begin
    mkdir_p (Filename.dirname d);
    Sys.mkdir d 0o755
  end

let read path = In_channel.with_open_text path In_channel.input_all

let () =
  let doc = if Array.length Sys.argv > 1 then Sys.argv.(1) else "spec/BELOCH.md" in
  let filename = Filename.basename doc in
  let blocks = extract_blocks (read doc) in
  let preludes = prelude_table blocks in
  let entries =
    List.mapi (fun index b -> json_of_entry index (compute_outcome filename preludes b)) blocks
  in
  let json : Yojson.Basic.t = `Assoc [ (doc, `List entries) ] in
  mkdir_p "_build/spec";
  Out_channel.with_open_text "_build/spec/blocks.json" (fun oc ->
      Out_channel.output_string oc (Yojson.Basic.pretty_to_string json))
