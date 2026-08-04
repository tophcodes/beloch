(** The enumeration pipeline: candidate combos of alignments -> symbolic
    equations -> {!Msolve} classification -> canonical symbols. Reproduces
    Alperin-Lang's fold-generator counts [alperin2006]: the one-fold alphabet
    gives exactly the 7 Huzita-Justin axioms [§2]; the two-fold alphabet
    restricted to combos without AL10 gives 203 of the paper's 489 [§4]. *)

val run_onefold : unit -> string list
(** Every one-fold generator combo ({!Combo.onefold_candidates}) whose equation
    system (alphabet A1-A5 [alperin2006, §2, Fig. 2], built on 2 variables — one
    fold) also survives the strict algebraic filter: zero dimensional, at least
    one solution, no repeated root ({!Msolve.classify}'s
    [count >= 1 && multiplicity_free]). Sorted. Validates the algebra and msolve
    plumbing against ground truth: still exactly the 7 HJAs.

    Realness ({!Msolve.zero_dim.real_count}) is not part of this filter: it is
    reported, not filtered (see notes/2026-08-04-multifold-203-mismatch.md's
    addendum) — a symbol whose only strict-surviving solution at this function's
    stream has [real_count = 0] is logged to stderr as "complex-only at this
    stream" rather than dropped. *)

val run_twofold : with_al10:bool -> stream:Symeq.param_stream -> string list
(** Every two-fold candidate combo ({!Combo.candidates}; combos containing an
    AL10 alignment are dropped first when [with_al10] is [false]) whose equation
    system (4 variables — two folds) survives the same strict filter. Canonical
    symbols ({!Alignment.combo_to_symbol}), sorted. Logs progress to stderr
    every 100 combos processed, and additionally logs any kept symbol whose
    solution has [real_count = 0] at this [stream] as "complex-only at this
    stream" — realness is reported, not filtered (see
    notes/2026-08-04-multifold-203-mismatch.md's addendum). *)

val run_twofold_lax : with_al10:bool -> stream:Symeq.param_stream -> string list
(** Same sweep as {!run_twofold}, but keeping every [`Zero_dim { count; _ }]
    with [count >= 1] regardless of [multiplicity_free] — a superset of
    {!run_twofold}'s result. Logs the lax-only symbols (in this result but not
    in {!run_twofold}'s) to stderr: this measured difference is the evidence for
    which filter semantics Alperin-Lang's printed totals actually correspond to
    (Phase-1 plan, Task 10). Shares {!run_twofold}'s msolve results for the same
    [(with_al10, stream)] rather than re-solving. *)

val lax_only : with_al10:bool -> stream:Symeq.param_stream -> string list
(** {!run_twofold_lax}'s result minus {!run_twofold}'s: the combos accepted only
    because [multiplicity_free] was ignored. *)

val run_twofold_published :
  with_al10:bool -> stream:Symeq.param_stream -> string list
(** {!run_twofold}'s result, additionally restricted by
    {!Combo.matches_published_list} (R4) -- the EMPIRICAL filter that reproduces
    Alperin-Lang's exact printed listing. This is the "reproduction run": at
    [with_al10:false], its result is symbol-exact against the paper's 203
    [alperin2006]. Logs both the unfiltered ({!run_twofold}) and R4-filtered
    counts to stderr, since R4 is not a derived rule and its effect should stay
    visible to callers rather than silently included. *)
