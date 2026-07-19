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
  beloch render FILE.fold|FILE.bel    render to a visual output (SVG/PNG) — see `beloch render --help`%s
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

(* Shared by `run_fold` and `.bel` render dispatch: read + evaluate a .bel
   file, rendering evaluator errors as source-context diagnostics. *)
let eval_bel_file file =
  match In_channel.with_open_text file In_channel.input_all with
  | exception Sys_error msg ->
      Printf.eprintf "%s\n" msg;
      exit 1
  | src -> (
      try Beloch.fold_string ~filename:file src
      with Error.Beloch_error (span, msg) ->
        prerr_string (Diagnostic.render ~source:src ~span ~msg);
        exit 1)

(* .bel -> FOLD JSON string, no temp file: piped straight into
   beloch-render's stdin over a real Unix.pipe. *)
let eval_to_fold_json file = Yojson.Safe.to_string (eval_bel_file file)

let run_render_piped prog json_str rest =
  let read_fd, write_fd = Unix.pipe ~cloexec:false () in
  Unix.set_close_on_exec write_fd;
  let argv = Array.of_list (render_bin :: "-" :: rest) in
  let pid = Unix.create_process prog argv read_fd Unix.stdout Unix.stderr in
  Unix.close read_fd;
  let oc = Unix.out_channel_of_descr write_fd in
  (* Accepted risk for v0.0: this write happens before `waitpid`, so a
     FOLD payload bigger than the pipe buffer (~64KiB on Linux) blocks
     here if beloch-render hasn't started reading yet, and a child that
     exits without draining stdin delivers SIGPIPE (uncaught -> process
     death, no diagnostic). Real .bel inputs today are far under that
     size. Forward fix if it ever bites: ignore SIGPIPE and catch EPIPE
     around this write, or move it to a background writer thread. *)
  output_string oc json_str;
  close_out oc;
  match Unix.waitpid [] pid with
  | _, Unix.WEXITED code -> code
  | _, (Unix.WSIGNALED _ | Unix.WSTOPPED _) -> 1

(* `--format` value from already-parsed rest args, defaulting to svg -
   used to pick the temp file extension for `--open`. *)
let format_ext rest =
  let rec find = function
    | "--format" :: v :: _ -> v
    | _ :: tl -> find tl
    | [] -> "svg"
  in
  if find rest = "png" then ".png" else ".svg"

let xdg_open path =
  match Render_cli.which "xdg-open" with
  | None ->
      Printf.eprintf "beloch render: xdg-open not found on PATH (file saved: %s)\n" path;
      exit 1
  | Some xdg -> ignore (Unix.create_process xdg [| "xdg-open"; path |] Unix.stdin Unix.stdout Unix.stderr)

(* `beloch render` hands off to `beloch-render`, the @beloch/render-svg CLI
   (linked onto PATH by the Nix devShell) — see render/README.md. `.fold`
   inputs pass straight through; `.bel` inputs are evaluated here first and
   the resulting FOLD JSON is piped into beloch-render's stdin. *)
let run_render args =
  if Render_cli.wants_help args then begin
    print_string Render_cli.render_help;
    exit 0
  end;
  match Render_cli.which render_bin with
  | None ->
      prerr_string render_unavailable_msg;
      exit 1
  | Some resolved -> (
      let open_flag = List.mem "--open" args in
      let args = List.filter (fun a -> a <> "--open") args in
      match args with
      | file :: rest when Filename.check_suffix file ".bel" ->
          let json_str = eval_to_fold_json file in
          if open_flag then begin
            let out_path = Filename.temp_file "beloch-render" (format_ext rest) in
            let code = run_render_piped resolved json_str (out_path :: rest) in
            if code <> 0 then exit code;
            xdg_open out_path
          end
          else exit (run_render_piped resolved json_str rest)
      | file :: rest when open_flag ->
          let out_path = Filename.temp_file "beloch-render" (format_ext rest) in
          let argv = Array.of_list (render_bin :: file :: out_path :: rest) in
          let pid = Unix.create_process resolved argv Unix.stdin Unix.stdout Unix.stderr in
          (match Unix.waitpid [] pid with
          | _, Unix.WEXITED 0 -> xdg_open out_path
          | _, Unix.WEXITED code -> exit code
          | _, (Unix.WSIGNALED _ | Unix.WSTOPPED _) -> exit 1)
      | _ -> Unix.execv resolved (Array.of_list (render_bin :: args)))

let run_fold file =
  print_endline (Yojson.Safe.pretty_to_string (eval_bel_file file))

(* `beloch fold --watch FILE`: keeps one incremental `Session.t` across
   re-folds and recomputes only the suffix invalidated by the edit (see
   lib/session.ml). Polls mtime rather than inotify — no new dependency
   beyond `unix`, and .bel edits are human-paced so a 200ms poll is
   imperceptible. *)
let run_fold_watch file =
  let session = Session.create () in
  let last_mtime = ref 0.0 in
  let fold_once () =
    match In_channel.with_open_text file In_channel.input_all with
    | exception Sys_error msg -> Printf.eprintf "%s\n%!" msg
    | src -> (
        try
          let folded = Session.eval session ~filename:file src in
          print_string (Yojson.Safe.pretty_to_string (Fold_emit.to_json_folded folded));
          print_newline ();
          let n = Session.last_ran session in
          Printf.eprintf "[watch] refolded %s (%d statement%s recomputed)\n%!" file n
            (if n = 1 then "" else "s")
        with Error.Beloch_error (span, msg) ->
          prerr_string (Diagnostic.render ~source:src ~span ~msg))
  in
  while true do
    (match (Unix.stat file).Unix.st_mtime with
    | m when m > !last_mtime ->
        last_mtime := m;
        fold_once ()
    | _ -> ());
    Unix.sleepf 0.2
  done

let () =
  match Array.to_list Sys.argv with
  | _ :: ("--version" | "-v") :: _ -> print_endline Beloch.version
  | _ :: "fold" :: "--watch" :: file :: _ -> run_fold_watch file
  | _ :: "fold" :: file :: _ -> run_fold file
  | _ :: "check" :: _ -> todo "check"
  | _ :: "lsp" :: _ -> todo "lsp"
  | _ :: "render" :: rest -> run_render rest
  | _ ->
      usage ();
      exit 2
