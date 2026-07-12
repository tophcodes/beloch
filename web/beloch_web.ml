(** js_of_ocaml spike entry point — reads a .bel program from stdin, runs it
    through the real evaluator ([Beloch.fold_string]), and prints the folded
    FOLD-extended JSON to stdout. Pure-rational programs round-trip; any
    program that touches an irrational (qqbar) value raises via the shim in
    [qqbar_shim.js] (see decisions/0013-flint-qqbar-backend.md). *)

let () =
  let src = In_channel.input_all stdin in
  let json = Beloch.fold_string ~filename:"stdin" src in
  print_string (Yojson.Safe.to_string json)
