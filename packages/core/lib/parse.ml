(** Source-to-AST parsing, shared by [Beloch] and [Session].

    Lives as its own leaf module (depends only on [Lexer]/[Parser]/
    [Sedlexing]/[Error]) so that [Session] can call it without creating a
    cycle through the top-level [Beloch] module, which re-exports every
    other module in the library. *)

let parse ~(filename : string) (src : string) : Ast.program =
  Lexer.reset ();
  let lexbuf = Sedlexing.Utf8.from_string src in
  Sedlexing.set_filename lexbuf filename;
  let supplier = Sedlexing.with_tokenizer Lexer.token lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised Parser.program
  in
  let prog =
    try parser supplier
    with Parser.Error ->
      let start, finish = Sedlexing.lexing_positions lexbuf in
      Error.fail (start, finish) "syntax error"
  in
  Annotation.check prog;
  prog

(** A library file, which holds shapes and no `paper` line, such as the
    standard library: the unit it declares, and the shapes a program sees as
    defined before its own first line. *)
let library ~(filename : string) (src : string) :
    (string * Error.span) option * Ast.shape_def list =
  Lexer.reset ();
  let lexbuf = Sedlexing.Utf8.from_string src in
  Sedlexing.set_filename lexbuf filename;
  let supplier = Sedlexing.with_tokenizer Lexer.token lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised Parser.library
  in
  try parser supplier
  with Parser.Error ->
    let start, finish = Sedlexing.lexing_positions lexbuf in
    Error.fail (start, finish) "syntax error"
