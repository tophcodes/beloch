(** Source spans and the single error type used across the evaluator. *)

type span = Lexing.position * Lexing.position

exception Beloch_error of span * string

let fail (span : span) (msg : string) : 'a = raise (Beloch_error (span, msg))

let span_to_string ((start, _) : span) : string =
  Printf.sprintf "%s:%d:%d" start.Lexing.pos_fname start.Lexing.pos_lnum
    (start.Lexing.pos_cnum - start.Lexing.pos_bol + 1)
