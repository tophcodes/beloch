(** Incremental evaluation session. Memoizes one [Eval.snapshot] per statement
    along [Spine]'s prefix-stable hash chain: on re-eval, the longest matching
    key prefix is reused and only the divergent suffix is recomputed.

    In-memory only (Phase 1). See
    docs/superpowers/specs/2026-07-19-incremental-eval-cache-design.md. *)

type t = {
  mutable keys : string array;        (* one hash-chain key per statement *)
  mutable snaps : Eval.snapshot array; (* snapshot taken AFTER each statement *)
  mutable last_ran : int;             (* statements recomputed on the last eval *)
}

let create () = { keys = [||]; snaps = [||]; last_ran = 0 }
let last_ran t = t.last_ran

(* Mirrors [Beloch.parse]; duplicated here because the top-level [Beloch]
   module wraps every other module in the library (including this one), so
   [Session] cannot depend on [Beloch] without a cycle. *)
let parse ~(filename : string) (src : string) : Ast.program =
  let lexbuf = Sedlexing.Utf8.from_string src in
  Sedlexing.set_filename lexbuf filename;
  let supplier = Sedlexing.with_tokenizer Lexer.token lexbuf in
  let parser =
    MenhirLib.Convert.Simplified.traditional2revised Parser.program
  in
  try parser supplier
  with Parser.Error ->
    let start, finish = Sedlexing.lexing_positions lexbuf in
    Error.fail (start, finish) "syntax error"

let eval (t : t) ~(filename : string) (src : string) : Eval.folded =
  let prog = parse ~filename src in
  let new_keys = Array.of_list (Spine.chain_keys src prog) in
  (* longest common prefix of the old and new key chains *)
  let n = Array.length new_keys in
  let prefix = ref 0 in
  while
    !prefix < n
    && !prefix < Array.length t.keys
    && String.equal new_keys.(!prefix) t.keys.(!prefix)
  do
    incr prefix
  done;
  let prefix = !prefix in
  let resume = if prefix = 0 then None else Some t.snaps.(prefix - 1) in
  let suffix = List.filteri (fun i _ -> i >= prefix) prog in
  (* collect one snapshot per suffix statement, in order *)
  let collected = ref [] in
  let on_step ctx = collected := Eval.snapshot ctx :: !collected in
  let folded = Eval.eval_program ?resume ~on_step suffix in
  let suffix_snaps = Array.of_list (List.rev !collected) in
  t.keys <- new_keys;
  t.snaps <- Array.append (Array.sub t.snaps 0 prefix) suffix_snaps;
  t.last_ran <- n - prefix;
  folded
