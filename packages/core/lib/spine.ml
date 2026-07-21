(** Per-statement hash chain for the incremental evaluation cache.

    The chain has exactly one entry per [Ast.stmt] (the `paper square`
    header, which the parser consumes without producing a statement, is
    folded into the chain seed instead of getting its own key). Each entry
    folds in every entry before it, so the key at index [i] is a hash of
    everything up to and including [i]. Appending a statement leaves all
    earlier keys unchanged (full prefix reuse); editing statement [k]
    changes [k] and every key after it. See [Session]. *)

(* All [Ast.stmt] variants carry their [Error.span] as the last field. *)
let span_of_stmt : Ast.stmt -> Error.span = function
  | Ast.BindLine (_, _, sp)
  | Ast.Mark (_, _, _, _, _, sp)
  | Ast.Fold (_, _, _, sp)
  | Ast.BindBundle (_, _, sp)
  | Ast.Point (_, _, sp)
  | Ast.Flip sp
  | Ast.Def (_, _, _, sp)
  | Ast.Apply (_, _, _, sp)
  | Ast.Export (_, _, sp)
  | Ast.Flatten (_, _, _, _, _, sp) -> sp

(* collapse every run of whitespace to a single space and trim — so
   reindentation / line breaks inside a statement do not change the key. *)
let normalize_ws (s : string) : string =
  let b = Buffer.create (String.length s) in
  let in_ws = ref true in
  String.iter
    (fun c ->
      if c = ' ' || c = '\t' || c = '\n' || c = '\r' then begin
        if not !in_ws then (Buffer.add_char b ' '; in_ws := true)
      end
      else (Buffer.add_char b c; in_ws := false))
    s;
  let r = Buffer.contents b in
  let n = String.length r in
  if n > 0 && r.[n - 1] = ' ' then String.sub r 0 (n - 1) else r

let canon_stmt (src : string) (stmt : Ast.stmt) : string =
  let start, stop = span_of_stmt stmt in
  let a = start.Lexing.pos_cnum in
  let b = stop.Lexing.pos_cnum in
  (* pos_cnum are byte offsets into [src]; clamp defensively *)
  let a = if a < 0 then 0 else a in
  let b = if b > String.length src then String.length src else b in
  let slice = if b > a then String.sub src a (b - a) else "" in
  normalize_ws slice

(* `paper square` is the program header, not a statement, so it never appears
   in [prog]. Seed the chain with the normalized source PREFIX before the first
   statement: editing it changes the seed and invalidates every key, while the
   returned list stays exactly one key per Ast.stmt (keys align 1:1 with
   statements and with Session's per-statement snapshots). *)
let chain_keys (src : string) (prog : Ast.program) : string list =
  let first_start =
    match prog with
    | [] -> String.length src
    | stmt :: _ -> (fst (span_of_stmt stmt)).Lexing.pos_cnum
  in
  let first_start =
    if first_start < 0 then 0
    else if first_start > String.length src then String.length src
    else first_start
  in
  let prelude = normalize_ws (String.sub src 0 first_start) in
  let seed = Digest.to_hex (Digest.string ("prelude\x00" ^ prelude)) in
  let rec go prev acc = function
    | [] -> List.rev acc
    | stmt :: rest ->
        let key =
          Digest.to_hex (Digest.string (prev ^ "\x00" ^ canon_stmt src stmt))
        in
        go key (key :: acc) rest
  in
  go seed [] prog
