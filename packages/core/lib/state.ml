(** Provenance carried on each crease: which axiom produced it, its source
    inputs, the source span, the bound crease name (if any), and the index of
    the statement that scored it. *)

type provenance = {
  axiom : string;
  sources : string list;
  span : Error.span;
  name : string option;
  stmt : int;
      (* position of the scoring statement in the `beloch:statements` log.
         The source span alone cannot identify it: two statements may share a
         line, so a consumer joining on line number gets an ambiguous key. *)
}
