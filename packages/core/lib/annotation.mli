(** Annotations (spec/BELOCH.md, Annotations; ADR 0029): what a reader of the
    program is told beside the geometry. An annotation belongs to the
    statement after it and never changes what the program evaluates to. *)

val check : Ast.program -> unit
(** The checks that need no geometry, over the whole program and every
    [def] body: a key without a namespace is one of the vocabulary, its
    arguments fit it, a namespaced key takes no bare word, a label is unique
    in its statement list, at most one [@step] stands before a statement, and
    every annotation has a statement after it. *)

val resolve : Ctx.ctx -> Ast.annotation -> Ctx.annot_entry
(** Reads the arguments against the current state, which is the state the
    statement after the annotation starts from. A read that fails is an error
    at the argument. The context is left as it was found: a read that
    materialises a mark on its way, or records a reference, is undone, so
    the program evaluates to the same geometry with or without it. *)
