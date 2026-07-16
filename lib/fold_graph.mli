(** The 3D-native folded-state core (issue #48, spec
    2026-07-15-fold-state-3d-rewrite). [t] is abstract: a folded state exists
    only via [make], which enforces the state invariants — so a value of type
    [t] IS a legal folded state. Flat-first: hinge angles (dihedral/π) are
    restricted to {0, ±1}; general rπ is Stage B. *)

type face = Geom.point array
(** 2D paper polygon, sheet coordinates; convex, CCW (same contract as the
    construction kernel — not re-validated here). *)

type assign = M | V | F
(** Mountain / valley / flat. Used both as a hinge's stored [intent]
    (crease-pattern colour, user intent) and as [mv]'s derived result. *)

type hinge = {
  fa : int;
  fb : int;
  line : Geom.line;
  angle : Num.t;
  crease_id : int;  (** internal identity; unique within a state, never serialized *)
  intent : assign;  (** crease-pattern colour (old eintent) — user intent, stored *)
  prov : State.provenance option;
}
(** Crease between adjacent faces [fa] and [fb]. [angle] = dihedral/π. The
    sign does not affect a flat placement (±π half-turns coincide); M/V is
    derived from the rank (Plan 2c), never stored. *)

type mark_geom = MSeg of Geom.point * Geom.point | MPoint of Geom.point

type mark = {
  mgeom : mark_geom;
  mline : Geom.line;
  mintent : assign;
  mcrease_id : int;
  mprov : State.provenance option;
}
(** Paper-space, fold-invariant reference/pinch record (moved verbatim from
    the old Fold_state). No invariants of its own. *)

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
  ?base:Isometry3.t ->
  ?marks:mark array ->
  faces:face array ->
  hinges:hinge array ->
  root:int ->
  rank:int array ->
  unit ->
  (t, violation) result
(** The only constructor. [rank].(i) is face i's stacking height (higher =
    above), a permutation of 0..n-1. [base] is the root face's placement —
    ONE whole-sheet rigid motion (default identity); needed because after a
    pleat (fold, then fold moving the previously-stationary side) no face
    keeps an identity placement, and [flip] moves everything. No per-face
    freedom, so tears stay unrepresentable, and the closure/non-crossing
    checks are unaffected (a rigid motion of everything). [marks] is a
    paper-space, fold-invariant array of reference/pinch records (default
    empty). The trailing [unit] anchors the two leading optional arguments
    — OCaml cannot erase omitted optionals followed only by labelled
    arguments. Checks in order: structure (indices, rank, angle domain,
    line non-degeneracy), connectivity, hinge adjacency (half-plane +
    shared edge), cycle closure, then the non-crossing conditions
    (taco-tortilla, taco-taco) over the flat projection. Input arrays are
    copied. *)

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

val base : t -> Isometry3.t
(** The stored root-face placement (see [make]'s [base] parameter). *)

val marks : t -> mark array
(** Copy of the paper-space marks carried on the state. *)

val face_up : t -> int -> bool
(** Face's derived placement preserves in-plane orientation (an even number
    of folds crossed from the root). *)

val mv : t -> int -> assign
(** Derived mountain/valley/flat of hinge [i], from placements + rank
    [hullzakharevich2023, §2.1]: valley iff the orientation-preserved side
    lies below its neighbour; [F] iff the hinge's angle is 0. Derived,
    never stored — it cannot contradict the geometry. *)

val fresh_crease_id : unit -> int
(** Mints a fresh internal crease id, unique within a reset cycle. *)

val reset_ids : unit -> unit
(** Resets the crease-id counter to 0 (called once per eval, so ids are a
    deterministic function of the program). *)

(** {1 2D access}

    Flat-first (hinge angles in {0, ±1}) motions keep z = 0 invariant, so a
    face's derived 3D placement restricted to the plane is exactly its table
    placement as a 2D isometry — that is what this section exposes. Stage B
    (partial angles) lifts faces off the plane; none of these must be used
    once that lands. *)

val face_iso2 : t -> int -> Isometry.t
(** In-plane 2D restriction of face [i]'s derived placement (the upper-left
    2×2 block + translation of [face_iso]). Flat-first only — see above. *)

val table_polygon : t -> int -> Geom.point array
(** Face [i]'s paper polygon placed on the table via [face_iso2]. Winding
    follows the placement (a reflected face is CW); see [table_polygon_ccw]
    for a normalized version. *)

val table_polygon_ccw : t -> int -> Geom.point array
(** [table_polygon], re-wound CCW if the placement reflects it. Use this for
    the [Geom] clip/crossing helpers, which require CCW input. *)

type rel = Above | Below | Apart
(** Layer relation of two faces in the current table projection. *)

val rel : t -> int -> int -> rel
(** [rel g i j]: [Above]/[Below] by rank where [i] and [j]'s table polygons
    strictly overlap ([Geom.convex_overlap] — touching is not overlap);
    [Apart] otherwise (including [i = j]). *)

val hinge_segment : t -> int -> Geom.point * Geom.point
(** Hinge [i]'s shared boundary segment, in paper space. *)

val hinge_table_segment : t -> int -> Geom.point * Geom.point
(** Hinge [i]'s shared boundary segment, placed on the table via [fa]'s
    [face_iso2]. *)

val table_position : t -> Geom.point -> Geom.point
(** The current table position of a paper-space point, found via whichever
    face contains it (placements agree at shared hinges, so any works).
    Raises [Invalid_argument] if the point lies in no face. *)

val paper_preimages : t -> Geom.point -> Geom.point list
(** Distinct paper-space points that currently map to table point [tp] — one
    per overlapping layer covering it. *)

val on_paper : t -> Geom.point -> bool
(** Whether a paper-space point lies in some face. *)

(** {1 Construction operations (Plan 3a)}

    Each operation builds new faces/hinges and re-validates through [make]; a
    violation raises {!Error.fail} at the given provenance span, since a
    program-level construction step is never expected to produce an invalid
    state — reaching [Error] here is a bug, not user input to report softly. *)

val init_square : t
(** The unit square [0,1]², a single flat face, no hinges. *)

val subdivide :
  ?crease_id:int ->
  ?intent:assign ->
  ?keep_side:Geom.line * int ->
  t ->
  Geom.line ->
  prov:State.provenance option ->
  t
(** Split every face [axis] (a TABLE-space line) crosses into two, joined by
    a new flat (angle 0) hinge; faces [axis] misses are left whole. Old
    hinges over a split face are carried onto whichever child pair still
    shares a positive-length boundary segment. [keep_side:(guard, keep)]
    restricts the cut to the ray of [axis] on side [keep] of the
    perpendicular [guard] line through the ray's origin — faces on the other
    side are left uncut. [crease_id] defaults to a fresh id; [intent]
    defaults to [V]. *)

val subdivide_paper :
  ?crease_id:int ->
  ?intent:assign ->
  t ->
  Geom.line ->
  prov:State.provenance option ->
  t
(** Like [subdivide], but [paper_axis] is a PAPER-space line: every face it
    crosses is split, regardless of current table placement. *)

val fold :
  ?crease_id:int ->
  ?moving_parents:bool array ->
  t ->
  axis:Geom.line ->
  move_side:int ->
  valley:bool ->
  prov:State.provenance option ->
  t
(** Simple flat fold as a graph transformation: faces on [move_side] of the
    TABLE-space [axis] (restricted to [moving_parents], default all faces)
    are cut and hinged to their stationary counterpart with a new angle-1
    hinge; any old hinge lying entirely on [axis] with exactly one moving
    side toggles (a flat precrease upgrades to folded, keeping its
    [crease_id]; a folded hinge with no cut counterpart on the axis
    physically unfolds back to angle 0). The rank is rebuilt in two blocks —
    stationary faces keep their relative order, movers reverse theirs — with
    movers stacked above for a valley fold, below for a mountain fold. The
    root and [base] are chosen from a stationary child where one exists (its
    parent's placement is unchanged); only when every face moves is the base
    itself reflected across [axis]. Raises {!Error.fail} at [prov]'s span on
    a resulting invariant violation. *)

val simple_fold : t -> axis:Geom.line -> move_side:int -> valley:bool -> t
(** [fold] with no [crease_id]/[moving_parents] override and no provenance. *)

val flip : t -> t
(** Turn the whole sheet over: reflects across the footprint's vertical
    centerline (an internal, cosmetic axis — which line is irrelevant, only
    the substantive effect matters), reverses the face array (D9 — emit
    order) and the stack. The reflection is absorbed into [base] — the ONE
    whole-sheet motion; no per-face isometry is stored. *)

val add_mark : t -> mark -> t
(** Append a paper-space mark. Marks carry no invariants, so this is a plain
    record update — no re-validation through [make]. *)

(** {1 Selectors} *)

val neighbors : t -> int -> int list
(** Face ids sharing a hinge with face [i]. *)

val hinge_between : t -> int -> Geom.point -> Geom.point -> int option
(** Index of the hinge incident to face [i] whose paper segment equals
    (pa,pb) in either order (old [edge_between], returning an index so
    callers can reach [mv]/[intent]/[prov]). *)

val all_crease_ids : t -> int list
(** The distinct crease ids present in the current state. *)

type crease_segment = {
  faces : int * int;
  ta : Geom.point;  (** table space *)
  tb : Geom.point;  (** table space *)
  pa : Geom.point;  (** paper space *)
  pb : Geom.point;  (** paper space *)
}

val crease_segments : t -> int -> crease_segment list
(** Every material segment of crease [cid]. List order is unspecified. *)

val edge_boundary_segments : t -> Geom.line -> crease_segment list
(** Boundary pieces of a paper edge [line] (one of the sheet's sides): the
    polygon sides of every face lying on [line] that are not paired with a
    neighbor across a hinge. List order is unspecified. *)

val crease_axis : t -> int -> Geom.line -> [ `Line of Geom.line | `Bent | `Empty ]
(** Classification of crease [cid] against its ORIGINAL table-space line
    [l_orig]: [`Line l_orig] if every piece still lies on it, else [`Line l]
    for the single line carrying every piece if one exists (reconstructed
    from two distinct table endpoints), [`Bent] if the pieces are not
    collinear, [`Empty] if the crease has no pieces. *)

val crease_paper_axis : t -> int -> [ `Line of Geom.line | `Bent | `Empty ]
(** The single PAPER-space line carrying every material segment of [cid], if
    one exists; [`Bent] if segments born on different layers are mirror-image
    scars on different paper lines, [`Empty] if the crease has no pieces. *)
