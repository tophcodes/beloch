(** The fan, the one operation every folding verb goes through: it moves
    each piece by the reflections across the changing hinges on its paper
    path (spec multifold, "A fan moves each piece by the changing hinges on
    its paper path"), then searches the layer order over the units and
    conditions the verb gives (spec layer-order, "A verb gives the units of
    its fan's layer search"). The vertex enters through what the verb hands
    over: the scored state, the tip, the face that stays and the role of
    each hinge. {!Axis_fan} builds them for a vertex at the point at
    infinity of an axis (spec multifold, "A fold is the fan at the point at
    infinity of its axis"), for `fold`, `unfold` and `reverse`; {!Collapse},
    {!Squash} and {!Flatten_fans} build them for a vertex on the table, for
    `flatten` and `squash`. *)

(** How a hinge takes part in the fan (spec multifold, "The fan tries each
    hinge no item fixes both ways"). [Keep]: it keeps its angle. [Fold]: it
    changes, a flat hinge folding and a folded one opening. [Try]: the fan
    tries it both ways. *)
type role = Keep | Fold | Try

type t
(** One way the fan folds, before any layer order: per face the motion of
    its piece and whether it turns over, the hinges that carry the letters
    of the elements, and the faces and hinges after the fold placed on the
    table. A mountain and a valley half-turn land every face in the same
    place, so none of this depends on the letters. *)

val make :
  Fold_state.t ->
  root:int ->
  tip:bool array ->
  names:int option array ->
  role:role array ->
  nelem:int ->
  side:(int -> int -> int -> (int * int) option) ->
  t list option
(** The ways the fan folds the state [g], one per choice for the [Try]
    hinges whose motions close. The faces outside [tip] stay, and [root],
    one of them, places the result on the table where it lies in [g] (spec
    multifold, "The stayer places the result on the table"). The motion of a
    face is the product of the reflections across the changing hinges on a
    path to it from a face that stays [hull2020, Def. 6.5]; a choice whose
    paths disagree does not close [hull2020, Thm. 6.6], and a choice that
    moves no face of the tip is none. [names] gives per hinge the element
    that names it, of [nelem], and [side k a b] orders the faces [a] and [b]
    of a hinge element [k] names as (the face on the clockwise side of its
    ray, the face across), or is [None] where it cannot tell. The letter of
    an element holds at each hinge it names whose face on the clockwise side
    lies above no such face of another hinge it names. [None] when no
    choice closes. *)

val geometry : t -> (Fold_state.geometry, Fold_state.violation) result
(** The faces and the changed hinges of the fan placed on the table. *)

(** What the verb fixes of the layer order. [Letters valley]: the units are
    the pieces, the faces of one motion, the faces that stay forming one
    piece, and [valley.(k)] is the letter of element [k] (spec layer-order,
    "A verb gives the units of its fan's layer search"). [Opening (cut,
    blocks)]: the fan of [cut], at the point at infinity of its axis, with
    [blocks] placed as {!Fold_state.fold_opening} places them; the units are
    the faces that stay and each block. *)
type conditions =
  | Letters of bool array
  | Opening of Fold_state.reverse_fan * (bool array * Fold_state.placement) list

val stackings : t -> conditions -> (Fold_state.t list, Fold_state.violation) result
(** Every layer order of the fan that keeps the side of two overlapping
    faces of one unit, exchanged where the fan turns them over, and that
    satisfies [conditions] and the non-crossing conditions
    ({!Fold_state.unit_orders}). *)
