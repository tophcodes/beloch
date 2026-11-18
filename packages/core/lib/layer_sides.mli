(** The sides of layer pairs that a fold has to decide. A pair [(s, m)] names two overlapping faces; its side is
    [true] when [s] lies above [m]. Conditions of the layer order relate
    the sides of two pairs, or fix one; [classes] then says which sides are
    decided and which turn together in a class that nothing decides. *)

type pair = int * int

type lit =
  | Known of bool  (** a side the state before the fold fixes *)
  | Side of pair * bool  (** the side of a pair, negated when [true] *)

type t

val create : unit -> t

val relate : t -> lit -> lit -> why:'why -> (unit, 'why) result
(** [relate t a b ~why] records that [a] and [b] are equal. [Error why] when
    the recorded relations already make them differ. *)

val classes : t -> pair list -> (pair * bool) list * (pair * bool) list list
(** The decided pairs with their sides, and the undecided pairs grouped in
    classes, each pair with its side when its class is set to [true]. *)
