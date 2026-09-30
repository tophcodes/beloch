(* [prose_mask] OUTDIR FILE…

   Writes OUTDIR/FILE.txt for every OCaml source FILE: a copy in which only
   the prose of its comments is left. Every other character becomes a space
   and every newline stays, so a word of a comment keeps the line and column it
   has in FILE. scripts/prose.sh runs Vale over these copies, since Vale has no
   parser for OCaml.

   The compiler's own lexer finds the comments, so nested comments and a "*)"
   inside a string literal end where the compiler says they end.

   Inside a comment the mask also covers the delimiters and the odoc markup
   that holds code or references in place of prose:
   - the delimiters "(*", "(**" and "*)", nested ones included;
   - "[...]" inline code, with nested brackets;
   - "{[...]}" and "{@lang[...]}" code blocks, "{v ...v}" verbatim text;
   - "{m ...}" and "{math ...}" math, with nested braces;
   - "{!ref}" references, and the target of "{{!ref} text}" and
     "{{:url} text}", whose text stays;
   - the marker and the closing brace of any "{tag text}", e.g. "{b …}",
     "{i …}", "{e …}", "{1 …}", "{ul …}", "{- …}"; the text stays.

   Known limitations: "@param", "@raise" and "@see <url>" tags stay as they
   are, and a "\\" escape only protects the character after it. An unclosed
   code span masks the rest of its comment.

   Columns count characters: a masked multi-byte UTF-8 character becomes one
   space. *)

let read_file path = In_channel.with_open_bin path In_channel.input_all

(* The byte spans [start, stop) of every comment in [src], delimiters
   included. Fails on a lexer error, e.g. an unterminated string. *)
let comment_spans ~path src =
  ignore (Warnings.parse_options false "-a");
  Lexer.init ();
  let lexbuf = Lexing.from_string src in
  Location.init lexbuf path;
  let rec drain () =
    match Lexer.token lexbuf with Parser.EOF -> () | _ -> drain ()
  in
  drain ();
  List.map
    (fun (_, (loc : Location.t)) ->
      (loc.loc_start.pos_cnum, loc.loc_end.pos_cnum))
    (Lexer.comments ())

let starts_with src i prefix =
  let n = String.length prefix in
  i + n <= String.length src && String.sub src i n = prefix

(* The index just past the first [closer] at or after [i], or [stop]. *)
let find src i stop closer =
  let rec go j =
    if j >= stop then stop
    else if starts_with src j closer then j + String.length closer
    else go (j + 1)
  in
  go i

(* The index just past the [close] that balances the [open_] before [i]. *)
let balanced src i stop open_ close =
  let rec go j depth =
    if j >= stop then stop
    else if src.[j] = '\\' then go (j + 2) depth
    else if src.[j] = open_ then go (j + 1) (depth + 1)
    else if src.[j] = close then
      if depth = 0 then j + 1 else go (j + 1) (depth - 1)
    else go (j + 1) depth
  in
  go i 0

let is_tag_char c =
  match c with 'a' .. 'z' | '0' .. '9' | '-' -> true | _ -> false

let is_space c = c = ' ' || c = '\t' || c = '\n' || c = '\r'

(* Marks the bytes of the comment [start, stop) that are prose. *)
let keep_prose src keep (start, stop) =
  let mask a b = Array.fill keep a (b - a) false in
  for j = start to stop - 1 do
    keep.(j) <- true
  done;
  (* A brace opened by a "{tag" marker closes with a masked "}"; any other
     brace keeps its "}". *)
  let braces = Stack.create () in
  let rec go i =
    if i < stop then
      if starts_with src i "(*" then begin
        mask i (i + 2);
        go (i + 2)
      end
      else if starts_with src i "*)" then begin
        mask i (i + 2);
        go (i + 2)
      end
      else
        match src.[i] with
        | '\\' -> go (i + 2)
        | '[' ->
            let j = balanced src (i + 1) stop '[' ']' in
            mask i j;
            go j
        | '{' -> brace i
        | '}' ->
            (match Stack.pop_opt braces with
            | Some true -> mask i (i + 1)
            | _ -> ());
            go (i + 1)
        | _ -> go (i + 1)
  and brace i =
    let skip j =
      mask i j;
      go j
    in
    if starts_with src i "{[" || starts_with src i "{@" then
      skip (find src i stop "]}")
    else if starts_with src i "{v" && i + 2 < stop && is_space src.[i + 2]
    then skip (find src i stop "v}")
    else if starts_with src i "{m " || starts_with src i "{math " then
      skip (balanced src (i + 1) stop '{' '}')
    else if starts_with src i "{!" then skip (find src i stop "}")
    else if starts_with src i "{{!" || starts_with src i "{{:" then begin
      Stack.push true braces;
      skip (find src (i + 1) stop "}")
    end
    else
      let j = ref (i + 1) in
      while !j < stop && is_tag_char src.[!j] do
        incr j
      done;
      if !j > i + 1 && !j < stop && is_space src.[!j] then begin
        Stack.push true braces;
        skip !j
      end
      else begin
        Stack.push false braces;
        go (i + 1)
      end
  in
  (* "(**" opens a doc comment; its second star is a delimiter too. *)
  let body = if starts_with src start "(**" then start + 3 else start in
  mask start body;
  go body

(* [src] with every byte outside [keep] blanked. A newline stays; a masked
   UTF-8 continuation byte is dropped, so a masked character is one space. *)
let render src keep =
  let out = Buffer.create (String.length src) in
  String.iteri
    (fun i c ->
      if keep.(i) || c = '\n' then Buffer.add_char out c
      else if Char.code c land 0xC0 <> 0x80 then Buffer.add_char out ' ')
    src;
  Buffer.contents out

let mask_file outdir path =
  let src = read_file path in
  let keep = Array.make (String.length src) false in
  List.iter (keep_prose src keep) (comment_spans ~path src);
  let target = Filename.concat outdir (path ^ ".txt") in
  let rec mkdir_p dir =
    if not (Sys.file_exists dir) then begin
      mkdir_p (Filename.dirname dir);
      Sys.mkdir dir 0o755
    end
  in
  mkdir_p (Filename.dirname target);
  Out_channel.with_open_bin target (fun oc ->
      Out_channel.output_string oc (render src keep))

let () =
  match Array.to_list Sys.argv with
  | _ :: outdir :: files -> (
      try List.iter (mask_file outdir) files
      with Lexer.Error _ as e ->
        Location.report_exception Format.err_formatter e;
        exit 1)
  | _ ->
      prerr_endline "usage: prose_mask OUTDIR FILE...";
      exit 2
