(** The Alperin-Lang two-fold alignment alphabet [alperin2006, §4, Fig. 4]. *)

type kind = AL1 | AL2 | AL3 | AL4 | AL5 | AL6 | AL7 | AL8 | AL9 | AL10
type suffix = A | B | Sym  (** Sym for the symmetric kinds AL1, AL8, AL9 *)
type t = { kind : kind; suffix : suffix }

val all_twofold : t list
(** The 17 symbols: AL1, AL8, AL9 symmetric; AL2–AL7, AL10 in a/b variants. *)
