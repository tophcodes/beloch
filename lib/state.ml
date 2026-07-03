(** Provenance carried on each crease: which axiom produced it, its source
    inputs, the source span, and the bound crease name (if any). *)

type provenance = {
  axiom : string;
  sources : string list;
  span : Error.span;
  name : string option;
  step : string option;
}
