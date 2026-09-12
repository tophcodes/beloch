(** sedlex tokenizer. Whitespace and `;`-to-end-of-line comments are skipped.
    `.name` -> POINT "name", `--name` -> CREASE "name". *)

open Parser

let id_char = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_']
let id = [%sedlex.regexp? Plus id_char]
let number = [%sedlex.regexp? Plus '0' .. '9', Opt ('/', Plus '0' .. '9')]

let rec token (buf : Sedlexing.lexbuf) : token =
  match%sedlex buf with
  | Plus (Chars " \t\r\n") -> token buf
  | ';', Star (Compl '\n') -> token buf
  | "paper" -> PAPER
  | "square" -> SQUARE
  | "through" -> THROUGH
  | "and" -> AND
  | "map" -> MAP
  | "onto" -> ONTO
  | "perp" -> PERP
  | "toward" -> TOWARD
  | "moving" -> MOVING
  | "mountain" -> MOUNTAIN
  | "valley" -> VALLEY
  | "up" -> UP
  | "to" -> TO
  | "fold" -> FOLD_KW
  | "flip" -> FLIP
  | "reverse" -> REVERSE
  | "outside" -> OUTSIDE
  | "def" -> DEF
  | "apply" -> APPLY
  | "export" -> EXPORT
  | "flatten" -> FLATTEN
  | "over" -> OVER
  | "under" -> UNDER
  | "staying" -> STAYING
  | "mark" -> MARK
  | "between" -> BETWEEN
  | "at" -> AT
  | "as" -> AS
  | "free" -> FREE
  | "on" -> ON
  | "from" -> FROM
  | number -> NUMBER (Q.of_string (Sedlexing.Utf8.lexeme buf))
  | '=' -> EQ
  | '!' -> BANG
  | '{' -> LBRACE
  | '}' -> RBRACE
  | '(' -> LPAREN
  | ']' -> RBRACKET
  | '[' -> LBRACKET
  | '&' -> AMP
  | '\\' -> BACKSLASH
  | '*' -> STAR
  | "#[" -> FLAP_BRACKET
  | "--[" -> LINE_MEMBER_OPEN   (* now the --[c+] line-select opener *)
  | ".[" -> POINT_MEMBER_OPEN   (* now the .[l+] point-select opener *)
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
