(** The standard library of sheets (packages/core/stdlib/shapes.bel), whose
    shapes every program sees as if they were defined before its first line
    (docs/reference/BELOCH.md, "Sheets"). *)

let filename = "stdlib/shapes.bel"

let shapes : Ast.shape_def list Lazy.t =
  lazy (snd (Parse.library ~filename Stdlib_source.source))
