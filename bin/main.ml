(** Beloch CLI. v0.0 implements `fold`; other subcommands are still stubs. *)

open Beloch

let usage () =
  prerr_string
    {|beloch — a declarative language for origami

usage:
  beloch fold   FILE.bel       evaluate and emit FOLD (stdout)
  beloch check  FILE.bel       parse and type-check only        (not yet implemented)
  beloch lsp                   run as an LSP server             (not yet implemented)
  beloch render FILE.fold      render to a visual output        (not yet implemented)
  beloch --version
|}

let todo name =
  Printf.eprintf "beloch %s: not yet implemented (v0.0)\n" name;
  exit 1

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
  | _ :: "render" :: _ -> todo "render"
  | _ ->
      usage ();
      exit 2
