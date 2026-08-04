(** msolve subprocess driver: classifies a polynomial system over ℚ by dimension
    of its variety, and — when zero-dimensional — the size of the solution set,
    by shelling out to msolve (Gröbner-basis + rational univariate
    representation, "RUR" [rouillier1999]) via [Filename.temp_file] input/output
    files. *)

exception Solve_failed of string
(** Raised when the msolve subprocess exits non-zero, or its output cannot be
    parsed against the format pinned by {!classify}'s implementation; carries
    the raw captured text (subprocess stdout+stderr, or the unparseable output
    file contents) for diagnosis. *)

val poly_to_string : names:(int -> string) -> Beloch.Mpoly.t -> string
(** [poly_to_string ~names p] renders [p] in msolve's polynomial syntax
    (`+`/`-`/`*`/`^`, monomial exponent 1 and coefficient 1 elided), using
    [names i] for the variable at index [i]. The zero polynomial renders as
    ["0"]. Exposed for the parser/printer unit tests. *)

type zero_dim = { count : int; multiplicity_free : bool }
(** [count] is the degree of the eliminant f₀ in msolve's rational
    parametrization of the SATURATED system (see {!classify}) — the number of
    DISTINCT points of the variety over an algebraic closure of ℚ.
    [multiplicity_free] is whether every one of those points is simple, i.e.
    whether [count] equals msolve's separately-reported multiplicity-weighted
    (Bézout) degree of the ideal's quotient ring — the "degree" position in its
    output tuple, distinct from f₀'s own degree.

    This is NOT gcd(f₀, f₀′): msolve's [-P] rational parametrization always
    represents the ideal's RADICAL [rouillier1999], so f₀ is squarefree by
    construction regardless of whether the original ideal has multiple points —
    a system like [(x−1)²] reports f₀ = (x−1) (degree 1), which a gcd-based
    squarefree check on f₀ alone cannot distinguish from a genuinely simple root
    at x=1 (both give a trivial gcd). The multiplicity-weighted degree is
    msolve's only carrier of that information, so [multiplicity_free] compares
    it against [count] instead. Detecting a non-multiplicity-free result is the
    Beloch analogue of rejecting a Jacobian-singular candidate point in the k=3
    (Alperin–Lang) fold construction [alperin2006, §4 step 5] — a spurious
    tangency the Rabinowitsch saturation didn't exclude shows up as a repeated
    root here. *)

val parse_output :
  string -> [ `Zero_dim of zero_dim | `Positive_dim | `No_solutions ]
(** [parse_output text] parses msolve's [-o] output-file contents ([text]) — the
    format {!classify} pins empirically against literal msolve 0.10.0 output
    (see test_msolve.ml). Exposed so the parser can be unit-tested directly
    against captured literal fixtures, without a msolve subprocess.
    @raise Solve_failed if [text] doesn't match the pinned shape. *)

val classify :
  nvars:int ->
  denoms:Beloch.Mpoly.t list ->
  Beloch.Mpoly.t list ->
  [ `Zero_dim of zero_dim | `Positive_dim | `No_solutions ]
(** [classify ~nvars ~denoms eqs] classifies the variety of [eqs] (each a
    polynomial in [nvars] variables, indices [0 .. nvars-1]).

    SATURATION: before solving, if [denoms] is non-empty the system is extended
    with one Rabinowitsch variable [w] (index [nvars]) and the equation
    [w · (product of denoms) − 1 = 0], excluding every point where a cleared
    denominator vanishes — see {!Symeq.equations_denoms_of} and the Phase-1
    plan, Task 7. [denoms = []] skips this (no extra variable, no extra
    equation). Classification then runs on the resulting (possibly
    [nvars+1]-variable) saturated system.

    @raise Solve_failed
      if the msolve subprocess fails or its output is unparseable. *)
