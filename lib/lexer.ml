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
  | "and" -> AND
  | "at" -> AT_KW
  | "map" -> MAP
  | "onto" -> ONTO
  | "perp" -> PERP
  | "toward" -> TOWARD
  | "moving" -> MOVING
  | "mountain" -> MOUNTAIN
  | "up" -> UP
  | "to" -> TO
  | "fold" -> FOLD_KW
  | "cross" -> CROSS
  | "flip" -> FLIP
  | "def" -> DEF
  | "apply" -> APPLY
  | "export" -> EXPORT
  | "step" -> STEP
  | "collapse" -> COLLAPSE
  | "over" -> OVER
  | "standing" -> STANDING
  | "as" -> AS
  | '=' -> EQ
  | '@' -> AT
  | '!' -> BANG
  | '{' -> LBRACE
  | '}' -> RBRACE
  | '(' -> LPAREN
  | ']' -> RBRACKET
  | "--(" -> LINE_OPEN
  | ".(" -> POINT_OPEN
  | "#(" -> FLAP_OPEN
  | "--[" -> LINE_MEMBER_OPEN
  | ".[" -> POINT_MEMBER_OPEN
  | ')' -> RPAREN
  | '$', id ->
      let s = Sedlexing.Utf8.lexeme buf in
      INSTANCE (String.sub s 1 (String.length s - 1))
  | "--", id ->
      let s = Sedlexing.Utf8.lexeme buf in
      CREASE (String.sub s 2 (String.length s - 2))
  | '.', id ->
      let s = Sedlexing.Utf8.lexeme buf in
      POINT (String.sub s 1 (String.length s - 1))
  | id -> IDENT (Sedlexing.Utf8.lexeme buf)
  | eof -> EOF
  | _ ->
      let start, finish = Sedlexing.lexing_positions buf in
      Error.fail (start, finish)
        (Printf.sprintf "unexpected character %S" (Sedlexing.Utf8.lexeme buf))
