(** The 3D-native folded-state core (issue #48, spec
    2026-07-15-fold-state-3d-rewrite). [t] is abstract: a folded state exists
    only via [make], which enforces the state invariants — so a value of type
    [t] IS a legal folded state. Flat-first: hinge angles (dihedral/π) are
    restricted to {0, ±1}; general rπ is Stage B. *)

type face = Geom.point array
(** 2D paper polygon, sheet coordinates; convex, CCW (same contract as the
    construction kernel — not re-validated here). *)

type hinge = { fa : int; fb : int; line : Geom.line; angle : Num.t }
(** Crease between adjacent faces [fa] and [fb]. [angle] = dihedral/π. The
    sign does not affect a flat placement (±π half-turns coincide); M/V is
    derived from the rank (Plan 2c), never stored. *)

type t

type violation =
  | Bad_index of string
      (** root or a hinge's face index out of range, or fa = fb *)
  | Bad_rank  (** rank is not a permutation of 0..n-1 *)
  | Bad_angle of int  (** hinge i: angle outside {0, ±1} (flat-first) *)
  | Bad_line of int  (** hinge i: line is degenerate (a = b = 0) *)
  | Disconnected of int  (** face i unreachable from the root via hinges *)
  | Hinge_not_shared of int
      (** hinge i: its line is not a positive-length shared boundary edge
          between faces lying in opposite half-planes *)
  | Hinge_not_closed of int
      (** hinge i (a cycle edge): the derived placements contradict its
          motion — folding would tear the sheet *)
  | Taco_tortilla of { tortilla : int; hinge : int }
      (** face [tortilla] is stacked inside folded hinge [hinge]'s taco but
          crosses its crease [hullzakharevich2023 §2.1] *)
  | Taco_taco of int * int
      (** hinges i and j: creases coincide on the table and their face pairs
          interleave in the stack [hullzakharevich2023 §2.1] *)

val violation_to_string : violation -> string

val make :
  faces:face array ->
  hinges:hinge array ->
  root:int ->
  rank:int array ->
  (t, violation) result
(** The only constructor. [rank].(i) is face i's stacking height (higher =
    above), a permutation of 0..n-1. Checks in order: structure (indices,
    rank, angle domain, line non-degeneracy), connectivity, hinge adjacency
    (half-plane + shared edge), cycle closure, then the non-crossing
    conditions (taco-tortilla, taco-taco) over the flat projection. Input
    arrays are copied. *)

val faces : t -> face array
val hinges : t -> hinge array
val root : t -> int

val rank : t -> int array
(** Accessors return copies; [t] cannot be mutated from outside. *)

val above : t -> int -> int -> bool
(** [above g i j]: face i stacked strictly above face j (rank comparison —
    meaningful for faces that overlap in the flat projection). *)

val hinge_motion : hinge -> Isometry3.t
(** The 3D motion a hinge applies in the sheet frame: identity when flat,
    else a half-turn about its crease line embedded in z=0. *)

val face_isos : t -> Isometry3.t array
(** Derived 3D placements (index = face), memoized at construction. *)

val face_iso : t -> int -> Isometry3.t

type mv = M | V

val face_up : t -> int -> bool
(** Face's derived placement preserves in-plane orientation (an even number
    of folds crossed from the root). *)

val mv : t -> int -> mv option
(** Derived mountain/valley of hinge [i], from placements + rank
    [hullzakharevich2023, §2.1]: valley iff the orientation-preserved side
    lies below its neighbour. [None] for a flat hinge. Derived, never
    stored — it cannot contradict the geometry. *)
