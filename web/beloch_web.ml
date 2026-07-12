(** js_of_ocaml entry point — exports a global [belochFoldString] that runs
    the real evaluator ([Beloch.fold_string]) on a source string and returns
    a JSON-encoded, structured result:

    - [{"ok":true,"fold":<FOLD object>}] on success.
    - [{"ok":false,"kind":"native","message":...}] when evaluation hit an
      irrational (qqbar) value, which the js_of_ocaml build can't compute
      (see [qqbar_shim.js] and decisions/0013-flint-qqbar-backend.md) — the
      caller should fall back to the native evaluator.
    - [{"ok":false,"kind":"error","message":...}] for a Beloch_error
      (language/program error) or any other exception.

    Pure-rational programs (incl. the axiom-7 cube-root fragment) round-trip
    fully in-browser; only ops that force a [Qqbar.t] canonical form hit the
    shim. *)

let irrational_prefix = "beloch: irrational value requires"

let starts_with ~prefix s =
  let lp = String.length prefix in
  String.length s >= lp && String.sub s 0 lp = prefix

let fold_string_js (src : Js_of_ocaml.Js.js_string Js_of_ocaml.Js.t) :
    Js_of_ocaml.Js.js_string Js_of_ocaml.Js.t =
  let src = Js_of_ocaml.Js.to_string src in
  let result =
    try
      let fold = Beloch.fold_string ~filename:"playground" src in
      `Assoc [ ("ok", `Bool true); ("fold", fold) ]
    with
    | Failure m when starts_with ~prefix:irrational_prefix m ->
        `Assoc
          [ ("ok", `Bool false); ("kind", `String "native"); ("message", `String m) ]
    | Beloch.Error.Beloch_error (_, m) ->
        `Assoc
          [ ("ok", `Bool false); ("kind", `String "error"); ("message", `String m) ]
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
