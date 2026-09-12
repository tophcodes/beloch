(** Module comment, which documents no item. *)

type face = int array
(** A polygon, given by the indices of {!point}s. *)

type t
(** @see <https://beloch.toph.so/model/#def-flat-state>
      realizes the flat folded state *)

type violation =
  | Bad_index of string  (** an index out of range *)
  | Taco_taco of int * int
      (** hinges i and j interleave
          @see <https://beloch.toph.so/model/#cond-taco-taco>
            realizes the taco-taco condition *)

type hinge = {
  fa : int;  (** one side *)
  fb : int;  (** the other side *)
}
(** A crease between two faces. *)

val undocumented : t -> int

val make : faces:face array -> unit -> (t, violation) result
(** The only constructor; it rejects [faces] that overlap.
    @see <https://beloch.toph.so/model/#def-noncrossing>
      realizes the non-crossing conditions *)

(** {1 A section}

    Whose comment belongs to no item. *)

val rank : t -> int array
(** The stacking order. *)
