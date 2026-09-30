(* Checks for scripts/prose.test.ts. Only one line of prose in this file breaks
   a rule; the same words in code, in strings and in odoc markup must pass. *)

let really = "really — *) still a string"

(* An outer comment (* with a nested one *) that closes here. *)
let simply = [ "(*"; "simply" ]

(** A doc comment with [really — code], {[ let x = really ]}, {@ocaml[ simply ]},
    {v really verbatim v}, {m \simply}, {math \really}, {!Really.simply},
    {{!Really.simply} the text of a reference}, {b bold}, {i italic} and
    {e emphasis}. *)
let accent = "é —" (* The mask really keeps this column. *)
