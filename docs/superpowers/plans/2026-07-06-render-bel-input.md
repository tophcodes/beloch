# `beloch render` accepts `.fold` and `.bel` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `beloch render f.bel out.svg` and `beloch render f.fold out.svg` both work directly, no manual `beloch fold | fold2svg.ts` piping, no temp file.

**Architecture:** All changes live in `bin/`. A new tiny `render_cli` library holds two pure-ish helpers (`which`, `dim`) that are unit-testable without needing the `beloch-render` binary. `bin/main.ml`'s `run_render` uses `which` to gate dispatch: `.bel` → evaluate via `Beloch.fold_string` and pipe the resulting JSON into `beloch-render`'s stdin over a real `Unix.pipe`; anything else → unchanged `execv` passthrough. `usage()` grows the same PATH check to print a dimmed `[unavailable: ...]` hint on the render line.

**Tech Stack:** OCaml (`dune`, `alcotest`, stdlib `Unix`), no new deps.

## Global Constraints

- OCaml/TypeScript boundary stays FOLD JSON only (ADR-0001) — no changes to `render/render-svg`.
- No temp files — JSON goes through a real pipe into `beloch-render`'s stdin.
- ANSI dimming only, gated on `Unix.isatty Unix.stderr` (usage/hint text is written to stderr) — no color, no other TTY machinery.
- Reuse the exact `.bel` error-rendering pattern already in `run_fold` (`Error.Beloch_error` → `Diagnostic.render`) — don't invent new error plumbing.

---

### Task 1: `render_cli` helper library (`which` + `dim`)

**Files:**
- Create: `bin/render_cli.ml`
- Modify: `bin/dune` (add a `library` stanza alongside the existing `executable`)
- Create: `tests/test_render_cli.ml`
- Modify: `tests/dune` (add a `test` stanza)

**Interfaces:**
- Produces: `Render_cli.which : string -> string option` — resolves `name` against `$PATH` (colon-split), returns the first candidate path that passes `Unix.access _ [Unix.X_OK]`, or `None`.
- Produces: `Render_cli.dim : is_tty:bool -> string -> string` — wraps `text` in `\027[2m...\027[0m` when `is_tty` is `true`, returns `text` unchanged otherwise.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_render_cli.ml`:

```ocaml
open Render_cli

let test_which_found () =
  let dir = Filename.temp_file "render_cli_test" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let path = Filename.concat dir "myprog" in
  let oc = open_out path in
  output_string oc "#!/bin/sh\nexit 0\n";
  close_out oc;
  Unix.chmod path 0o755;
  let saved_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" dir;
  let result = which "myprog" in
  (match saved_path with Some p -> Unix.putenv "PATH" p | None -> ());
  Sys.remove path;
  Unix.rmdir dir;
  Alcotest.(check bool) "found on PATH" true (result <> None)

let test_which_missing () =
  let dir = Filename.temp_file "render_cli_test" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  let saved_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" dir;
  let result = which "nonexistent-binary-xyz" in
  (match saved_path with Some p -> Unix.putenv "PATH" p | None -> ());
  Unix.rmdir dir;
  Alcotest.(check bool) "not found" true (result = None)

let test_dim_tty () =
  Alcotest.(check string) "dimmed" "\027[2mhint\027[0m" (dim ~is_tty:true "hint")

let test_dim_no_tty () =
  Alcotest.(check string) "plain" "hint" (dim ~is_tty:false "hint")

let () =
  Alcotest.run "render_cli"
    [
      ( "which",
        [
          Alcotest.test_case "found on PATH" `Quick test_which_found;
          Alcotest.test_case "not found" `Quick test_which_missing;
        ] );
      ( "dim",
        [
          Alcotest.test_case "tty wraps in ANSI dim" `Quick test_dim_tty;
          Alcotest.test_case "non-tty passes through" `Quick test_dim_no_tty;
        ] );
    ]
```

Add to `tests/dune` (after the last existing `(test ...)` stanza):

```dune
(test
 (name test_render_cli)
 (libraries render_cli alcotest unix))
```

- [ ] **Step 2: Run test to verify it fails (module doesn't exist yet)**

Run: `dune build @tests/runtest 2>&1 | head -30`
Expected: build error, something like `Unbound module Render_cli` or `Library "render_cli" not found`.

- [ ] **Step 3: Create the library**

Create `bin/render_cli.ml`:

```ocaml
let which name =
  match Sys.getenv_opt "PATH" with
  | None -> None
  | Some path ->
      String.split_on_char ':' path
      |> List.find_map (fun dir ->
             if dir = "" then None
             else
               let candidate = Filename.concat dir name in
               match Unix.access candidate [ Unix.X_OK ] with
               | () -> Some candidate
               | exception Unix.Unix_error _ -> None)

let dim ~is_tty text = if is_tty then "\027[2m" ^ text ^ "\027[0m" else text
```

Replace `bin/dune` with:

```dune
(executable
 (name main)
 (public_name beloch)
 (libraries beloch render_cli unix)
 (modules main))

(library
 (name render_cli)
 (libraries unix)
 (modules render_cli))
```

(Explicit `(modules ...)` on both stanzas is required — dune errors if two stanzas in the same directory both claim `render_cli.ml`/`main.ml` implicitly.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `dune build @tests/runtest 2>&1 | tail -40`
Expected: `test_render_cli` passes all 4 cases (and every other existing test stanza still passes — this touches shared `tests/dune`).

- [ ] **Step 5: Commit**

```bash
git add bin/render_cli.ml bin/dune tests/test_render_cli.ml tests/dune
git commit -m "feat(cli): add render_cli.which/dim helpers"
```

---

### Task 2: Wire `.fold`/`.bel` dispatch + PATH hint into `bin/main.ml`

**Files:**
- Modify: `bin/main.ml` (entire file — see below for full replacement content)

**Interfaces:**
- Consumes: `Render_cli.which : string -> string option`, `Render_cli.dim : is_tty:bool -> string -> string` (Task 1).
- Consumes: `Beloch.fold_string : filename:string -> string -> Yojson.Safe.t` and `Error.Beloch_error : (Lexing.position * Lexing.position) * string -> exn`, `Diagnostic.render : source:string -> span:(Lexing.position * Lexing.position) -> msg:string -> string` — all already used by the existing `run_fold`, unchanged signatures.
- Produces: nothing new consumed elsewhere — `bin/main.ml` is the executable's entry point, not a library.

- [ ] **Step 1: Replace `bin/main.ml`**

```ocaml
(** Beloch CLI. v0.0 implements `fold`; other subcommands are still stubs. *)

open Beloch

let render_bin = "beloch-render"

let render_hint () =
  match Render_cli.which render_bin with
  | Some _ -> ""
  | None ->
      let is_tty = Unix.isatty Unix.stderr in
      "  " ^ Render_cli.dim ~is_tty "[unavailable: beloch-render not on PATH]"

let usage () =
  Printf.eprintf
    {|beloch — a declarative language for origami

usage:
  beloch fold   FILE.bel              evaluate and emit FOLD (stdout)
  beloch check  FILE.bel              parse and type-check only        (not yet implemented)
  beloch lsp                          run as an LSP server             (not yet implemented)
  beloch render FILE.fold|FILE.bel    render to a visual output (SVG/PNG)%s
  beloch --version
|}
    (render_hint ())

let todo name =
  Printf.eprintf "beloch %s: not yet implemented (v0.0)\n" name;
  exit 1

let render_unavailable_msg =
  Printf.sprintf
    "beloch render: `%s` not found on PATH — run `nix develop` (or `cd \
     render/render-svg && bun link`)\n"
    render_bin

(* .bel -> evaluate to FOLD JSON, no temp file: piped straight into
   beloch-render's stdin over a real Unix.pipe. *)
let eval_to_fold_json file =
  match In_channel.with_open_text file In_channel.input_all with
  | exception Sys_error msg ->
      Printf.eprintf "%s\n" msg;
      exit 1
  | src -> (
      try Yojson.Safe.to_string (Beloch.fold_string ~filename:file src)
      with Error.Beloch_error (span, msg) ->
        prerr_string (Diagnostic.render ~source:src ~span ~msg);
        exit 1)

let run_render_piped prog json_str rest =
  let read_fd, write_fd = Unix.pipe ~cloexec:false () in
  Unix.set_close_on_exec write_fd;
  let argv = Array.of_list (render_bin :: "-" :: rest) in
  let pid = Unix.create_process prog argv read_fd Unix.stdout Unix.stderr in
  Unix.close read_fd;
  let oc = Unix.out_channel_of_descr write_fd in
  output_string oc json_str;
  close_out oc;
  match Unix.waitpid [] pid with
  | _, Unix.WEXITED code -> exit code
  | _, (Unix.WSIGNALED _ | Unix.WSTOPPED _) -> exit 1

(* `beloch render` hands off to `beloch-render`, the @beloch/render-svg CLI
   (linked onto PATH by the Nix devShell) — see render/README.md. `.fold`
   inputs pass straight through; `.bel` inputs are evaluated here first and
   the resulting FOLD JSON is piped into beloch-render's stdin. *)
let run_render args =
  match Render_cli.which render_bin with
  | None ->
      prerr_string render_unavailable_msg;
      exit 1
  | Some resolved -> (
      match args with
      | file :: rest when Filename.check_suffix file ".bel" ->
          let json_str = eval_to_fold_json file in
          run_render_piped resolved json_str rest
      | _ -> Unix.execv resolved (Array.of_list (render_bin :: args)))

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

let () =
  match Array.to_list Sys.argv with
  | _ :: ("--version" | "-v") :: _ -> print_endline Beloch.version
  | _ :: "fold" :: file :: _ -> run_fold file
  | _ :: "check" :: _ -> todo "check"
  | _ :: "lsp" :: _ -> todo "lsp"
  | _ :: "render" :: rest -> run_render rest
  | _ ->
      usage ();
      exit 2
```

- [ ] **Step 2: Build**

Run: `dune build 2>&1 | tail -40`
Expected: clean build, no warnings/errors.

- [ ] **Step 3: Manual verify — `.fold` passthrough unchanged**

Run: `dune exec beloch -- render tests/golden/syntax/bisect-a.fold /tmp/bisect-a.svg && head -c 60 /tmp/bisect-a.svg`
Expected: exits 0, output starts with `<svg`.

- [ ] **Step 4: Manual verify — `.bel` input works end to end**

Run: `dune exec beloch -- render examples/fold-along.bel /tmp/fold-along.svg && head -c 60 /tmp/fold-along.svg`
Expected: exits 0, output starts with `<svg`.

- [ ] **Step 5: Manual verify — `.bel` evaluation error surfaces as a diagnostic, not a crash**

Run: `printf 'paper square\n--l = through .a .a\n' > /tmp/bad.bel && dune exec beloch -- render /tmp/bad.bel /tmp/bad.svg; echo "exit=$?"`
Expected: exit code 1, stderr shows the rustc-style diagnostic block (`error: ...`, `--> /tmp/bad.bel:2:...`, caret underline) — same shape as `beloch fold /tmp/bad.bel`'s error output. No `/tmp/bad.svg` written.

- [ ] **Step 6: Manual verify — `--help` hint when `beloch-render` is unavailable**

Run: `PATH=/usr/bin:/bin dune build 2>&1 | tail -5` (just confirming build itself doesn't need `beloch-render` on PATH), then:
Run: `env PATH=/usr/bin:/bin _build/default/bin/main.exe 2>&1 | grep render`
Expected: the render line ends with `[unavailable: beloch-render not on PATH]` (raw escape codes since stderr is piped through `grep`, not a tty — confirms the non-tty branch).

- [ ] **Step 7: Manual verify — `render` itself fails with the hint when unavailable**

Run: `env PATH=/usr/bin:/bin _build/default/bin/main.exe render tests/golden/syntax/bisect-a.fold /tmp/x.svg; echo "exit=$?"`
Expected: exit 1, stderr: `` beloch render: `beloch-render` not found on PATH — run `nix develop` (or `cd render/render-svg && bun link`) ``.

- [ ] **Step 8: Run full test suite to confirm no regressions**

Run: `dune build @tests/runtest 2>&1 | tail -60`
Expected: all test stanzas (including `test_render_cli` from Task 1) pass.

- [ ] **Step 9: Commit**

```bash
git add bin/main.ml
git commit -m "feat(cli): beloch render accepts .bel input directly"
```

---

## Self-Review Notes

- **Spec coverage:** dispatch flow (Task 2 Step 1), PATH-gated `--help` hint (Task 2 `render_hint`/`usage`), dimmed ANSI only on real TTY (Task 1 `dim` + Task 2 `Unix.isatty Unix.stderr`), no temp file (Task 2 `run_render_piped` uses `Unix.pipe`), `.bel` error handling reuses `run_fold`'s pattern (Task 2 `eval_to_fold_json`) — all covered.
- **Correction from spec draft:** the spec's Testing section said `Unix.isatty Unix.stdout`; the hint is printed via `usage()`/`render_unavailable_msg` which both go to **stderr**, so the plan uses `Unix.isatty Unix.stderr` throughout. Spec should be amended to match.
- **No placeholders**, no repeated "similar to Task N" — Task 2 Step 1 is the full file.
