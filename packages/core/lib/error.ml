(** Source spans and the single error type used across the evaluator. *)

type span = Lexing.position * Lexing.position

(** A rejected program: where, what is wrong, and optionally one thing the
    author can write instead (ADR 0028). The message never carries the
    suggestion itself. *)
exception Beloch_error of span * string * string option

let fail ?hint (span : span) (msg : string) : 'a =
  raise (Beloch_error (span, msg, hint))

let span_to_string ((start, stop) : span) : string =
  let open Lexing in
  let sl = start.pos_lnum and sc = start.pos_cnum - start.pos_bol + 1 in
  let el = stop.pos_lnum and ec = stop.pos_cnum - stop.pos_bol + 1 in
  if sl = el then Printf.sprintf "%s:%d:%d-%d" start.pos_fname sl sc ec
  else Printf.sprintf "%s:%d:%d-%d:%d" start.pos_fname sl sc el ec
