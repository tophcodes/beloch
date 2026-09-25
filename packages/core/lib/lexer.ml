(** sedlex tokenizer. Whitespace and `;`-to-end-of-line comments are skipped.
    `.name` -> POINT "name", `--name` -> CREASE "name".

    An annotation is the one place the end of a line matters: `@key` opens
    it, and the next line break (or the end of the file) closes it with
    NEWLINE. Text in double quotes exists only there. *)

open Parser

(* true between an annotation's `@key` and the end of its line *)
let in_annotation = ref false

let reset () = in_annotation := false

(* the body of a quoted text; a backslash escapes a quote or a backslash *)
let text_of_lexeme (s : string) : string =
  let inner = String.sub s 1 (String.length s - 2) in
  let b = Buffer.create (String.length inner) in
  let i = ref 0 in
  while !i < String.length inner do
    (if inner.[!i] = '\\' && !i + 1 < String.length inner then (
       Buffer.add_char b inner.[!i + 1];
       incr i)
     else Buffer.add_char b inner.[!i]);
    incr i
  done;
  Buffer.contents b

let id_char = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_']
let id = [%sedlex.regexp? Plus id_char]
let number = [%sedlex.regexp? Plus '0' .. '9', Opt ('/', Plus '0' .. '9')]

let rec token (buf : Sedlexing.lexbuf) : token =
  if !in_annotation then annotation_token buf else program_token buf

and annotation_token (buf : Sedlexing.lexbuf) : token =
  match%sedlex buf with
  | Plus (Chars " \t\r") -> annotation_token buf
  | ';', Star (Compl '\n') -> annotation_token buf
  | '\n' | eof ->
      in_annotation := false;
      NEWLINE
  | '"', Star (Compl ('"' | '\\' | '\n') | ('\\', ('"' | '\\'))), '"' ->
      TEXT (text_of_lexeme (Sedlexing.Utf8.lexeme buf))
  | '"' ->
      let start, finish = Sedlexing.lexing_positions buf in
      Error.fail (start, finish)
        "a text runs to its closing quote on the same line; \\\" and \\\\ are its only escapes"
  | _ ->
      Sedlexing.rollback buf;
      program_token buf

and program_token (buf : Sedlexing.lexbuf) : token =
  match%sedlex buf with
  | Plus (Chars " \t\r\n") -> token buf
  | ';', Star (Compl '\n') -> token buf
  | '@', id, Opt (':', id) ->
      let s = Sedlexing.Utf8.lexeme buf in
      let s = String.sub s 1 (String.length s - 1) in
      in_annotation := true;
      (match String.index_opt s ':' with
      | Some i ->
          ANNOT (Some (String.sub s 0 i), String.sub s (i + 1) (String.length s - i - 1))
      | None -> ANNOT (None, s))
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
  | "align" -> ALIGN
  | "into" -> INTO
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
