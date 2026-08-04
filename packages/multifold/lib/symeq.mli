(** Symbolic two-fold alignment equations over [Beloch.Mpoly].

    Representation [alperin2006, Def. 2]: a line [(X, Y)] is the point set of
    [Xx + Yy + 1 = 0]. Fold line [i] (0 or 1) has coordinates
    [x_i = Mpoly.var nvars (2i)] and [y_i = Mpoly.var nvars (2i + 1)];
    [nvars = 4] for two-fold work, [nvars = 2] for the one-fold pipeline reuse
    (only alignments touching fold 0 are then representable).

    Suffix semantics: for AL2–AL7 the suffix names the fold that does the
    folding (a → fold 0, b → fold 1); for AL10 the suffix names the fold whose
    line makes the intersection (AL10a: intersection with fold 0's line,
    reflection by fold 1). AL1, AL8, AL9 are symmetric with roles fixed as in
    [alperin2006, Fig. 4]. *)

type param_stream
(** A deterministic supply of generic rational parameters. Each alignment
    occurrence pulls fresh values, so no two alignments in a combination share a
    given object — matching the paper's "points and lines … are assumed to be
    distinct" [alperin2006, §2, body text above Table 1]. Known limitation:
    because every occurrence draws fresh values, a stream cannot express a
    deliberately REPEATED given object across alignments (e.g. the paper's
    quartic construction AL6ab9 with L1 = L2 [alperin2006, §6.2.3]) — fine for
    generic enumeration, but relevant for future construction work that needs a
    shared given object. *)

val stream_a : param_stream
(** A hardcoded stream of generic rationals (mixed large prime
    numerators/denominators, alternating signs — no collinearities or other
    degeneracies by genericity). *)

val stream_b : param_stream
(** A second such stream, disjoint from {!stream_a}. *)

type params = {
  points : (Q.t * Q.t) list;
      (** given points, in notation order (P, or P1 P2) *)
  lines : (Q.t * Q.t) list;
      (** given lines in (X,Y) rep, in notation order (L, or L1 L2) *)
}
(** The given objects one alignment occurrence consumes. *)

val alignment_params :
  stream:param_stream -> start:int -> Alignment.t -> params * int
(** [alignment_params ~stream ~start a] draws the given objects [a] consumes
    from [stream] beginning at position [start]; returns them together with the
    next unread position. Points are drawn before lines. Raises
    [Invalid_argument] if the stream is exhausted. *)

val reflect_point_raw :
  nvars:int ->
  fold:int ->
  Q.t * Q.t ->
  Beloch.Mpoly.t * Beloch.Mpoly.t * Beloch.Mpoly.t
(** [reflect_point_raw ~nvars ~fold (px, py)] is the folded image of the given
    point across fold line [fold], as [(num_x, num_y, den)] with
    [den = x_i² + y_i²] [alperin2006, eq. (1)]. *)

val reflect_line_raw :
  nvars:int ->
  fold:int ->
  Q.t * Q.t ->
  Beloch.Mpoly.t * Beloch.Mpoly.t * Beloch.Mpoly.t
(** [reflect_line_raw ~nvars ~fold (lX, lY)] is the folded image of the given
    line across fold line [fold], as [(num_X, num_Y, den)] on the (X,Y)
    representation, with [den = x_i² + y_i² − 2·lX·x_i − 2·lY·y_i]. Derived in
    the implementation (eq. (2) of the paper's OCR is garbled); validated by the
    involution and Geom cross-check tests. *)

val equations_denoms_of :
  nvars:int ->
  stream:param_stream ->
  Combo.t ->
  Beloch.Mpoly.t list * Beloch.Mpoly.t list
(** [equations_denoms_of ~nvars ~stream combo] is [(equations, denoms)]: the
    same polynomial system as {!equations_of}, together with the denominators
    that were actually cleared while building it (deduplicated across the whole
    combination). Every equation is obtained from a reflection formula
    ([reflect_point_raw] or [reflect_line_raw]) by clearing a denominator that
    is a polynomial in the UNKNOWN fold coordinates, not in the given parameters
    — clearing it enlarges the solution set to include fold positions where the
    denominator vanishes (the reflected object has left the (X, Y) chart),
    whether or not the alignment itself holds. Consumers solving these systems
    MUST exclude denominator zeros, e.g. by Rabinowitsch saturation (auxiliary
    variable [w], equation [w · (product of denoms) − 1 = 0]) — see the Phase-1
    plan, Task 7. *)

val equations_of :
  nvars:int -> stream:param_stream -> Combo.t -> Beloch.Mpoly.t list
(** The equations component of {!equations_denoms_of}, without the cleared
    denominators: the concatenation, in combo order, of each alignment's
    equations (1 or 2 per alignment, per [Alignment.equations]). Given objects
    are drawn fresh from [stream], threading positions left to right. Callers
    that will actually solve the system, rather than just build and inspect it,
    should use {!equations_denoms_of} instead so the denominator-zero loci can
    be excluded. *)
