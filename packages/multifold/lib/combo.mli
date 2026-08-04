(** Multisets of two-fold alignments (candidate 2FAs) [alperin2006, §4]. *)

type t = Alignment.t list
(** Sorted by {!Alignment.compare}. *)

val candidates : unit -> t list
(** All multisets of 2-4 symbols from {!Alignment.all_twofold} whose
    equations sum to exactly 4, canonical under global a<->b swap, and
    non-separable. *)

val canonical : t -> t
(** The lexicographically smaller (via {!Alignment.compare} list order) of a
    combo and its {!Alignment.swap_ab} image, both sorted. *)

val separable : t -> bool
(** Whether the combo splits into two independent single-fold-axiom
    subsystems [alperin2006, Def. 10]. *)
