# Diagnostic Error Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render every `Beloch_error` as a rustc-style source-context block (header, `-->` location, line-number gutter, up to 3 lines of prior context, the error line, a caret underline under the span, and the message) instead of the current one-liner.

**Architecture:** A new pure module `lib/diagnostic.ml` turns `(source, span, msg)` into the rendered string. `bin/main.ml` reads the source, catches `Beloch_error`, and prints the rendered block to stderr. No changes to error-raising sites — the renderer uses whatever span each error already carries.

**Tech Stack:** OCaml, dune, alcotest (+ `str` for substring assertions), `Lexing.position` (start/end).

## Global Constraints

- The renderer is a pure function `Diagnostic.render : source:string -> span:Error.span -> msg:string -> string`. No I/O in the module.
- `span = Lexing.position * Lexing.position`; column = `pos_cnum - pos_bol` (0-based, byte offset); line = `pos_lnum` (1-based); file = `pos_fname`.
- Show up to 3 lines of context before the error line (fewer at top of file).
- Caret width = `max 1 (end_col - start_col)`; for a multi-line span, underline from the start column to the end of the start line.
- New module must be re-exported from `lib/beloch.ml` (facade uses `module X = X`) or `open Beloch` in tests won't see it.
- Byte-offset columns are exact for ASCII `.bel`; UTF-8 caret drift in multibyte comment text is accepted (out of scope).
- No ANSI color (out of scope).

---

### Task 1: `lib/diagnostic.ml` renderer + unit tests

**Files:**
- Create: `lib/diagnostic.ml`
- Modify: `lib/beloch.ml` (add the facade re-export)
- Create: `tests/test_diagnostic.ml`
- Modify: `tests/dune` (register the test)

**Interfaces:**
- Produces: `Diagnostic.render : source:string -> span:Error.span -> msg:string -> string`
  (returns the full multi-line block, trailing newline included)

- [ ] **Step 1: Register the test executable**

Add to `tests/dune` (append after the existing `(test …)` stanzas):
```
(test
 (name test_diagnostic)
 (libraries beloch alcotest str))
```

- [ ] **Step 2: Write the failing unit tests**

Create `tests/test_diagnostic.ml`:
```ocaml
open Beloch

(* build a Lexing.position: file, 1-based line, byte offset of line start, and
   absolute byte offset *)
let pos fname lnum bol cnum =
  { Lexing.pos_fname = fname; pos_lnum = lnum; pos_bol = bol; pos_cnum = cnum }

let contains hay needle =
  try ignore (Str.search_forward (Str.regexp_string needle) hay 0); true
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
  Alcotest.(check bool) "error line with gutter" true (contains out "3 | --l: through .a .a");
  Alcotest.(check bool) "prior context line 2" true (contains out "2 | line two");
  Alcotest.(check bool) "prior context line 1" true (contains out "1 | line one");
  (* 13-char span => 13 carets *)
  Alcotest.(check bool) "caret width" true (contains out (String.make 13 '^'));
  (* context stops 3 lines back: line four (below) must NOT appear *)
  Alcotest.(check bool) "no lines after the error" false (contains out "line four")

let test_top_of_file () =
  (* error on line 1: no prior context, no crash *)
  let span = (pos "f.bel" 1 0 0, pos "f.bel" 1 0 4) in
  let out = Diagnostic.render ~source:src ~span ~msg:"boom" in
  Alcotest.(check bool) "line 1 shown" true (contains out "1 | line one");
  Alcotest.(check bool) "header" true (contains out "error: boom")

let () =
  Alcotest.run "diagnostic"
    [ ("render",
       [ Alcotest.test_case "basic block" `Quick test_basic;
         Alcotest.test_case "top of file" `Quick test_top_of_file ]) ]
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd /home/toph/Projects/beloch-wt/diagnostic-errors && dune build 2>&1 | head`
Expected: FAIL — `Unbound module Diagnostic` (module + facade re-export not created yet).

- [ ] **Step 4: Create the renderer**

Create `lib/diagnostic.ml`:
```ocaml
(** Render a Beloch_error as a rustc-style source-context block. Pure: source
    text + span + message -> string. Uses whatever span the error carries. *)

let render ~(source : string) ~(span : Error.span) ~(msg : string) : string =
  let start, finish = span in
  let lines = String.split_on_char '\n' source in
  let line_at n =
    match List.nth_opt lines (n - 1) with Some l -> l | None -> ""
  in
  let line_no = start.Lexing.pos_lnum in
  let start_col = start.Lexing.pos_cnum - start.Lexing.pos_bol in
  let end_col =
    if finish.Lexing.pos_lnum = line_no then
      finish.Lexing.pos_cnum - finish.Lexing.pos_bol
    else String.length (line_at line_no) (* multi-line: to end of start line *)
  in
  let start_col = max 0 start_col in
  let caret_w = max 1 (end_col - start_col) in
  let file = start.Lexing.pos_fname in
  let first = max 1 (line_no - 3) in
  let gutter_w = String.length (string_of_int line_no) in
  let blank = String.make gutter_w ' ' in
  let pad n =
    let s = string_of_int n in
    String.make (gutter_w - String.length s) ' ' ^ s
  in
  let buf = Buffer.create 256 in
  Buffer.add_string buf (Printf.sprintf "error: %s\n" msg);
  Buffer.add_string buf
    (Printf.sprintf "%s--> %s:%d:%d\n" blank file line_no (start_col + 1));
  Buffer.add_string buf (Printf.sprintf "%s |\n" blank);
  for n = first to line_no do
    Buffer.add_string buf (Printf.sprintf "%s | %s\n" (pad n) (line_at n))
  done;
  let caret = String.make start_col ' ' ^ String.make caret_w '^' in
  Buffer.add_string buf (Printf.sprintf "%s | %s %s\n" blank caret msg);
  Buffer.contents buf
```

- [ ] **Step 5: Re-export the module from the facade**

In `lib/beloch.ml`, add alongside the other `module X = X` lines (e.g. after `module Error = Error`):
```ocaml
module Diagnostic = Diagnostic
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd /home/toph/Projects/beloch-wt/diagnostic-errors && dune exec tests/test_diagnostic.exe 2>&1 | tail -20`
Expected: PASS — `Test Successful` (2 test cases).

- [ ] **Step 7: Commit**

```bash
cd /home/toph/Projects/beloch-wt/diagnostic-errors
git add lib/diagnostic.ml lib/beloch.ml tests/test_diagnostic.ml tests/dune
git commit -m "feat(diagnostic): rustc-style source-context error renderer"
```

---

### Task 2: Wire the renderer into the CLI + integration test

**Files:**
- Modify: `bin/main.ml` (the `run_fold` function)
- Modify: `tests/test_diagnostic.ml` (add an integration test that drives a real error)

**Interfaces:**
- Consumes: `Diagnostic.render` (Task 1)

- [ ] **Step 1: Write the failing integration test**

In `tests/test_diagnostic.ml`, add this test (before the `let () = Alcotest.run …`):
```ocaml
(* a real evaluator error carries a real span through fold_string; render it *)
let test_integration () =
  let source = "paper square\n--l: through .a .a\n" in
  let rendered =
    try
      ignore (Beloch.fold_string ~filename:"t.bel" source);
      "NO ERROR"
    with Error.Beloch_error (span, msg) ->
      Diagnostic.render ~source ~span ~msg
  in
  Alcotest.(check bool) "renders an error block" true (contains rendered "error:");
  Alcotest.(check bool) "has a location arrow" true (contains rendered "--> t.bel:");
  Alcotest.(check bool) "has a caret" true (contains rendered "^");
  Alcotest.(check bool) "shows the offending line" true
    (contains rendered "through .a .a")
```
And add its case to the `Alcotest.run` list (in the `"render"` group):
```ocaml
         Alcotest.test_case "integration via fold_string" `Quick test_integration;
```

- [ ] **Step 2: Run to verify it passes at the module level (renderer already works)**

Run: `cd /home/toph/Projects/beloch-wt/diagnostic-errors && dune exec tests/test_diagnostic.exe 2>&1 | tail -20`
Expected: PASS — the integration test drives a real `through .a .a` error and renders it. (This test exercises the library path; the CLI wiring in Step 3 is what a user sees.)

- [ ] **Step 3: Wire the renderer into `bin/main.ml`**

Replace the `run_fold` function in `bin/main.ml` with:
```ocaml
let run_fold file =
  match In_channel.with_open_text file In_channel.input_all with
  | exception Sys_error msg ->
      Printf.eprintf "%s\n" msg;
      exit 1
  | src -> (
      try
        let json = Beloch.fold_string ~filename:file src in
        print_endline (Yojson.Safe.pretty_to_string json)
      with Error.Beloch_error (span, msg) ->
        prerr_string (Diagnostic.render ~source:src ~span ~msg);
        exit 1)
```
(`Diagnostic` resolves via the top-of-file `open Beloch`.)

- [ ] **Step 4: Verify the whole build + a real CLI run**

Run:
```bash
cd /home/toph/Projects/beloch-wt/diagnostic-errors
dune build 2>&1 | tail -5
printf 'paper square\n--l: through .a .a\n' > /tmp/diag-test.bel
dune exec beloch -- fold /tmp/diag-test.bel
```
Expected: `dune build` clean; the CLI prints an `error:` block with `--> /tmp/diag-test.bel:2:…`, the source line `2 | --l: through .a .a`, and a caret line, then exits non-zero.

- [ ] **Step 5: Commit**

```bash
cd /home/toph/Projects/beloch-wt/diagnostic-errors
git add bin/main.ml tests/test_diagnostic.ml
git commit -m "feat(cli): render Beloch errors as source-context diagnostics"
```

---

## Self-Review

**Spec coverage:**
- Source-context block (header, `-->`, gutter, ≤3 context lines, error line, caret, msg) → Task 1 renderer ✓
- Uses existing spans, no per-site surgery → Task 1 (renderer is span-agnostic) ✓
- Wire into the single catch site → Task 2 `bin/main.ml` ✓
- Fallback when source unreadable → Task 2 (`Sys_error` arm keeps the plain message) ✓
- Edge cases (top of file, multi-line span, empty span) → Task 1 (`first = max 1 …`, multi-line `end_col`, `caret_w = max 1 …`); top-of-file has a unit test ✓
- Testing: unit (basic + top-of-file), integration via `fold_string` → Tasks 1 & 2 ✓

**Placeholder scan:** none — every step has complete code.

**Type consistency:** `Diagnostic.render ~source ~span ~msg` is defined in Task 1 and consumed identically in Task 2's test and `bin/main.ml`. `Error.span` = `Lexing.position * Lexing.position` used consistently. `pos` helper matches `Lexing.position` field names.

**Note for the implementer:** the Bash cwd resets to the main repo between commands — every `dune`/`git` command in this plan `cd`s into the worktree `/home/toph/Projects/beloch-wt/diagnostic-errors` first. Keep that.
