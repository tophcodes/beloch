(** A write's items classified against the signature of its verb.

    The grammar parses the union of every verb's item bodies, so a head that
    does not belong to the verb arrives here as a [Ast.raw_item] and is
    reported by name at its own span instead of dying as a syntax error. The
    per-verb table lives here and nowhere else.

    A leaf over [Ast] and [Error], called from the semantic actions of the
    parser: [Error -> Ast -> Items -> Parser] (ADR 0018 covers the evaluator
    chain, which this module sits in front of). *)

val mark : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val fold : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val reverse : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val flatten : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
val flip : Ast.raw_item list -> Ast.output -> Error.span -> Ast.stmt
(** Walk the items into the slots of the verb, left to right, and build the
    statement. Each fails at the offending item's span: a head the verb does
    not take, a slot filled twice, a missing axis or ray. *)

val slot : string -> string -> 'a option ref -> Error.span -> 'a -> unit
(** [slot verb head cell span v] fills [cell] with [v], or fails at [span]
    with ["only one <head> item per <verb>"]. *)

val reject : string -> string -> Error.span -> 'a
(** [reject verb head span] fails with ["<verb> takes no (<head>) item"]. *)

val axiom_of_construction : Ast.construction -> Ast.axiom
(** The construction's alignment set recognised as one of the seven axioms,
    by the multiset of its alignment kinds, with source order fixing the
    operand roles where a kind repeats (ADR 0022). Fails naming the
    alignments when the set is none of the seven, when the construction names
    fold lines, and when [toward] rides on a construction that determines one
    line.

    The evaluator reads a construction through this function, since
    [Axiom.axis_of] dispatches on the seven-constructor [Ast.axiom]. *)

val bound_name : Ast.output -> string option
(** The name the output clause binds, for the evaluator's binding step, which
    takes the name alone. *)
