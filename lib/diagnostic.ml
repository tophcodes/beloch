(** Render a Beloch_error as a rustc-style source-context block. Pure: source
    text + span + message -> string. Uses whatever span the error carries. *)

let render ~(source : string) ~(span : Error.span) ~(msg : string) : string =
  let start, finish = span in
  let lines = String.split_on_char '\n' source in
  let line_at n =
    match List.nth_opt lines (n - 1) with Some l -> l | None -> ""
  in
  let line_no = start.Lexing.pos_lnum in
  let start_col = max 0 (start.Lexing.pos_cnum - start.Lexing.pos_bol) in
  let end_col =
    if finish.Lexing.pos_lnum = line_no then
      finish.Lexing.pos_cnum - finish.Lexing.pos_bol
    else String.length (line_at line_no) (* multi-line: to end of start line *)
  in
  let caret_w = max 1 (end_col - start_col) in
  let file = start.Lexing.pos_fname in
  let first = max 1 (line_no - 3) in
  let gutter_w = String.length (string_of_int line_no) in
  let blank = String.make gutter_w ' ' in
  let pad n =
    let s = string_of_int n in
    String.make (gutter_w - String.length s) ' ' ^ s
  in
  let buf = Buffer.create 256 in
  Buffer.add_string buf (Printf.sprintf "error: %s\n" msg);
  Buffer.add_string buf
    (Printf.sprintf "%s--> %s:%d:%d\n" blank file line_no (start_col + 1));
  Buffer.add_string buf (Printf.sprintf "%s |\n" blank);
  for n = first to line_no do
    Buffer.add_string buf (Printf.sprintf "%s | %s\n" (pad n) (line_at n))
  done;
  let caret = String.make start_col ' ' ^ String.make caret_w '^' in
  Buffer.add_string buf (Printf.sprintf "%s | %s %s\n" blank caret msg);
  Buffer.contents buf
