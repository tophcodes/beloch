(** Beloch — evaluator core.

    The library is intentionally empty until the minimal core (v0.0) is
    specified in [spec/10-core-v0.md]: one square of paper, axiom 1 only, a
    crease-line type, output to FOLD-extended. See
    [decisions/0003-restart-from-minimal-core.md] and
    [decisions/0007-evaluator-not-compiler.md]. *)

let version = "0.3.0-dev"

let parse ~(filename : string) (src : string) : Ast.program =
  let lexbuf = Sedlexing.Utf8.from_string src in
  Sedlexing.set_filename lexbuf filename;
  let supplier = Sedlexing.with_tokenizer Lexer.token lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised Parser.program
  in
  try parser supplier
  with Parser.Error ->
    let start, finish = Sedlexing.lexing_positions lexbuf in
    Error.fail (start, finish) "syntax error"

let fold_string ~(filename : string) (src : string) : Yojson.Safe.t =
  parse ~filename src |> Eval.eval_folded |> Fold_emit.to_json_folded

module Num = Num
module Error = Error
module Geom = Geom
module Isometry = Isometry
module Ast = Ast
module Lexer = Lexer
module Parser = Parser
module State = State
module Eval = Eval
module Fold_emit = Fold_emit
module Fold_state = Fold_state
module Poly = Poly
module Mpoly = Mpoly
