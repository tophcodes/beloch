(** Beloch — evaluator core.

    The library is intentionally empty until the minimal core (v0.0) is
    specified in [spec/10-core-v0.md]: one square of paper, axiom 1 only, a
    crease-line type, output to FOLD-extended. See
    [decisions/0003-restart-from-minimal-core.md] and
    [decisions/0007-evaluator-not-compiler.md]. *)

let version = Version.version

let parse ~(filename : string) (src : string) : Ast.program =
  Parse.parse ~filename src

let fold_string ~(filename : string) (src : string) : Yojson.Safe.t =
  parse ~filename src |> Eval.eval_folded |> Fold_emit.to_json_folded

(** The FOLD with its trace (spec/FOLD.md, "The trace"), and the
    program's failure. A program that fails still yields the file up to the
    failing statement, with the failure in `beloch:error`. A parse error
    raises as in [fold_string]. *)
type failure = {
  f_span : Error.span;
  f_message : string;
  f_hint : string option;
  f_statement : int;  (** the log entry of the statement that failed *)
}

(* Evaluate [prog] and keep what was evaluated when a statement fails: the
   result up to the state the failing statement read, with its log entry
   and its trace entries. *)
let eval_traced (prog : Ast.program) : Eval.folded * failure option =
  Fold_state.reset_ids ();
  let ctx = Ctx.create () in
  let root_scope = List.hd ctx.Ctx.scopes in
  let failure =
    try Eval.run_program ctx ignore prog; None
    with Error.Beloch_error (f_span, f_message, f_hint) ->
      Some { f_span; f_message; f_hint;
             f_statement = List.length ctx.Ctx.statements_rev - 1 }
  in
  (Eval.build_output ctx root_scope, failure)

let fold_traced ~(filename : string) (src : string) :
    Yojson.Safe.t * failure option =
  let fd, failure = parse ~filename src |> eval_traced in
  match (Fold_emit.to_json_folded ~trace:true fd, failure) with
  | json, None -> (json, None)
  | `Assoc kv, Some f ->
      let error =
        `Assoc
          [
            ("message", `String f.f_message);
            ("hint", match f.f_hint with Some h -> `String h | None -> `Null);
            ("span", `String (Error.span_to_string f.f_span));
            ("statement", `Int f.f_statement);
          ]
      in
      (`Assoc (kv @ [ ("beloch:error", error) ]), Some f)
  | json, Some f -> (json, Some f)

module Num = Num
module Error = Error
module Geom = Geom
module Isometry = Isometry
module Isometry3 = Isometry3
module Fold_state = Fold_state
module Ast = Ast
module Lexer = Lexer
module Parser = Parser
module Parse = Parse
module State = State
module Eval = Eval
module Fold_emit = Fold_emit
module Collapse = Collapse
module Flatten = Flatten
module Poly = Poly
module Mpoly = Mpoly
module Qqbar = Qqbar
module Diagnostic = Diagnostic
module Field_merge = Field_merge
module Spine = Spine
module Session = Session
