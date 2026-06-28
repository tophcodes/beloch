(** Beloch CLI.

    Subcommand shape per [decisions/0007-evaluator-not-compiler.md]:
      beloch fold   FILE.bel        evaluate, emit FOLD-extended (primary op)
      beloch check  FILE.bel        front-end only, no geometric evaluation
      beloch lsp                    run as an LSP server
      beloch render FILE.fold       render to a visual output

    All but version are stubs until the minimal core (v0.0) lands. *)

let usage () =
  prerr_string
    {|beloch — a declarative language for origami

usage:
  beloch fold   FILE.bel       evaluate and emit FOLD-extended  (not yet implemented)
  beloch check  FILE.bel       parse and type-check only        (not yet implemented)
  beloch lsp                   run as an LSP server             (not yet implemented)
  beloch render FILE.fold      render to a visual output        (not yet implemented)
  beloch --version
|}

let todo name =
  Printf.eprintf "beloch %s: not yet implemented (minimal core v0.0 pending)\n" name;
  exit 1

let () =
  match Array.to_list Sys.argv with
  | _ :: ("--version" | "-v") :: _ -> print_endline Beloch.version
  | _ :: "fold" :: _ -> todo "fold"
  | _ :: "check" :: _ -> todo "check"
  | _ :: "lsp" :: _ -> todo "lsp"
  | _ :: "render" :: _ -> todo "render"
  | _ ->
    usage ();
    exit 2
