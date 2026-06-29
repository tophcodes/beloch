(** sedlex tokenizer. Whitespace and `;`-to-end-of-line comments are skipped.
    `.name` -> POINT "name", `--name` -> CREASE "name". *)

open Parser

let id_char = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_']
let id = [%sedlex.regexp? Plus id_char]

let rec token (buf : Sedlexing.lexbuf) : token =
  match%sedlex buf with
  | Plus (Chars " \t\r\n") -> token buf
  | ';', Star (Compl '\n') -> token buf
  | "paper" -> PAPER
  | "square" -> SQUARE
  | "through" -> THROUGH
  | "fold" -> FOLD
  | "perp" -> PERP
  | "bisect" -> BISECT
  | "toward" -> TOWARD
  | "to" -> TO
  | "cross" -> CROSS
  | ':' -> COLON
  | "--", id ->
      let s = Sedlexing.Utf8.lexeme buf in
      CREASE (String.sub s 2 (String.length s - 2))
  | '.', id ->
      let s = Sedlexing.Utf8.lexeme buf in
      POINT (String.sub s 1 (String.length s - 1))
  | eof -> EOF
  | _ ->
      let start, finish = Sedlexing.lexing_positions buf in
      Error.fail (start, finish)
        (Printf.sprintf "unexpected character %S" (Sedlexing.Utf8.lexeme buf))
