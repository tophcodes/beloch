(** Annotations (docs/reference/BELOCH-ANNOTATIONS.md; decisions/annotations-pass-through-and-each-output-is-a-library): what a reader of the
    program is told beside the geometry. An annotation belongs to the
    statement after it and never changes what the program evaluates to. *)

val program_keys : string list
(** The keys without a namespace that belong to the program as a whole
    (decisions/a-program-states-its-author-design-and-sources): [author], [design] and [source]. *)

val check : Ast.program -> unit
(** The checks that need no geometry, over the whole program and every
    [def] body: a key without a namespace is one of the vocabulary, its
    arguments fit it, a namespaced key takes no bare word, a label is unique
    in its statement list, at most one [@step] stands before a statement, and
    every annotation has a statement after it. The keys of the program as a
    whole, [@author], [@design] and [@source] (decisions/a-program-states-its-author-design-and-sources), stand at the top
    level before the first statement, and [@author] and [@design] once. *)

val check_head : Ast.annotation list -> unit
(** {!check} over the annotations at the head of a library file, which
    holds no statements. *)

val resolve : Ctx.ctx -> Ast.annotation -> Ctx.annot_entry
(** Reads the arguments against the current state, which is the state the
    statement after the annotation starts from. A read that fails is an error
    at the argument. The context is left as it was found: a read that
    materializes a mark on its way, or records a reference, is undone, so
    the program evaluates to the same geometry with or without it. *)
