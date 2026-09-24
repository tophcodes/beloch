(** js_of_ocaml entry point — exports a global [belochFoldString] that runs
    the real evaluator ([Beloch.fold_string]) on a source string and returns
    a JSON-encoded, structured result:

    - [{"ok":true,"fold":<FOLD object>}] on success.
    - [{"ok":false,"kind":"native","message":...}] when evaluation hit an
      irrational (qqbar) value, which the js_of_ocaml build can't compute
      (see [qqbar_shim.js] and decisions/0013-flint-qqbar-backend.md) — the
      caller should fall back to the native evaluator.
    - [{"ok":false,"kind":"error","message":...,"hint":...,"line":...,"column":...,
      "endLine":...,"endColumn":...}] for a Beloch_error (language/program
      error). [line] and [column] are the 1-based start of the span the error
      carries, [endLine] and [endColumn] the position one past its end, so the
      caller can mark the offending word in its editor. [hint] is present when
      the error suggests something to write instead (ADR 0028). An exception
      with no span omits all position fields.

    Pure-rational programs (incl. the axiom-7 cube-root fragment) round-trip
    fully in-browser; only ops that force a [Qqbar.t] canonical form hit the
    shim. *)

let irrational_prefix = "beloch: irrational value requires"

let starts_with ~prefix s =
  let lp = String.length prefix in
  String.length s >= lp && String.sub s 0 lp = prefix

(* One long-lived session per worker: successive edits reuse the unchanged
   statement prefix and recompute only the divergent suffix. *)
let session = Beloch.Session.create ()

let fold_string_js (src : Js_of_ocaml.Js.js_string Js_of_ocaml.Js.t) :
    Js_of_ocaml.Js.js_string Js_of_ocaml.Js.t =
  let src = Js_of_ocaml.Js.to_string src in
  let result =
    try
      let folded = Beloch.Session.eval session ~filename:"playground" src in
      let fold = Beloch.Fold_emit.to_json_folded folded in
      `Assoc [ ("ok", `Bool true); ("fold", fold) ]
    with
    | Failure m when starts_with ~prefix:irrational_prefix m ->
        `Assoc
          [ ("ok", `Bool false); ("kind", `String "native"); ("message", `String m) ]
    | Beloch.Error.Beloch_error ((start, stop), m, hint) ->
        let col (p : Lexing.position) = p.pos_cnum - p.pos_bol + 1 in
        `Assoc
          ([ ("ok", `Bool false); ("kind", `String "error"); ("message", `String m) ]
          @ (match hint with Some h -> [ ("hint", `String h) ] | None -> [])
          @ [
              ("line", `Int start.Lexing.pos_lnum);
              ("column", `Int (col start));
              ("endLine", `Int stop.Lexing.pos_lnum);
              ("endColumn", `Int (col stop));
            ])
    | e ->
        `Assoc
          [
            ("ok", `Bool false);
            ("kind", `String "error");
            ("message", `String (Printexc.to_string e));
          ]
  in
  Js_of_ocaml.Js.string (Yojson.Safe.to_string result)

let () =
  Js_of_ocaml.Js.Unsafe.set Js_of_ocaml.Js.Unsafe.global "belochFoldString"
    (Js_of_ocaml.Js.wrap_callback fold_string_js)
