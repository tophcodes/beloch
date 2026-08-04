(** The Alperin-Lang two-fold alignment alphabet [alperin2006, §4, Fig. 4]. *)

type kind = AL1 | AL2 | AL3 | AL4 | AL5 | AL6 | AL7 | AL8 | AL9 | AL10
type suffix = A | B | Sym  (** Sym for the symmetric kinds AL1, AL8, AL9 *)
type t = { kind : kind; suffix : suffix }

val all_twofold : t list
(** The 17 symbols: AL1, AL8, AL9 symmetric; AL2–AL7, AL10 in a/b variants. *)

val equations : t -> int
(** Number of equations an alignment contributes: 2 for AL4, AL8, AL9; 1 for the
    rest [alperin2006, §4]. *)

val swap_ab : t -> t
(** Swap the a/b suffix (fixed point on symmetric alignments). *)

val compare : t -> t -> int
(** Orders by kind (AL1..AL10), then a before b within a kind. *)

val combo_to_symbol : t list -> string
(** Render a combination of alignments in the paper's notation, e.g.
    [AL6a; AL6b; AL8] -> ["AL6ab8"] [alperin2006, §4]. *)

val combo_of_symbol : string -> t list option
(** Parse the paper's notation back into a combination of alignments; [None] if
    [s] is not a well-formed symbol. Inverse of {!combo_to_symbol}. *)
